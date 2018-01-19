package RDF::Store::BerkeleyDB;

use 5.014;
use strict;
use warnings FATAL => 'all';

use Moo;

use Digest;
use URI;
use URI::BNode;
use Try::Tiny;
use Throwable::Error;
use Scalar::Util ();
use Path::Class  ();

use BerkeleyDB qw(DB_CREATE DB_INIT_MPOOL DB_INIT_TXN DB_INIT_LOCK
                  DB_INIT_LOG DB_RECOVER DB_AUTO_COMMIT DB_DUP
                  DB_DUPSORT DB_FOREIGN_ABORT DB_DONOTINDEX);

=head1 NAME

RDF::Store::BerkeleyDB - Generic storage for RDF based on Berkeley DB

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  package My::Subclass;

  use Moo; # or Moose or whatever

  with 'RDF::Store::BerkeleyDB';

  # now do your implementation-specific stuff

=head1 METHODS

=head2 new

=cut

sub _is_really {
    my ($thing, $class) = @_;

    my $ref = ref $thing or return;
    return $thing->isa($class) || Scalar::Util::reftype($thing) eq $class
        if Scalar::Util::blessed($thing);

    return $ref eq $class;
}

sub _create_dir {
    my ($self, $dir) = @_;
    Throwable::Error->throw("$dir is not a Path::Class::Dir")
          unless _is_really($dir, 'Path::Class::Dir');

    my $stat = $dir->stat;
    if ($stat) {
        Throwable::Error->throw("Cannot read $dir")  unless -r $stat;
        Throwable::Error->throw("Cannot write $dir") unless -w $stat;
    }
    else {
        try {
            my $mode = 0777 & ~$self->umask | 02000;
            $dir->mkpath(0, $mode);
        } catch {
            Throwable::Error->throw("Cannot create $dir: $_");
        };
    }

    # not like we're evaluating the output but whatever
    $dir;
}

# is URI, IRI, or conforming opaque string (strict means no bnodes)
sub _assert_resource {
    my ($obj, $strict) = @_;
}

# is URI::BNode or conforming opaque string starting with "_:"
sub _assert_blank {
}

# either a UTF-8 string or an ARRAY reference
sub _assert_literal {
}

sub _encode_resource {
}

sub _decode_resource {
}

sub _encode_literal {
    my $literal = shift;
}

sub _decode_literal {
    # will decode into either a string or arrayref
}

# databases:

# node: resolves nodes to their values
#   key:   sha256 hash of normalized+encoded node
#   value: normalized+encoded node
#
# statement: stores statement data
#   key:   sha256 hash of normalized+encoded statement
#   value: concatenated sha256 hashes of SPO nodes
#
# context: maps statement to graph
#   key:   concatenated sha256 hashes of graph and normalized+encoded statement
#   value: sha256 hash of normalized+encoded node
#
# literal: enables lookups on literal (sans language/datatype)
#   key:   raw literal value
#   value: sha256 hash of normalized+encoded literal
#
# language: enables lookups on language codes
#   key:   language code
#   value: sha256 hash of normalized+encoded literal
#
# datatype: enables lookups on datatypes
#   key:   sha256 hash of normalized+encoded datatype
#   value: sha256 hash of normalized+encoded literal
#
# graph: resolves graph node to statements
#   key:   sha256 hash of normalized+encoded node
#   value: sha256 hash of normalized+encoded statement
#
# subject: resolves subject node to statements
#   key:   sha256 hash of normalized+encoded node
#   value: sha256 hash of normalized+encoded statement
#
# predicate: resolves predicate node to statements
#   key:   sha256 hash of normalized+encoded node
#   value: sha256 hash of normalized+encoded statement
#
# object: resolves object node to statements
#   key:   sha256 hash of normalized+encoded node
#   value: sha256 hash of normalized+encoded statement

# database constants
my @DBS  = qw(node statement context literal language datatype
              graph subject predicate object);
my %DUPS = map +($_ => 1), @DBS[3..$#DBS]; # DBs with duplicates

# secondary database function generators
sub _offset {
    my ($off, $len) = @_;
    sub {
        $_[2] = substr($_[1], $off, $len);
        return 0;
    };
}

sub _lit {
    my $which = shift;
    Throwable::Error->throw("$which is not an integer between 0 and 2")
          unless $which =~ /^[0-2]$/;

    sub {
        return DB_DONOTINDEX unless $_[1] =~ /^"/;
        my $aref = _decode_literal($_[1]);

        # coerce to array of the form [ content, language, datatype ]
        my @a = ref $aref eq 'ARRAY' ? @$aref : ($aref, undef, undef);

        # datatype will be a URI reference. since datatypes and
        # language tags are disjoint, it can occupy the second position.
        splice @a, 1, 0, undef if @a == 2 and ref $a[1];

        # if we still have a 2-piece array, the second will be language.
        push @a, undef if @a == 2;

        if (defined (my $k = $a[$which])) {
            $_[2] = $which ? "$k" : lc $k;
            return 0;
        }
        DB_DONOTINDEX;
    };
}

my %ASSOC = (
    graph     => _offset(0,  32),
    subject   => _offset(0,  32),
    predicate => _offset(32, 32),
    object    => _offset(64, 32),
    literal   => _lit(0),
    language  => _lit(1),
    datatype  => _lit(2),
);

has dir => (
    is       => 'ro',
    isa      => sub { _is_really($_[0], 'Path::Class::Dir') },
    coerce   => sub { Path::Class::Dir->new($_[0]) },
    required => 1,
);

has name => (
    is       => 'ro',
    isa      => sub { $_[0] =~ /^[0-9a-z_-]+$/ },
    coerce   => sub { lc $_[0] },
    default  => 'default',
);

has umask => (
    is       => 'ro',
    isa      => sub {},
    default  => 077,
);

has _env => (
    is       => 'rw',
    init_arg => undef,
);

has _contents => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { {} },
);

sub BUILD {
    my $self = shift;

    # make directory if not present
    $self->_create_dir($self->dir);

    # initialize environment
    my $mode  = 0666 & ~$self->umask;
    my $flags = DB_CREATE|DB_INIT_MPOOL|DB_INIT_TXN|
        DB_INIT_LOCK|DB_INIT_LOG|DB_RECOVER;
    my $env = BerkeleyDB::Env->new(
        -Home    => $self->dir->absolute->stringify,
        -Mode    => $mode,
        -Flags   => $flags,
        -ErrFile => $self->dir->absolute->file('error.log')->stringify,
    ) or Throwable::Error->throw
        ("Can't create transaction environment: $BerkeleyDB::Error");

    # initialize databases
    my $contents = $self->_contents;
    for my $id (@DBS) {
        my %p = (
            -Env      => $env,
            -Flags    => DB_CREATE|DB_AUTO_COMMIT,
            -Mode     => $mode,
            -Filename => $self->name,
            -Subname  => $id,
        );
        $p{-Property} = DB_DUP|DB_DUPSORT if $DUPS{$id};

        my $db = BerkeleyDB::Btree->new(%p) or Throwable::Error->throw
            ("Can't create/bind database $id: $BerkeleyDB::Error");
        $contents->{$id} = $db;
    }

    # now we set up associations
    # subject, predicate, object are secondary to statement
    for my $id (qw(subject predicate object)) {
        $contents->{statement}->associate($contents->{$id}, $ASSOC{$id}) == 0
            or Throwable::Error->throw("Error associating $id to statement "
                                           . "database: $BerkeleyDB::Error");
    }

    # we need a special association for context to graph
    if ($contents->{context}->associate
            ($contents->{graph}, $ASSOC{graph}) != 0) {
        Throwable::Error->throw('Error associating graph to context '
                                    . "database: $BerkeleyDB::Error");
    }

    # language, datatype are secondary to node
    for my $id (qw(literal language datatype)) {
        $contents->{node}->associate($contents->{$id}, $ASSOC{$id}) == 0
            or Throwable::Error->throw("Error associating $id to node " .
                                           "database: $BerkeleyDB::Error");
    }

    # subject, predicate, object all foreign key to node
    # XXX cannot make graph a foreign key as graph cannot be empty
    for my $id (qw(datatype graph subject predicate object)) {
        $contents->{node}->associate_foreign
            ($contents->{$id}, undef, DB_FOREIGN_ABORT) == 0
                or Throwable::Error->throw("Error associating $id to node " .
                                               "database: $BerkeleyDB::Error");
    }

}

sub DEMOLISH {
}

=head2 get_statements $s, $p, $o [, $g, $opts]

returns a callback in scalar context

=cut

sub get_statements {
    my ($self, $s, $p, $o, $g, $opts) = @_;
}

=head2 get_contexts

returns a callback in scalar context

=cut

sub get_contexts {
    my $self = shift;
}

=head2 add_statement $s, $p, $o [, $g]

returns true or throws an error

=cut

sub add_statement {
    my ($self, $s, $p, $o, $g) = @_;
    # verify input

    # encode nodes

    # hash nodes

    # insert nodes
}

=head2 remove_statement $s, $p, $o [, $g]

returns true or throws an error

=cut

sub remove_statement {
}

=head2 count_statements

returns a non-negative integer

=cut

sub count_statements {
}

=head1 AUTHOR

Dorian Taylor, C<< <dorian at cpan.org> >>

=head1 BUGS

Please report issues at
L<https://github.com/doriantaylor/p5-rdf-store-berkeleydb/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

  perldoc RDF::Store::BerkeleyDB

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/RDF-Store-BerkeleyDB>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/RDF-Store-BerkeleyDB>

=item * Search CPAN

L<http://search.cpan.org/dist/RDF-Store-BerkeleyDB/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2017 Dorian Taylor.

Licensed under the Apache License, Version 2.0 (the "License"); you
may not use this file except in compliance with the License.  You may
obtain a copy of the License at
L<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied.  See the License for the specific language governing
permissions and limitations under the License.

=cut

1; # End of RDF::Store::BerkeleyDB

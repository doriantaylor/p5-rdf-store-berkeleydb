package RDF::Store::BerkeleyDB;

use 5.014;
use strict;
use warnings FATAL => 'all';

use Moo::Role;

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
    return $thing->isa($class) || reftype $thing eq $class
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

    # this should always be true since it's a reference
    $dir;
}

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

my @DBS  = qw(statement node language datatype graph subject predicate object);
my %DUPS = map +($_ => 1), @DBS[2..$#DBS]; # DBs with duplicates

# secondary database functions
sub _offset {
    my ($off, $len) = @_;
    sub {
        $_[2] = substr($_[1], $off, $len);
        return 0;
    };
}
sub _lit {
    my $which = int not not shift;
    sub {
        return DB_DONOTINDEX unless $_[1] =~ /^"/;
        my $aref = _decode_literal($_[1]);
        if (ref $aref eq 'ARRAY' and defined (my $k = $aref->[1 + $which])) {
            $_[2] = $which ? "$k" : lc $k;
            return 0;
        }
        DB_DONOTINDEX;
    };
}
my %ASSOC = (
    subject   => _offset(0,  32),
    predicate => _offset(32, 32),
    object    => _offset(64, 32),
    language  => _lit(0),
    datatype  => _lit(1),
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
            or Throwable::Error->throw
                ("Error associating $id to statement database");
    }
    # graph, subject, predicate, object all foreign key to node
    for my $id (qw(graph subject predicate object)) {
        $contents->{$id}->associate_foreign
            ($contents->{node}, undef, DB_FOREIGN_ABORT) == 0
                or Throwable::Error->throw
                    ("Error associating $id to node database");
    }

    # language, datatype are secondary to node
    for my $id (qw(language datatype)) {
        $contents->{node}->associate($contents->{$id}, $ASSOC{$id}) == 0
            or Throwable::Error->throw
                ("Error associating $id to node database");
    }
}

sub _encode_literal {
    my $literal = shift;
    
}

sub _decode_literal {
    # will decode into 
}

=head2 get_statements

=cut

sub get_statements {
}

=head2 get_contexts

=cut

sub get_contexts {
}

=head2 add_statement

=cut

sub add_statement {
}

=head2 remove_statement

=cut

sub remove_statement {
}

=head2 count_statements

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

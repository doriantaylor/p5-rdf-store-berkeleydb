package RDF::Store::BerkeleyDB;

use 5.014;
use strict;
use warnings FATAL => 'all';

use Moo::Role;

use Digest;
use URI;
use URI::BNode;
use Path::Class ();

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

=head2 function1

=cut

sub function1 {
}

=head2 function2

=cut

sub function2 {
}

=head1 AUTHOR

Dorian Taylor, C<< <dorian at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-rdf-store-berkeleydb at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=RDF-Store-BerkeleyDB>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RDF::Store::BerkeleyDB


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=RDF-Store-BerkeleyDB>

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

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    L<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


=cut

1; # End of RDF::Store::BerkeleyDB

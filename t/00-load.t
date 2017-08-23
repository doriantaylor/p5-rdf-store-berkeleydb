#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 3;

BEGIN {
    use_ok( 'RDF::Store::BerkeleyDB' ) || print "Bail out!\n";
    use_ok( 'RDF::Store::BerkeleyDB::Trine' ) || print "Bail out!\n";
    use_ok( 'RDF::Store::BerkeleyDB::Attean' ) || print "Bail out!\n";
}

diag( "Testing RDF::Store::BerkeleyDB $RDF::Store::BerkeleyDB::VERSION, Perl $], $^X" );

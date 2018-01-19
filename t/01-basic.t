#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

plan tests => 1;

use_ok('RDF::Store::BerkeleyDB');

my $store = RDF::Store::BerkeleyDB->new(dir => '/tmp/bezerkeley');
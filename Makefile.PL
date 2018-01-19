use 5.014;
use strict;
use warnings;
use inc::Module::Install;

name        'RDF-Store-BerkeleyDB';
readme_from 'lib/RDF/Store/BerkeleyDB.pm';
all_from    'lib/RDF/Store/BerkeleyDB.pm';
author      q{Dorian Taylor <dorian@cpan.org>};
license     'apache';

perl_version 5.014;

tests_recursive('t');

resources (
   homepage   => 'https://github.com/doriantaylor/p5-rdf-store-berkeleydb',
   license    => 'http://www.apache.org/licenses/LICENSE-2.0',
   repository => 'git://github.com/doriantaylor/p5-rdf-store-berkeleydb.git',
   bugtracker => 'https://github.com/doriantaylor/p5-rdf-store-berkeleydb/issues',
);

configure_requires (
   'Module::Install' => 0,
);

build_requires (
   'Test::More' => 0,
);

requires (
    'Moo'         => '2.003',
    'Throwable'   => '0.200013',
    'Try::Tiny'   => '0.22',
    'BerkeleyDB'  => '0.55',
    'Digest'      => '1.17',
    'Path::Class' => '0.35',
    'URI'         => '1.69',
    'IRI'         => '0.008',
    'URI::BNode'  => '0.06',
);

install_as_cpan;
auto_install;
WriteAll;

use strict;
use warnings;

use Wikidata::API;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Wikidata::API::VERSION, 0.01, 'Version.');

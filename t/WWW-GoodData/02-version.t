use strict;
use warnings;

use WWW::GoodData;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($WWW::GoodData::VERSION, 1.12, 'Version.');

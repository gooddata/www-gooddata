use strict;
use warnings;

use LWP::Authen::Gooddata;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($LWP::Authen::Gooddata::VERSION, 1.12, 'Version.');

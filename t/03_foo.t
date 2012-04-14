use strict;
use warnings;
use utf8;
use Test::More;
use lib 't/lib/';

use Foo;

is(hello("John"), "Hello, John");

done_testing;


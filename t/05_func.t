use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

test_nana(<<'CODE', <<'OUT', <<'ERR');
say("OK");
CODE
OK
OUT
ERR

done_testing;


use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

my $ret = eval_nana("[1,2,3].push(4)");
is_deeply($ret, [1,2,3,4]);

is(eval_nana("1-2-3"), 1-2-3);
is(eval_nana("1-2+3"), 1-2+3);
is(eval_nana("1/2/3"), 1/2/3);
is(eval_nana("1**2**3"), 1**2**3);

done_testing;


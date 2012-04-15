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
is(eval_nana("-3"), -3);
is(eval_nana("+3"), +3);
is(eval_nana("~3"), ~3);
is(eval_nana("2*3*4"), 2*3*4);
is(eval_nana("2%3%4"), 2%3%4);
is(eval_nana("2>>3>>4"), 2>>3>>4, '2>>3>>4');
is_deeply(eval_nana("{1=>2}"), {1=>2});
is_deeply(eval_nana("{1=>2,}"), {1=>2,});
is_deeply(eval_nana("{1=>2,3=>4}"), {1=>2,3=>4});
is_deeply(eval_nana("qw(1 2 3)"), [qw(1 2 3)]);
is_deeply(eval_nana("qw(a b 'c)"), [qw(a b 'c)]);
is(eval_nana("0xcc"), 0xcc);

done_testing;


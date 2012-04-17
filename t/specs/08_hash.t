use strict;
use warnings;
use utf8;
use Test::More;
use Test::Base;
use t::Util;

run {
    my $block = shift;
    test_nana($block->code, $block->stdout, $block->stderr);
};

done_testing;

__DATA__

===
--- code
say("YO");
--- stdout
YO
--- stderr

===
--- code
--- stdout
--- stderr

===
--- code
for {1 => 2, 3 => 4}.keys() -> {
    say($_);
}
--- stdout
1
3
--- stderr


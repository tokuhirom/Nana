use strict;
use warnings;
use utf8;
use Test::More;
use t::Util;

note("class method");
test_nana(<<'CODE', <<'OUT', <<'ERR');
class Foo {
    sub bar() {
        say("OK");
    }
}
Foo.bar();
CODE
OK
OUT
ERR

test_nana(<<'CODE', <<'OUT', <<'ERR');
my $a = [1,2,3];
$a.push(4);
for $a -> {
    say($_);
}
CODE
1
2
3
4
OUT
ERR

done_testing;


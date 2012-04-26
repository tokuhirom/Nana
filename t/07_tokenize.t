use strict;
use warnings;
use utf8;
use Test::Base;
use Nana::Parser;

plan tests => 2*blocks;

filters {
    used => ['chomp'],
    token => ['chomp'],
};

run {
    my $block = shift;
    my ($used, $token_id) = Nana::Parser::_token_op($block->src);
    is($used, $block->used);
    is($token_id, Nana::Parser->can($block->token)->());
    $block->src
};

__END__

===
--- src
++
--- used
2
--- token
TOKEN_PLUSPLUS

===
--- src
**
--- used
2
--- token
TOKEN_MULMUL

===
--- src
>>
--- used
2
--- token
TOKEN_RSHIFT

===
--- src
>>=
--- used
3
--- token
TOKEN_RSHIFT_ASSIGN

===
--- src
>
--- used
1
--- token
TOKEN_LT

===
--- src
&
--- used
1
--- token
TOKEN_AND

===
--- src
&&
--- used
2
--- token
TOKEN_ANDAND

===
--- src
&=
--- used
2
--- token
TOKEN_AND_ASSIGN

===
--- src
 &&
--- used
3
--- token
TOKEN_ANDAND

===
--- src
||
--- used
2
--- token
TOKEN_OROR

===
--- src
||=
--- used
3
--- token
TOKEN_OROR_ASSIGN

===
--- src
.
--- used
1
--- token
TOKEN_DOT

===
--- src
..
--- used
2
--- token
TOKEN_DOTDOT

===
--- src
...
--- used
3
--- token
TOKEN_DOTDOTDOT

===
--- src
^
--- used
1
--- token
TOKEN_XOR

===
--- src
^=
--- used
2
--- token
TOKEN_XOR_ASSIGN

===
--- src
-f
--- used
2
--- token
TOKEN_FILETEST

===
--- src
->
--- used
2
--- token
TOKEN_LAMBDA

===
--- src
-=
--- used
2
--- token
TOKEN_MINUS_ASSIGN

===
--- src
+=
--- used
2
--- token
TOKEN_PLUS_ASSIGN

===
--- src
==
--- used
2
--- token
TOKEN_EQUAL_EQUAL

===
--- src
,
--- used
1
--- token
TOKEN_COMMA

===
--- src
%
--- used
1
--- token
TOKEN_MOD

===
--- src
%=
--- used
2
--- token
TOKEN_MOD_EQUAL

===
--- src
/=
--- used
2
--- token
TOKEN_DIV_EQUAL

===
--- src
/
--- used
1
--- token
TOKEN_DIV

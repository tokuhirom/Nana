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

sub eeeol {
    local $_ = shift;
    s/\n$//;
    $_;
}

run {
    my $block = shift;
    my ($used, $token_id) = Nana::Parser::_token_op($block->src);
    is($used, $block->used || length($block->src), eeeol($block->src));
    my $code = Nana::Parser->can($block->token)
        or die "Unknown token: " . $block->token;
    is($token_id, $code->());
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
TOKEN_POW

===
--- src
*=
--- used
2
--- token
TOKEN_MUL_ASSIGN

===
--- src
*
--- used
1
--- token
TOKEN_MUL

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
/
--- used
1
--- token
TOKEN_DIV

===
--- src
==
--- used
2
--- token
TOKEN_EQUAL_EQUAL

===
--- src
!=
--- used
2
--- token
TOKEN_NOT_EQUAL

===
--- src
<=>
--- used
3
--- token
TOKEN_CMP

===
--- src
<
--- used
1
--- token
TOKEN_GT

===
--- src
>
--- used
1
--- token
TOKEN_LT

===
--- src
<=
--- used
2
--- token
TOKEN_GE

===
--- src
>=
--- used
2
--- token
TOKEN_LE

===
--- src: -=
--- token: TOKEN_MINUS_ASSIGN

===
--- src: >>=
--- token: TOKEN_RSHIFT_ASSIGN

===
--- src: %=
--- token: TOKEN_MOD_ASSIGN

===
--- src: =
--- token: TOKEN_ASSIGN

===
--- src: +=
--- token: TOKEN_PLUS_ASSIGN

===
--- src: <<=
--- token: TOKEN_LSHIFT_ASSIGN

===
--- src: **=
--- used: 3
--- token: TOKEN_POW_ASSIGN

===
--- src: /=
--- token: TOKEN_DIV_ASSIGN

===
--- src: ^=
--- token: TOKEN_XOR_ASSIGN

===
--- src: *=
--- token: TOKEN_MUL_ASSIGN

===
--- src: &=
--- token: TOKEN_AND_ASSIGN

===
--- src: |=
--- token: TOKEN_OR_ASSIGN

===
--- src: ${
--- token: TOKEN_DEREF

===
--- src: \
--- token: TOKEN_REF

===
--- src: [
--- token: TOKEN_LBRACKET

===
--- src: "
--- token: TOKEN_STRING_DQ

===
--- src: qq{
--- token: TOKEN_STRING_QQ_START

===
--- src: <<'
--- token: TOKEN_HEREDOC_SQ_START

===
--- src: b'
--- token: TOKEN_BYTES_SQ

===
--- src: b"
--- token: TOKEN_BYTES_DQ

===
--- src: (
--- token: TOKEN_LPAREN

use strict;
use warnings;
use utf8;
use Test::Base;
use Nana::Parser;

plan 'no_plan';

filters {
    used => ['chomp'],
    token => ['chomp'],
};

sub eeeol {
    local $_ = shift;
    s/\n$//;
    s/^(\d+)$/+$1/;
    $_;
}

run {
    my $block = shift;
    my ($used, $token_id, $val) = Nana::Parser::_token_op($block->src);
    is($used, $block->used || length($block->src), eeeol($block->src));
    my $code = Nana::Parser->can($block->token)
        or die "Unknown token: " . $block->token;
    is($token_id, $code->());
    if (defined $block->lval) {
        is($val, $block->lval);
    }
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

===
--- src: classA
--- token: TOKEN_IDENT
--- lval: classA

===
--- src: class
--- token: TOKEN_CLASS

===
--- src: return
--- token: TOKEN_RETURN

===
--- src: use
--- token: TOKEN_USE

===
--- src: 0
--- token: TOKEN_INTEGER
--- lval: 0

===
--- src: 4649
--- token: TOKEN_INTEGER
--- lval: 4649

===
--- src: 0xdeadbeef
--- token: TOKEN_INTEGER
--- lval: 3735928559

===
--- src: 0.5
--- token: TOKEN_DOUBLE
--- lval: 0.5

===
--- src: 0.0
--- token: TOKEN_DOUBLE
--- lval: 0

===
--- src: Foo::Bar
--- token: TOKEN_CLASS_NAME
--- lval: Foo::Bar

===
--- src: $var
--- token: TOKEN_VARIABLE
--- lval: $var

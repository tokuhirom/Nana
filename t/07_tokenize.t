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

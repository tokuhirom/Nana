use strict;
use warnings;
use utf8;
use Test::More;
use Nana::Parser;

{
    my ($used, $token_id) = Nana::Parser::_token_op("++");
    is($used, 2);
    is($token_id, Nana::Parser::TOKEN_PLUSPLUS);
}

done_testing;

use strict;
use warnings;
use utf8;
use Test::More;
use Nana::Parser;
use Data::Dumper;

is_deeply(Nana::Translator::Perl::Runtime::tora_boolean(1), JSON::XS::true());
is_deeply(Nana::Translator::Perl::Runtime::tora_boolean(0), JSON::XS::true());
is_deeply(Nana::Translator::Perl::Runtime::tora_boolean(undef), JSON::XS::false());
is_deeply(Nana::Translator::Perl::Runtime::tora_boolean(JSON::XS::true()), JSON::XS::true());
is_deeply(Nana::Translator::Perl::Runtime::tora_boolean(JSON::XS::false()), JSON::XS::false());

done_testing;


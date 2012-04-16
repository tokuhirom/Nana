package Nana::Translator::Perl::Builtins;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);
use 5.10.0;

our @EXPORT = qw(%TORA_BUILTINS);

our %TORA_BUILTINS = (
    'say' => sub {
        say(@_);
    },
    'stat' => sub {
        return File::stat::stat(@_);
    },
    'open' => sub {
        ...
    },
);

1;


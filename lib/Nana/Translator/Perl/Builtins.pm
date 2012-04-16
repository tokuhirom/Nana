package Nana::Translator::Perl::Builtins;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);
use 5.10.0;

our @EXPORT = qw(
    %TORA_BUILTIN_FUNCTIONS
    %TORA_BUILTIN_CLASSES
);

our %TORA_BUILTIN_FUNCTIONS = (
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

our %TORA_BUILTIN_CLASSES = (
    'Array' => {
        push => sub {
            CORE::push(@{$_[0]}, $_[1]);
            $_[0];
        },
    },
);


1;


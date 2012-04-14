package Nana::Translator::Perl::Type::ARRAY;
use strict;
use warnings;
use utf8;

sub push {
    my $arr = CORE::shift;
    CORE::push(@$arr, @_);
    return $arr;
}

1;


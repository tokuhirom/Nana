package Nana::Translator::Perl::Bytes;
use strict;
use warnings;
use utf8;

sub new {
    my ($class, $data) = @_;
    bless [$data], $class;
}

sub data { shift->[0] }

1;


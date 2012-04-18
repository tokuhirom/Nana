package Nana::Translator::Perl::Class;
use strict;
use warnings;
use utf8;

sub new {
    my ($class, $name, $klass) = @_;
    CORE::bless {__tora_name => $name, klass => $klass}, $class;
}

sub name {
    my $self = shift;
    return $self->{__tora_name};
}

1;


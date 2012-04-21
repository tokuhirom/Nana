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

sub get_method {
    my ($self, $name) = @_;
    return $self->{$name};
}

sub add_method {
    my ($self, $name, $code) = @_;
    $self->{$name} = $code;
    undef;
}

1;


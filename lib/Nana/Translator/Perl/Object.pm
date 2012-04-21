package Nana::Translator::Perl::Object;
use strict;
use warnings;
use utf8;

sub new {
    my ($class, $klass, $data) = @_;
    bless {klass => $klass, data => $data}, $class;
}

sub data {
    my $self = shift;
    return $self->{data};
}

sub get_method {
    my ($self, $name) = @_;
    return $self->{klass}->get_method($name);
}

sub class {
    my ($self) = @_;
    return $self->{klass};
}

1;


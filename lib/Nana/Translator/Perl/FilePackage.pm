package Nana::Translator::Perl::FilePackage;
use strict;
use warnings;
use utf8;

sub new {
    my ($class, $name) = @_;
    bless {name => $name}, $class;
}

sub add {
    my ($self, $name, $stuff) = @_;
    $self->{$name} = $stuff;
}

sub get {
    my ($self, $name) = @_;
    return $self->{$name};
}

1;


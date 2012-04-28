package Nana::Translator::Perl::Class;
use strict;
use warnings;
use utf8;

sub new {
    my ($class, $name, $superclass) = @_;
    CORE::bless {
        name => $name,
        superclass => $superclass,
        methods => +{},
    }, $class;
}

sub superclass {
    my $self = shift;
    return $self->{superclass};
}

sub name {
    my $self = shift;
    return $self->{name};
}

sub get_method_list {
    my ($self, $name) = @_;
    return [keys %{$self->{methods}}];
}

sub get_method {
    my ($self, $name) = @_;
    return $self->{methods}->{$name};
}

sub add_method {
    my ($self, $name, $code) = @_;
    $self->{methods}->{$name} = $code;
    undef;
}

sub create_instance {
    my ($self, $data) = @_;
    return Nana::Translator::Perl::Object->new(
        $self,
        $data
    );
}

1;


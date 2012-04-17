package Nana::Translator::Perl::Range;
use strict;
use warnings;
use utf8;
use overload
    q{""} => \&stringify;

sub new {
    my ($class, $lhs, $rhs) = @_;
    bless {
        left  => $lhs,
        right => $rhs,
    }, $class;
}

sub stringify {
    my $self = shift;
    $self->{left} . '..' . $self->{right};
}

sub list {
    my $self = shift;
    $self->{left}..$self->{right};
}

1;


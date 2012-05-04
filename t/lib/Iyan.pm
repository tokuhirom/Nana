package Iyan;
use strict;
use warnings;
use utf8;

sub new {
    my ($class, $code) = @_;
    ref $code eq 'CODE' or die "Oops";
    bless [$code], $class;
}

sub run {
    my ($self, $arg) = @_;
    $self->[0]->(Bakan->new($arg));
    return "WOWO!";
}

package Bakan;
sub new {
    my ($class, $stuff) = @_;
    bless [$stuff], shift;
}

sub get {
    return shift->[0];
}

1;


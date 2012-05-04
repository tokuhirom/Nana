package Deep;
use strict;
use warnings;
use utf8;
use Data::Dumper;

sub new {
    my ($class, $stuff) = @_;
    $stuff or die;
    bless [$stuff], $class;
}

sub call {
    my $self = shift;
    $self->[0]->{'callback'}->(Deep::Stuff->new());
}

package Deep::Stuff;

sub new {
    bless [], shift;
}

sub get { 4649 }

1;


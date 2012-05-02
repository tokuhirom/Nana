package Nana::Translator::Perl::Code;
use strict;
use warnings;
use utf8;
use Scalar::Util qw(blessed refaddr);

my %KLASS_FOR;

sub new {
    my ($class, $code, $klass) = @_;
    $KLASS_FOR{refaddr $code} = $klass;
    bless $code, $class;
}

sub class {
    my ($self) = shift;
    return $KLASS_FOR{refaddr $self};
}

1;


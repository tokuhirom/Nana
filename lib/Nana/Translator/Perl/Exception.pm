package Nana::Translator::Perl::Exception;
use strict;
use warnings;
use utf8;

use overload
    q{""} => \&stringify;

sub new {
    my ($class, $e) = @_;
    bless \$e, $class;
}

sub val { ${shift @_} }

sub stringify {
    my ($self) = @_;
    return $$self;
}

1;


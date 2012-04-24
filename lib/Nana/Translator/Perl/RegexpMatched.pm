package Nana::Translator::Perl::RegexpMatched;
use strict;
use warnings;
use utf8;

sub new {
    my ($class, $str) = @_;

    my @parens;
    # see perlvar for @+, @-
    for (my $i=0; $i<@+; $i++) {
        push @parens, substr($str, $-[$i], $+[$i] - $-[$i]);
    }

    return bless {parens => \@parens}, $class;
}

sub parens { $_[0]->{parens} }

1;


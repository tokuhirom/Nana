package Nana::Translator::Perl::Regexp;
use strict;
use warnings;
use utf8;

sub new {
    my ($class, $pattern, $global) = @_;
    bless { pattern => $pattern, global => $global }, $class;
}

sub global  { $_[0]->{global}  }
sub pattern { $_[0]->{pattern} }

1;


package Nana::Filter;
use strict;
use warnings;
use utf8;
use Module::Compile -base;
use Nana::Parser;
use Nana::Translator::Perl;

my $compiler = Nana::Translator::Perl->new();
my $parser = Nana::Parser->new();

sub pmc_compile {
    my ($class, $src, $extra) = @_;

    my $ast = $parser->parse($src);
    my $perl = $compiler->compile($ast);
    return $perl;
}

1;


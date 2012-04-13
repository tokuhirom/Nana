package Tora::Filter;
use strict;
use warnings;
use utf8;
use Module::Compile -base;
use Tora::Parser;
use Tora::Compiler;

my $compiler = Tora::Compiler->new();
my $parser = Tora::Parser->new();

sub pmc_compile {
    my ($class, $src, $extra) = @_;

    my $ast = $parser->parse($src);
    my $perl = $compiler->compile($ast);
    return $perl;
}

1;


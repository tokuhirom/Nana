use strict;
use warnings;
use utf8;
use Test::More;
use Data::Dumper;

use Nana::Compiler;
use Nana::Parser;

my $compiler = Nana::Compiler->new();
my $parser   = Nana::Parser->new();

test("1+2", "1+2");
test('sub foo { 4 }', 'sub foo { 4 }');
test('sub foo { 3+2 }', 'sub foo { 3+2 }');
test('sub foo($var) { 3+2 }', 'sub foo { my $var=shift;3+2 }');
test('sub foo($var, $boo) { 3+2 }', 'sub foo { my $var=shift;my $boo=shift;3+2 }');
test('class Foo { sub new() { } }', '{package Foo;sub new {  }}');

done_testing;

sub test {
    my ($src, $expected) = @_;

    subtest $src, sub {
        my $ast = $parser->parse($src);
        my $perl = $compiler->compile($ast, my $no_header = 1);
        $perl =~ s/#line .+\n//;
        is($perl, $expected);
    };
}


use strict;
use warnings;
use utf8;
use Test::More;
use Data::Dumper;

use Tora::Compiler;
use Tora::Parser;

my $compiler = Tora::Compiler->new();
my $parser   = Tora::Parser->new();

test("1+2", "1+2");
test('sub foo { 4 }', 'sub foo { 4 }');
test('sub foo { 3+2 }', 'sub foo { 3+2 }');
test('sub foo($var) { 3+2 }', 'sub foo { my $var=shift;3+2 }');
test('sub foo($var, $boo) { 3+2 }', 'sub foo { my $var=shift;my $boo=shift;3+2 }');

done_testing;

sub test {
    my ($src, $expected) = @_;

    subtest $src, sub {
        my $ast = $parser->parse($src);
        my $perl = $compiler->compile($ast, my $no_header = 1);
        is($perl, $expected);
    };
}


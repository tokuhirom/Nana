use strict;
use warnings;
use utf8;
use Test::More;
use Data::Dumper;

use Nana::Translator::Perl;
use Nana::Parser;

my $compiler = Nana::Translator::Perl->new();
my $parser   = Nana::Parser->new();

test("1+2", "(1+2)");
test('sub foo { 4 }', 'sub foo { 4 }');
test('sub foo { 3+2 }', 'sub foo { (3+2) }');
test('sub foo($var) { 3+2 }', 'sub foo { my $var=shift;(3+2) }');
test('sub foo($var, $boo) { 3+2 }', 'sub foo { my $var=shift;my $boo=shift;(3+2) }');
test('class Foo { sub new() { } }', '{package Foo;use Mouse;sub new {  };no Mouse;}');
test(q!class Foo isa Bar { sub new() { } }!, q!{package Foo;use Mouse;BEGIN{extends 'Bar';}sub new {  };no Mouse;}!);
test('if 1 { }', 'if (1) {}');
test('if 1 { 4 }', 'if (1) {4}');
test('if 1 { 4 } else { }', 'if (1) {4} else {}');
test('if 1 { 4 } elsif 3 { } else { }', 'if (1) {4} elsif (3) {} else {}');
test('while 1 {}', 'while (1) {}');
test('"Hello, " ~ $name', '("Hello, ".$name)');
test('return 3', 'return (3);');
test('[1,2,3]', '[1,2,3]');
test('(1+2)*3', '((1+2)*3)');
test('[1,2,3].push(4)', '[1,2,3]->push(4)');
test(<<'...', 'sub hello { my $name=shift;return (("Hello, ".$name)); }');
sub hello($name) {
    return "Hello, " ~ $name;
}
...

done_testing;

sub test {
    my ($src, $expected) = @_;

    subtest $src, sub {
        my $ast = $parser->parse($src);
        my $perl = $compiler->compile($ast, my $no_header = 1);
        $perl =~ s/#line .+\n//;
        local $Test::Builder::Level = $Test::Builder::Level + 6;
        is($perl, $expected);
    };
}


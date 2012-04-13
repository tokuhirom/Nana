use strict;
use warnings;
use utf8;
use Test::More;
use Data::Dumper;

use Tora::Compiler;
use Tora::Parser;

my $compiler = Tora::Compiler->new();
my $parser   = Tora::Parser->new();

my $ast = $parser->parse("1+2");
is($compiler->compile($ast), '1+2');
is($compiler->compile($parser->parse('sub foo { 4 }')), 'sub foo { 4 }');
is($compiler->compile($parser->parse('sub foo { 3+2 }')), 'sub foo { 3+2 }');
is($compiler->compile($parser->parse('sub foo($var) { 3+2 }')), 'sub foo { my $var=shift;3+2 }');
is($compiler->compile($parser->parse('sub foo($var, $boo) { 3+2 }')), 'sub foo { my $var=shift;my $boo=shift;3+2 }');

done_testing;


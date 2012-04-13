use strict;
use warnings;
use utf8;
use Test::More;
use Tora::Parser;
use Carp;

$SIG{INT} = \&confess;

my $parser = Tora::Parser->new();
is_deeply($parser->parse('sub foo($a, $b, $c) { 1 }'), [
    'SUB',
    ['IDENT', 'foo'],
    [map { ['VARIABLE', $_] } qw($a $b $c)],
    ['INT', 1]
]);

is_deeply($parser->parse('qw()'),
    ['QW', []],
);

is_deeply($parser->parse('qw(1 2 3)'),
    ['QW', [qw(1 2 3)]],
);

is_deeply($parser->parse(''),
    ['NOP']
);

done_testing;


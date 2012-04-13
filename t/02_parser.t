use strict;
use warnings;
use utf8;
use Test::More;
use Nana::Parser;
use Carp;
use Data::Dumper;

$SIG{INT} = \&confess;

my $parser = Nana::Parser->new();
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

is_deeply($parser->parse(<<'...'),
class Foo {
    sub new() {
    }
}
...
    [
        'CLASS',
        [ 'IDENT', 'Foo' ],
        [ 'SUB', [ 'IDENT', 'new' ], [ ], [ 'NOP' ] ]
    ]
);

is_deeply($parser->parse('say()'),
    ['CALL', ['IDENT', 'say'], []]
);

done_testing;


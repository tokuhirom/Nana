use strict;
use warnings;
use utf8;
use Test::More;
use Nana::Parser;
use Carp;
use Data::Dumper;
use Test::Differences;

$SIG{INT} = \&confess;

my $parser = Nana::Parser->new();
is_deeply(
    $parser->parse('sub foo($a, $b, $c) { 1 }'),
    [
        'STMTS', 1, [
            [
                'SUB', 1,
                [ 'IDENT', 1, 'foo' ],
                [ map { [ 'VARIABLE', 1, $_ ] } qw($a $b $c) ],
                [ 'INT', 1, 1 ]
            ]
        ]
    ]
);

is_deeply($parser->parse('qw()'),
    ['STMTS', 1, [['QW', 1, []]]],
);

is_deeply($parser->parse('qw(1 2 3)'),
    ['STMTS', 1, [['QW', 1, [qw(1 2 3)]]]],
);

is_deeply($parser->parse(''),
    ['STMTS', 1, []]
);

is_deeply($parser->parse(<<'...'),
class Foo {
    sub new() {
    }
}
...
    ['STMTS', 1, [
        [
            'CLASS', 1,
            [ 'IDENT', 1, 'Foo' ],
            [ 'SUB', 2, [ 'IDENT', 2, 'new' ], [ ], [ 'NOP', 3 ] ]
        ]
    ] ]
);

is_deeply($parser->parse('say()'),
    ['STMTS', 1, [['CALL', 1, ['IDENT', 1, 'say'], []]]]
);

is_deeply($parser->parse('1+2;3+4'),
    ['STMTS', 1,
        [
            ['+', 1, ['INT', 1, 1], ['INT', 1, 2]],
            ['+', 1, ['INT', 1, 3], ['INT', 1, 4]]
        ]
    ]
);

eq_or_diff($parser->parse(<<'...'),
1+2
3+4
...
    ['STMTS', 1,
        [
            ['+', 1, ['INT', 1, '1'], ['INT', 1, '2']],
            ['+', 2, ['INT', 2, '3'], ['INT', 2, '4']]
        ]
    ]
);

done_testing;


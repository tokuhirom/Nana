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
eq_or_diff(
    $parser->parse('sub foo($a, $b, $c) { 1 }'),
    [
        'STMTS', 1, [
            [
                'SUB', 1,
                [ 'IDENT', 1, 'foo' ],
                [ map { [ 'VARIABLE', 1, $_ ] } qw($a $b $c) ],
                [BLOCK => 1,
                    [ 'STMTS', 1, [[ 'INT', 1, '1' ]]],
                ]
            ]
        ]
    ]
);

is_deeply($parser->parse('qw()'),
    ['STMTS', 1, [['QW', 1, []]]],
);
is_deeply($parser->parse('[]'),
    ['STMTS', 1, [['ARRAY', 1, []]]],
);

is_deeply($parser->parse('qw(1 2 3)'),
    ['STMTS', 1, [['QW', 1, [qw(1 2 3)]]]],
);

is_deeply($parser->parse(''),
    ['STMTS', 1, []]
);

eq_or_diff($parser->parse(<<'...'),
class Foo {
    sub new() {
    }
}
...
    ['STMTS', 1, [
        [
            'CLASS', 1,
            [ 'IDENT', 1, 'Foo' ],
            undef,
            [BLOCK => 1, [
                'STMTS', 1, [
                    [ 'SUB', 2, [ 'IDENT', 2, 'new' ], [ ], [BLOCK => 2, ['STMTS', 2, []]] ]
                ]
            ]]
        ]
    ] ]
);

is_deeply($parser->parse('say()'),
    ['STMTS', 1, [['CALL', 1, ['PRIMARY_IDENT', 1, 'say'], []]]]
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

eq_or_diff($parser->parse(<<'...'),
"hoge"+"fuga"
...
    ['STMTS', 1, [
        ['+', 1,
            ['STR2', 1, \'hoge'],
            ['STR2', 1, \'fuga'],
        ]
    ]]
);

eq_or_diff($parser->parse(<<'...'),
say("hoge"+"fuga")
...
    ['STMTS', 1, [
        ['CALL', 1,
            [
                'PRIMARY_IDENT',
                1,
                'say',
            ],
            [
                ['+', 1,
                    ['STR2', 1, \'hoge'],
                    ['STR2', 1, \'fuga'],
                ]
            ]
        ]
    ]]
);

eq_or_diff($parser->parse(<<'...'),
if 1 { }
...
    ['STMTS', 1, [
        ['IF', 1,
            [
                'INT',
                1,
                '1',
            ],
            [
                BLOCK => 1, [
                    'STMTS', 1, [ ]
                ]
            ],
            undef
        ]
    ]]
);

eq_or_diff($parser->parse(<<'...'),
if 1 { } else { }
...
    ['STMTS', 1, [
        ['IF', 1,
            [
                'INT',
                1,
                '1',
            ],
            [
                'BLOCK', 1, [
                    'STMTS', 1, [ ]
                ]
            ],
            [
                'ELSE', 1, [
                    BLOCK => 1, [
                        'STMTS', 1, [ ]
                    ]
                ]
            ]
        ]
    ]]
);


done_testing;


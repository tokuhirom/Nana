use strict;
use warnings;
use utf8;
use Test::More;
use Nana::Parser;
use Carp;
use Data::Dumper;
use Test::Differences;
use Nana::Node;

$SIG{INT} = \&confess;

my $parser = Nana::Parser->new();
eq_or_diff(
    $parser->parse('sub foo($a, $b, $c) { 1 }'),
    [
        NODE_STMTS, 1, [
            [
                NODE_SUB, 1,
                [ NODE_IDENT, 1, 'foo' ],
                [ map { [ NODE_VARIABLE, 1, $_ ] } qw($a $b $c) ],
                [NODE_BLOCK() => 1,
                    [ NODE_STMTS, 1, [[ NODE_INT, 1, 1 ]]],
                ]
            ]
        ]
    ]
);

is_deeply($parser->parse('qw()'),
    [NODE_STMTS, 1, [[NODE_QW, 1, []]]],
);
is_deeply($parser->parse('[]'),
    [NODE_STMTS, 1, [[NODE_MAKE_ARRAY, 1, []]]],
);

is_deeply($parser->parse('qw(1 2 3)'),
    [NODE_STMTS, 1, [[NODE_QW, 1, [qw(1 2 3)]]]],
);

is_deeply($parser->parse(''),
    [NODE_STMTS, 1, []],
    'empty'
);

eq_or_diff($parser->parse(<<'...'),
class Foo {
    sub new() {
    }
}
...
    [NODE_STMTS, 1, [
        [
            NODE_CLASS, 1,
            [ NODE_IDENT, 1, 'Foo' ],
            undef,
            [NODE_BLOCK() => 1, [
                NODE_STMTS, 2, [
                    [ NODE_SUB, 2, [ NODE_IDENT, 2, 'new' ], [ ], [NODE_BLOCK() => 2, [NODE_STMTS, 3, []]] ]
                ]
            ]]
        ]
    ] ]
);

is_deeply($parser->parse('say()'),
    [NODE_STMTS, 1, [[NODE_CALL, 1, [NODE_PRIMARY_IDENT, 1, 'say'], []]]]
);

is_deeply($parser->parse('1+2;3+4'),
    [NODE_STMTS, 1,
        [
            [NODE_PLUS, 1, [NODE_INT, 1, 1], [NODE_INT, 1, 2]],
            [NODE_PLUS, 1, [NODE_INT, 1, 3], [NODE_INT, 1, 4]]
        ]
    ], '1+2;3+4'
);

eq_or_diff($parser->parse(<<'...'),
1+2
3+4
...
    [NODE_STMTS, 1,
        [
            [NODE_PLUS, 1, [NODE_INT, 1, 1], [NODE_INT, 1, 2]],
            [NODE_PLUS, 2, [NODE_INT, 2, 3], [NODE_INT, 2, 4]]
        ]
    ]
);

eq_or_diff($parser->parse(<<'...'),
"hoge"+"fuga"
...
    [NODE_STMTS, 1, [
        [NODE_PLUS, 1,
            [NODE_STR2, 1, \'hoge'],
            [NODE_STR2, 1, \'fuga'],
        ]
    ]]
);

eq_or_diff($parser->parse(<<'...'),
say("hoge"+"fuga")
...
    [NODE_STMTS, 1, [
        [NODE_CALL, 1,
            [
                NODE_PRIMARY_IDENT,
                1,
                'say',
            ],
            [
                [NODE_PLUS, 1,
                    [NODE_STR2, 1, \'hoge'],
                    [NODE_STR2, 1, \'fuga'],
                ]
            ]
        ]
    ]]
);

eq_or_diff($parser->parse(<<'...'),
if 1 { }
...
    [NODE_STMTS, 1, [
        [NODE_IF, 1,
            [
                NODE_INT,
                1,
                1,
            ],
            [
                NODE_BLOCK() => 1, [
                    NODE_STMTS, 1, [ ]
                ]
            ],
            undef
        ]
    ]]
);

eq_or_diff($parser->parse(<<'...'),
if 1 { } else { }
...
    [NODE_STMTS, 1, [
        [NODE_IF, 1,
            [
                NODE_INT,
                1,
                1,
            ],
            [
                NODE_BLOCK, 1, [
                    NODE_STMTS, 1, [ ]
                ]
            ],
            [
                NODE_ELSE, 1, [
                    NODE_BLOCK() => 1, [
                        NODE_STMTS, 1, [ ]
                    ]
                ]
            ]
        ]
    ]]
);


done_testing;


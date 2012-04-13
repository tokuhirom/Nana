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

done_testing;


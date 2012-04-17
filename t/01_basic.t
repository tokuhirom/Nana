use strict;
use warnings;
use utf8;
use 5.10.0;
use Test::More;
use Data::Dumper;

use Nana::Translator::Perl;
use Nana::Parser;

my $compiler = Nana::Translator::Perl->new();
my $parser   = Nana::Parser->new();

sub eeeeol { local $_ = shift; s/\n$//; $_ }

my $dat = join '', <DATA>;
for my $case (grep { /\S/ } split /^--- input\n/sm, $dat) {
    if (my ($input, $expected) = ($case =~ /^(.+)\n--- expected\n(.+?)\n*$/s)) {
        test($input, $expected);
    } else {
        die "parse failed in test case:" . $case;
    }
}

done_testing;

sub test {
    my ($src, $expected) = @_;

    subtest $src, sub {
        my $ast = $parser->parse($src);
        my $perl = $compiler->compile($ast, my $no_header = 1);
        $perl =~ s/#line .+\n//g;
        $perl =~ s/;$//;
        $perl =~ s/;;/;/g;
        $perl =~ s/\n$//;
        local $Test::Builder::Level = $Test::Builder::Level + 6;
        is(eeeeol($perl), eeeeol($expected)) or note(Dumper($ast, $src));
    };
}

__DATA__
--- input
say(<<'PPP', <<'MMM')
hoho
PPP
fufu
MMM
--- expected
tora_call_func($TORA_PACKAGE, q{say}, (scalar('hoho
'),scalar('fufu
')))

--- input
foo() if bar()
--- expected
if (tora_call_func($TORA_PACKAGE, q{bar}, ())) {tora_call_func($TORA_PACKAGE, q{foo}, ())}

--- input
foo() unless bar()
--- expected
unless (tora_call_func($TORA_PACKAGE, q{bar}, ())) {tora_call_func($TORA_PACKAGE, q{foo}, ())}

--- input
foo() for bar()
--- expected
{my $__tora_iteratee = (tora_call_func($TORA_PACKAGE, q{bar}, ()));
for (ref($__tora_iteratee) eq "ARRAY" ? @{$__tora_iteratee} : ref($__tora_iteratee) eq "Nana::Translator::Perl::Range" ? $__tora_iteratee->list : $__tora_iteratee) {
tora_call_func($TORA_PACKAGE, q{foo}, ())}}

--- input
foo() while bar()
--- expected
while (tora_call_func($TORA_PACKAGE, q{bar}, ())) {tora_call_func($TORA_PACKAGE, q{foo}, ())}

--- input
1+2
--- expected
tora_op_add(1,2)

--- input
sub foo { 4 }
--- expected
$TORA_PACKAGE->{q{foo}} = sub {
4;
 }

--- input
sub foo { 3+2 }
--- expected
$TORA_PACKAGE->{q{foo}} = sub {
tora_op_add(3,2);
 }

--- input
sub foo($var) { 3+2 }
--- expected
$TORA_PACKAGE->{q{foo}} = sub {
my $var=shift;tora_op_add(3,2);
 }

--- input
sub foo($var, $boo) { 3+2 }
--- expected
$TORA_PACKAGE->{q{foo}} = sub {
my $var=shift;my $boo=shift;tora_op_add(3,2);
 }

--- input
class Foo { sub new() { } }
--- expected
{my $TORA_CLASS=($TORA_PACKAGE->{q{Foo}} = +{});
$TORA_CLASS->{q{new}} = sub {
 };
;}

--- input
class Foo isa Bar { sub new() { } }
--- expected
{my $TORA_CLASS=($TORA_PACKAGE->{q{Foo}} = +{});BEGIN{extends 'q{Bar}';}
$TORA_CLASS->{q{new}} = sub {
 };
;}

--- input
if 1 { }
--- expected
if (1) {}

--- input
if 1 { 4 }
--- expected
if (1) {4;
}

--- input
if 1 { 4 } else { }
--- expected
if (1) {4;
} else {}

--- input
if 1 { 4 } elsif 3 { } else { }
--- expected
if (1) {4;
} elsif (3) {} else {}

--- input
while 1 {}
--- expected
while (1) {}

--- input
"Hello, " ~ $name
--- expected
("Hello, ".$name)

--- input
return 3
--- expected
return (3);

--- input
[1,2,3]
--- expected
[1,2,3]

--- input
(1+2)*3
--- expected
((tora_op_add(1,2))*3)

--- input
1-2-3
--- expected
((1-2)-3)

--- input
1/2/3
--- expected
((1/2)/3)

--- input
1**2**3
--- expected
(1**(2**3))

--- input
1=~2=~3
--- expected
((1=~2)=~3)

--- input
1-2+3
--- expected
tora_op_add((1-2),3)

--- input
1*2*3
--- expected
((1*2)*3)

--- input
1%2%3
--- expected
((1%2)%3)

--- input
1x2x3
--- expected
((1 x 2) x 3)

--- input
1>>2>>3
--- expected
((1>>2)>>3)

--- input
1<<2<<3
--- expected
((1<<2)<<3)

--- input
1<2
--- expected
tora_op_lt(1,2)

--- input
1==2
--- expected
tora_op_equal(1,2)

--- input
1?2:3
--- expected
((1)?(2):(3))

--- input
$x=$y=$z
--- expected
($x=($y=$z))

--- input
1..2
--- expected
tora_make_range(1,2)

--- input
1,2,3
--- expected
((1,2),3)

--- input
[1,2,3].push(4)
--- expected
tora_call_method($TORA_PACKAGE, [1,2,3], q{push}, (4))

--- input
sub hello($name) {
    return "Hello, " ~ $name;
}
--- expected
$TORA_PACKAGE->{q{hello}} = sub {
my $name=shift;return (("Hello, ".$name));
 }

--- input
$i++
--- expected
($i)++

--- input
$i--
--- expected
($i)--

--- input
++$i
--- expected
++($i)

--- input
--$i
--- expected
--($i)

--- input
$i**$j
--- expected
($i**$j)

--- input
unless undef { 3 }
--- expected
unless (undef) {3;
}

--- input
(my $x, my $y)
--- expected
((my ($x),my ($y)))

--- input
my $x
--- expected
my ($x)

--- input
my ($x, $y, $z)
--- expected
my ($x, $y, $z)

--- input
do { 1; 2; }
--- expected
do {
1;
2;
}

--- input
1 and 2
--- expected
(1 and 2)

--- input
1 or 2
--- expected
(1 or 2)

--- input
1 xor 2
--- expected
(1 xor 2)

--- input
0
--- expected
0

--- input
1 && 2
--- expected
(1&&2)

--- input
1 || 2
--- expected
(1||2)

--- input
1 | 2
--- expected
(1|2)

--- input
1 & 2
--- expected
(1&2)

--- input
for 1..10 -> { }
--- expected
{my $__tora_iteratee = (tora_make_range(1,10));
for (ref($__tora_iteratee) eq "ARRAY" ? @{$__tora_iteratee} : ref($__tora_iteratee) eq "Nana::Translator::Perl::Range" ? $__tora_iteratee->list : $__tora_iteratee) {
}}

--- input
for 1..10 -> $i { }
--- expected
{my $__tora_iteratee = (tora_make_range(1,10));
for my $i(ref($__tora_iteratee) eq "ARRAY" ? @{$__tora_iteratee} : ref($__tora_iteratee) eq "Nana::Translator::Perl::Range" ? $__tora_iteratee->list : $__tora_iteratee) {
}}

--- input
has()
--- expected
tora_call_func($TORA_PACKAGE, q{has}, ())

--- input
has(1)
--- expected
tora_call_func($TORA_PACKAGE, q{has}, (scalar(1)))

--- input
has(1,2)
--- expected
tora_call_func($TORA_PACKAGE, q{has}, (scalar(1),scalar(2)))

--- input
has("foo")
--- expected
tora_call_func($TORA_PACKAGE, q{has}, (scalar("foo")))

--- input
classA()
--- expected
tora_call_func($TORA_PACKAGE, q{classA}, ())

--- input
//
--- expected
//

--- input
/\//
--- expected
/\//

--- input
/hoge/xsmi
--- expected
/hoge/xsmi


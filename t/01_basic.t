use strict;
use warnings;
use utf8;
use 5.10.0;
use Test::More;
use Test::Base;
use Data::Dumper;

use Nana::Translator::Perl;
use Nana::Parser;

my $compiler = Nana::Translator::Perl->new();
my $parser   = Nana::Parser->new();

sub eeeeol { local $_ = shift; s/\n$//; $_ }

spec_file('t/01_basic.dat');

my $ofh;
if ($ENV{REGEN}) {
    open $ofh, '>', 't/01_basic.dat'
        or die;
}

plan tests => blocks()*1;

run {
    my $block = shift;
    my ($input, $expected) = ($block->input, $block->expected);

    test($input, $expected);
};

sub test {
    my ($src, $expected) = @_;

    note $src;
    my $ast = $parser->parse($src);
    my $perl = $compiler->compile($ast, my $no_header = 1);
    $perl =~ s/#line .+\n//g;
    $perl =~ s/;$//;
    $perl =~ s/;;/;/g;
    $perl =~ s/\n$//;

    if ($ENV{REGEN}) {
        print $ofh "===\n";
        print $ofh "--- input\n";
        print $ofh $src . "\n";
        print $ofh "--- expected\n";
        print $ofh $perl . "\n";
        print $ofh "\n";
    }

    local $Test::Builder::Level = $Test::Builder::Level + 6;
    is(eeeeol($perl), eeeeol($expected)) or note(Dumper($ast, $src));
}


package t::Util;
use strict;
use warnings;
use utf8;
use Nana::Parser;
use Nana::Translator::Perl;
use Test::More;
use Data::Dumper;
use base qw(Exporter);
our @EXPORT = qw(eval_nana);

sub eval_nana {
    my $src = shift;
    my $parser   = Nana::Parser->new();
    my $compiler = Nana::Translator::Perl->new();
    my $ast = $parser->parse($src);
    my $perl = $compiler->compile($ast);
    warn Dumper($ast) if $ENV{DEBUG};
    warn $perl if $ENV{DEBUG};
    my $ret = eval $perl;
    if ($@) {
        Test::More::diag $perl;
    }
    die $@ if $@;
    return $ret;
}

1;


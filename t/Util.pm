package t::Util;
use strict;
use warnings FATAL => 'all';
use utf8;
use lib 'lib';
use Capture::Tiny qw(capture);
use Nana::Parser;
use Nana::Translator::Perl;
use Test::More;
use Data::Dumper;
use base qw(Exporter);
our @EXPORT = qw(eval_nana test_nana run_tora_is);

sub eval_nana {
    my $src = shift;
    my $parser   = Nana::Parser->new();
    my $compiler = Nana::Translator::Perl->new();
    my $ast = $parser->parse($src);
    my $perl = $compiler->compile($ast, 0);
    warn Dumper($ast) if $ENV{DUMP_AST};
    warn $perl if $ENV{DUMP_PERL};
    my $ret = do {
        no warnings;
        eval $perl;
    };
    if ($@) {
        Test::More::diag $perl;
    }
    die $@ if $@;
    return $ret;
}

sub test_nana {
    my ($src, $expected_stdout, $expected_stderr) = @_;
    my ($stdout, $stderr) = capture {
        eval {
            eval_nana($src);
        };
        warn $@ if $@;
    };
    subtest $src => sub {
        is($stdout, $expected_stdout,       'stdout');
        is($stderr, $expected_stderr || '', 'stderr');
    };
}
*run_tora_is = *test_nana;

1;


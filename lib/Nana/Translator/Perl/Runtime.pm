package Nana::Translator::Perl::Runtime;
use strict;
use warnings;
use utf8;

use parent qw(Exporter);
use Nana::Translator::Perl::Builtins;
use Carp qw(croak);

our @EXPORT = qw(tora_call_func);

sub tora_call_func {
    my ($funname, @args) = @_;
    my $func = $TORA_BUILTINS{$funname};
    if ($func) {
        $func->(@args);
    } else {
        croak "Unknown function $funname";
    }
}

1;


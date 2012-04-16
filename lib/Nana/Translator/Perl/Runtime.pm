package Nana::Translator::Perl::Runtime;
use strict;
use warnings FATAL => 'all';
use utf8;

use parent qw(Exporter);
use Nana::Translator::Perl::Builtins;
use Carp qw(croak);

our @EXPORT = qw(tora_call_func);

sub tora_call_func {
    my ($pkg, $funname, @args) = @_;
    if (my $func = $pkg->{$funname}) {
        return $func->(@args);
    } else {
        my $func = $TORA_BUILTINS{$funname};
        if ($func) {
            return $func->(@args);
        } else {
            croak "Unknown function $funname";
        }
    }
}

1;


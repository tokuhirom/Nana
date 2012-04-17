package Nana::Translator::Perl::Runtime;
use strict;
use warnings FATAL => 'all';
use utf8;

use parent qw(Exporter);
use Nana::Translator::Perl::Builtins;
use Carp qw(croak);

our @EXPORT = qw(tora_call_func tora_call_method);

sub tora_call_func {
    my ($pkg, $funname, @args) = @_;
    if (my $func = $pkg->{$funname}) {
        return $func->(@args);
    } else {
        my $func = $TORA_BUILTIN_FUNCTIONS{$funname};
        if ($func) {
            return $func->(@args);
        } else {
            croak "Unknown function $funname";
        }
    }
}

sub tora_call_method {
    my ($pkg, $klass, $methname, @args) = @_;
    if (my $klaas = $pkg->{$klass}) {
        if (my $methbody = $klaas->{$methname}) {
            return $methbody->(@args);
        } else {
            die "Unknown method named $methname in $klass";
        }
    } else {
        # builtin methods
        if (ref $klass eq 'ARRAY') {
            if (my $methbody = $TORA_BUILTIN_CLASSES{Array}->{$methname}) {
                return $methbody->($klass, @args);
            } else {
                die "Unknown method $methname in Array";
            }
        } elsif (ref $klass eq 'HASH') {
            if (my $methbody = $TORA_BUILTIN_CLASSES{Hash}->{$methname}) {
                return $methbody->($klass, @args);
            } else {
                die "Unknown method $methname in Hash";
            }
        } else {
            die "unknown class: $klass";
        }
    }
}

1;


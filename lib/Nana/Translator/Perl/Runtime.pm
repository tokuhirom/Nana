package Nana::Translator::Perl::Runtime;
use strict;
use warnings FATAL => 'all';
use utf8;
use 5.10.0;

use parent qw(Exporter);
use Nana::Translator::Perl::Builtins;
use Nana::Translator::Perl::Range;
use Carp qw(croak);
use B;
use JSON ();

our @EXPORT = qw(tora_call_func tora_call_method tora_op_equal
    tora_op_lt tora_op_gt
    tora_op_le tora_op_ge
    tora_make_range
    tora_op_add
);

*true = *JSON::true;
*false = *JSON::false;

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

sub tora_op_equal {
    my ($lhs, $rhs) = @_;
    my $flags = B::svref_2object(\$lhs)->FLAGS;
    if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
        # IV or NV
        return $lhs == $rhs ? true() : false();
    } elsif ($flags & B::SVp_POK) {
        return $lhs eq $rhs ? true() : false();
    } else {
        die "OOPS";
    }
}

sub tora_op_lt {
    my ($lhs, $rhs) = @_;

    my $flags = B::svref_2object(\$lhs)->FLAGS;
    if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
        # IV or NV
        return $lhs < $rhs ? true() : false();
    } elsif ($flags & B::SVp_POK) {
        return $lhs lt $rhs ? true() : false();
    } else {
        die "OOPS";
    }
}

sub tora_op_gt {
    my ($lhs, $rhs) = @_;

    my $flags = B::svref_2object(\$lhs)->FLAGS;
    if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
        # IV or NV
        return $lhs > $rhs ? true() : false();
    } elsif ($flags & B::SVp_POK) {
        return $lhs gt $rhs ? true() : false();
    } else {
        die "OOPS";
    }
}

sub tora_op_le {
    my ($lhs, $rhs) = @_;
    my $flags = B::svref_2object(\$lhs)->FLAGS;
    if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
        # IV or NV
        return $lhs <= $rhs ? true() : false();
    } elsif ($flags & B::SVp_POK) {
        return $lhs le $rhs ? true() : false();
    } else {
        die "OOPS";
    }
}

sub tora_op_ge {
    my ($lhs, $rhs) = @_;
    my $flags = B::svref_2object(\$lhs)->FLAGS;
    if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
        # IV or NV
        return $lhs >= $rhs ? true() : false();
    } elsif ($flags & B::SVp_POK) {
        return $lhs ge $rhs ? true() : false();
    } else {
        die "OOPS";
    }
}

sub tora_op_add {
    my ($lhs, $rhs) = @_;
    my $flags = B::svref_2object(\$lhs)->FLAGS;
    if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
        return $lhs + $rhs;
    } elsif ($flags & B::SVp_POK) {
        return $lhs . $rhs;
    } else {
        ...
    }
}

sub tora_make_range {
    my ($lhs, $rhs) = @_;
    Nana::Translator::Perl::Range->new($lhs, $rhs);
}

1;


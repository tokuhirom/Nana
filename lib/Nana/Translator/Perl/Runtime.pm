package Nana::Translator::Perl::Runtime;
use strict;
use warnings;
use warnings FATAL => 'recursion';
use utf8;
use 5.10.0;

use Data::Dumper;
use parent qw(Exporter);
use Nana::Translator::Perl::Builtins;
use Nana::Translator::Perl::Class;
use Nana::Translator::Perl::Object;
use Nana::Translator::Perl::Range;
use Nana::Translator::Perl::Exception;
use Carp qw(croak);
use B;
use JSON ();

our $TORA_SELF;
our $TORA_FILENAME;

our @EXPORT = qw(tora_call_func tora_call_method tora_op_equal
    tora_op_lt tora_op_gt
    tora_op_le tora_op_ge
    tora_make_range
    tora_op_add tora_op_div
    tora_get_item
    $TORA_SELF
);

*true = *JSON::true;
*false = *JSON::false;

sub tora_call_func {
    my ($pkg, $funname, @args) = @_;
    if (my $func = $pkg->{$funname}) {
        my @ret = $func->(@args);
        return wantarray ? @ret : (@ret==1 ? $ret[0] : \@ret);
    } else {
        my $func = $TORA_BUILTIN_FUNCTIONS{$funname};
        if ($func) {
            my @ret = $func->(@args);
            return wantarray ? @ret : (@ret==1 ? $ret[0] : \@ret);
        } else {
            die "Unknown function '$funname' at $TORA_FILENAME line @{[ (caller(0))[2] ]}\n";
        }
    }
}

sub tora_call_method {
    my ($pkg, $klass, $methname, @args) = @_;
    if (my $klaas = $pkg->{$klass}) {
        if (my $methbody = $klaas->{$methname}) {
            my @ret = $methbody->(@args);
            return wantarray ? @ret : (@ret==1 ? $ret[0] : \@ret);
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
        } elsif (ref $klass eq 'Nana::Translator::Perl::Object') {
            if (my $methbody = $klass->get_method($methname)) {
                return $methbody->(@args);
            } else {
                die "Unknown method $methname in " . $klass->class->name;
            }
        } elsif (ref $klass eq 'Nana::Translator::Perl::Class') {
            if (my $methbody = $TORA_BUILTIN_CLASSES{Class}->{$methname}) {
                return $methbody->($klass, @args);
            } else {
                die "Unknown method $methname in Class";
            }
        } else {
            croak "Unknown class: $klass";
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

sub tora_op_div {
    my ($lhs, $rhs) = @_;
    my $flags = B::svref_2object(\$lhs)->FLAGS;
    if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
        if ($rhs == 0) {
            die "Zero divided Exception line @{[ (caller(0))[2] ]}";
        } else {
            return $lhs / $rhs;
        }
    } elsif ($flags & B::SVp_POK) {
        die "'$lhs' is not numeric. You cannot divide. line @{[ (caller(0))[2] ]}\n";
    } else {
        ...
    }
}

sub tora_make_range {
    my ($lhs, $rhs) = @_;
    Nana::Translator::Perl::Range->new($lhs, $rhs);
}

sub tora_get_item :lvalue {
    my ($lhs, $rhs) = @_;
    if (ref $lhs eq 'ARRAY') {
        $lhs->[$rhs];
    } else {
        ...;
        return $lhs;
    }
}

1;


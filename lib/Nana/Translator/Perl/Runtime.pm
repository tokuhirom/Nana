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

use File::ShareDir ();
use File::Spec;

our $TORA_SELF;
our $TORA_FILENAME;
our %TORA_INC;

our @EXPORT = qw(tora_call_func tora_call_method
    tora_op_equal tora_op_ne
    tora_op_lt tora_op_gt
    tora_op_le tora_op_ge
    tora_make_range
    tora_op_add tora_op_div
    tora_get_item
    tora_deref
    tora_use
);

*true = *JSON::true;
*false = *JSON::false;

our @CALLER_STACK;

sub __call {
    my ($func, $args) = @_;

    local @CALLER_STACK = @CALLER_STACK;
    push @CALLER_STACK, [
        $func
    ];

    my @ret = $func->(@$args);
    return wantarray ? @ret : (@ret==1 ? $ret[0] : \@ret);
}

sub tora_call_func {
    my ($pkg, $funname, @args) = @_;
    if (ref $funname eq 'CODE') {
        return __call($funname, \@args);
    }
    if (my $func = $pkg->{$funname}) {
        return __call($func, \@args);
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

sub __tora_call_method_fallback {
    my ($pkg, $klass, $klass_name, $methname, @args) = @_;
    # call 'Object'
    if (my $methbody = $TORA_BUILTIN_CLASSES{Object}->{$methname}) {
        my @ret = $methbody->($klass, @args);
        return wantarray ? @ret : (@ret==1 ? $ret[0] : \@ret);
    }
    croak "Unknown method named $methname in $klass_name";
}

sub tora_call_method {
    my ($pkg, $klass, $methname, @args) = @_;
    local $Nana::Translator::Perl::Runtime::TORA_SELF = $klass;

#   if (my $klaas = $pkg->{$klass}) {
#       die "XXX WHO CAN CALL THIS PATH?";

#       if (my $methbody = $klaas->{$methname}) {
#           return __call($methbody, \@args);
#       } else {
#           if (my $methbody = $TORA_BUILTIN_CLASSES{Class}->{$methname}) {
#               my @ret = $methbody->(@args);
#               return wantarray ? @ret : (@ret==1 ? $ret[0] : \@ret);
#           }
#           __tora_call_method_fallback($pkg, $klass, $klass, $methname, @args);
#       }
#   } else {
    {
        # builtin methods
        if (ref $klass eq 'ARRAY') {
            if (my $methbody = $TORA_BUILTIN_CLASSES{Array}->{$methname}) {
                return $methbody->($klass, @args);
            } else {
                __tora_call_method_fallback($pkg, $klass, 'Array', $methname, @args);
            }
        } elsif (ref $klass eq 'CODE') {
            if (my $methbody = $TORA_BUILTIN_CLASSES{Code}->{$methname}) {
                return $methbody->($klass, @args);
            } else {
                __tora_call_method_fallback($pkg, $klass, 'Code', $methname, @args);
            }
        } elsif (ref $klass eq 'HASH') {
            if (my $methbody = $TORA_BUILTIN_CLASSES{Hash}->{$methname}) {
                return $methbody->($klass, @args);
            } else {
                __tora_call_method_fallback($pkg, $klass, 'Hash', $methname, @args);
            }
        } elsif (ref $klass eq 'Nana::Translator::Perl::Object') {
            if (my $methbody = $klass->get_method($methname)) {
                return __call($methbody, \@args);
            } else {
                __tora_call_method_fallback($pkg, $klass, $klass->class->name, $methname, @args);
            }
        } elsif (ref $klass eq 'Nana::Translator::Perl::Class') {
            if (my $methbody = $klass->{$methname}) {
                return __call($methbody, [$klass, @args]);
            } else {
                if (my $methbody = $TORA_BUILTIN_CLASSES{Class}->{$methname}) {
                    return $methbody->($klass, @args);
                }
                __tora_call_method_fallback($pkg, $klass, $klass->name, $methname, @args);
            }
        } elsif (!ref $klass) {
            # IV or NV
            my $flags = B::svref_2object(\$klass)->FLAGS;
            # TODO: support NV class.
            if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
                if (my $methbody = $TORA_BUILTIN_CLASSES{Int}->{$methname}) {
                    return $methbody->($klass, @args);
                } else {
                    __tora_call_method_fallback($pkg, $klass, 'Int', $methname, @args);
                }
            } else {
                if (my $methbody = $TORA_BUILTIN_CLASSES{Str}->{$methname}) {
                    return $methbody->($klass, @args);
                } else {
                    __tora_call_method_fallback($pkg, $klass, 'Str', $methname, @args);
                }
            }
        } else {
            croak "Unknown class: $klass";
        }
    }
}

sub tora_call_method2 {
    my ($pkg, $klass, $methname, $seen, @args) = @_;
}

sub tora_op_equal {
    my ($lhs, $rhs) = @_;
    my $flags = B::svref_2object(\$lhs)->FLAGS;
    if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
        # IV or NV
        return $lhs == $rhs ? true() : false();
    } elsif ($flags & B::SVp_POK) {
        return $lhs eq $rhs ? true() : false();
    } elsif (!defined $lhs) {
        return !defined $rhs;
    } elsif (!defined $rhs) {
        return !defined $lhs;
    } elsif (ref $lhs eq 'JSON::XS::Boolean') {
        return (ref $rhs eq 'JSON::XS::Boolean') && $lhs == $rhs;
    } else {
    warn Dumper([$lhs, $rhs]);
        Dump($lhs);
        Dump($rhs);
        die "OOPS";
    }
}

sub tora_op_ne {
    my ($lhs, $rhs) = @_;
    my $flags = B::svref_2object(\$lhs)->FLAGS;
    if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
        # IV or NV
        return $lhs != $rhs ? true() : false();
    } elsif ($flags & B::SVp_POK) {
        return $lhs ne $rhs ? true() : false();
    } elsif (!defined $lhs) {
        return defined $rhs;
    } else {
        use Devel::Peek;
        Dump($lhs);
        ...
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
        if (!defined $rhs) {
            warn "use of uninitialized value in Str#+ at " . (caller(0))[1] . ' line ' . (caller(0))[2] . "\n";
            return $lhs;
        } else {
            return $lhs . $rhs;
        }
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
    } elsif (ref $lhs eq 'HASH') {
        $lhs->{$rhs};
    } elsif (!defined $lhs) {
        die "You cannot get item from Undef";
        $lhs; # workaround. perl5 needs lvalue on die.
    } else {
        ...;
        return $lhs;
    }
}

*typeof = *Nana::Translator::Perl::Builtins::typeof;

sub tora_deref:lvalue {
    my $v = shift;
    if (ref $v eq 'Nana::Translator::Perl::Object') {
        $v->{data};
    } else {
        die "You cannot dereference " . typeof($v);
        $v; # dummy for :lvalue
    }
}

my @libdir = (
    grep { defined $_ } (
        eval { File::Spec->catfile(File::ShareDir::dist_dir('nana'), 'lib') },
    )
);
sub tora_use {
    my ($pkg, $klass, $import) = @_;
    # TODO: $NANALIB
    (my $path = $klass) =~ s!::!\/!g;
    require Nana::Parser;
    require Nana::Translator::Perl;
    state $parser   = Nana::Parser->new();
    state $compiler = Nana::Translator::Perl->new();
    local $Nana::Translator::Perl::Runtime::CURRENT_PACKAGE;
    for my $libdir (@libdir) {
        my $fname = "$libdir/$path.tra";
        if (-f $fname) {
            open(my $fh, '<', $fname)
                or die "Cannot open module file $fname: $!";
            my $src = do { local $/; <$fh> };
            my $perl = eval {
                my $ast = $parser->parse($src, $fname);
                $compiler->compile($ast, 0, $fname);
            };
            if ($@) {
                die "Compilation failed in use: $@";
            }

            eval $perl;
            if ($@) {
                die "Compilation failed in use(Phase 2): $@";
            }

            for my $key (keys %$Nana::Translator::Perl::Runtime::CURRENT_PACKAGE) {
                if ($pkg->{$key}) {
                    warn "overriding $key at " . (caller(0))[1] . ' line ' . (caller(0))[2] . "\n";
                }
                $pkg->{$key} = $Nana::Translator::Perl::Runtime::CURRENT_PACKAGE->{$key};
            }

            return;
        }
    }
    die "Cannot find module $klass from:\n" . join("\n", @libdir);
}

1;


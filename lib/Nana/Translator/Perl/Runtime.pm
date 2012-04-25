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
use Nana::Translator::Perl::FilePackage;
use Nana::Translator::Perl::Regexp;
use Carp qw(croak);
use B;
use JSON ();

use File::ShareDir ();
use File::Spec;

our $TORA_SELF;
our $TORA_FILENAME;
our %TORA_INC;
our $LIBPATH = [
    grep { defined $_ } (
        eval { File::Spec->catfile(File::ShareDir::dist_dir('nana'), 'lib') },
    )
];
our $STDOUT = $Nana::Translator::Perl::Builtins::TORA_BUILTIN_CLASSES{'File'}->create_instance(*STDOUT);
our $STDERR = $Nana::Translator::Perl::Builtins::TORA_BUILTIN_CLASSES{'File'}->create_instance(*STDERR);
our $STDIN  = $Nana::Translator::Perl::Builtins::TORA_BUILTIN_CLASSES{'File'}->create_instance(*STDIN);

sub add_libpath {
    my ($class, $libpaths) = @_;
    unshift @$LIBPATH, @$libpaths;
}

our @EXPORT = qw(tora_call_func
    tora_op_equal tora_op_ne
    tora_op_lt tora_op_gt
    tora_op_le tora_op_ge
    tora_make_range
    tora_op_add tora_op_div tora_op_mul
    tora_get_item
    tora_deref
    tora_use
    tora_bytes
    tora_get_method tora_call_method
    __tora_set_regexp_global
    tora_op_not
);

*true = *JSON::true;
*false = *JSON::false;

sub _runtime_error {
    croak @_;
}

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

sub tora_call_method {
    my ($func, @args) = @_;
    return __call($func, \@args);
}

sub tora_get_method {
    my ($pkg, $object, $methname, @args) = @_;
    return tora_get_method2($pkg, $object, $object, $methname, @args);
}

sub tora_get_method2 {
    my ($pkg, $object, $klass, $methname, @args) = @_;

    my $type = typeof($klass);
    # builtin methods
    if ($type ~~ ['Regexp', 'Array', 'Code', 'Hash']) {
        if (defined(my $methbody = $TORA_BUILTIN_CLASSES{$type}->get_method($methname))) {
            return ($methbody, $klass, @args);
        } else {
            __tora_get_method_fallback($pkg, $klass, $type, $methname);
        }
    } elsif (ref $klass eq 'Nana::Translator::Perl::FilePackage') {
        if (defined(my $methbody = $klass->get($methname))) {
            return ($methbody, $klass, @args);
        } else {
            __tora_get_method_fallback($pkg, $klass, $klass->class->name, $methname, @args);
        }
    } elsif (ref $klass eq 'Nana::Translator::Perl::Object') {
        tora_get_method_object($object, $object->class, $methname, @args);
    } elsif (ref $klass eq 'Nana::Translator::Perl::Class') {
        {
            my $target = $object;
            while ($target) {
                if (defined(my $methbody = $target->get_method($methname))) {
                    return ($methbody, @args);
                }
                $target = $target->superclass();
            }
        }
        if (my $methbody = $TORA_BUILTIN_CLASSES{Class}->get_method($methname)) {
            return ($methbody, $object, @args);
        }
        __tora_get_method_fallback($pkg, $object, $object->name, $methname, @args);
    } elsif (!ref $klass) {
        # IV or NV
        my $flags = B::svref_2object(\$klass)->FLAGS;
        # TODO: support NV class.
        if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
            if (defined(my $methbody = $TORA_BUILTIN_CLASSES{Int}->get_method($methname))) {
                return ($methbody, $klass, @args);
            } else {
                __tora_get_method_fallback($pkg, $klass, 'Int', $methname, @args);
            }
        } else {
            if (defined(my $methbody = $TORA_BUILTIN_CLASSES{Str}->get_method($methname))) {
                return ($methbody, $klass, @args);
            } else {
                __tora_get_method_fallback($pkg, $klass, 'Str', $methname, @args);
            }
        }
    } else {
        croak "Unknown class: $klass";
    }
}

sub tora_get_method_object {
    my ($object, $klass, $methname, @args) = @_;

    if (defined(my $methbody = $klass->get_method($methname))) {
        return ($methbody, @args);
    } elsif (defined(my $super = $klass->superclass())) {
        return tora_get_method_object($object, $super, $methname, @args);
    } else {
        __tora_get_method_fallback(undef, $object, $object->class->name, $methname, @args);
    }
}

sub __tora_get_method_fallback {
    my ($pkg, $klass, $klass_name, $methname, @args) = @_;
    # call 'Object'
    if (my $methbody = $TORA_BUILTIN_CLASSES{Object}->get_method($methname)) {
        return ($methbody, $klass, @args);
    }
    croak "Unknown method named $methname in $klass_name";
}

sub tora_op_equal {
    my ($lhs, $rhs) = @_;

    # check undef
    if (!defined $lhs) {
        return !defined $rhs;
    } elsif (!defined $rhs) {
        return !defined $lhs;
    }

    my $type = typeof($lhs);
    if ($type eq 'Int') {
        if (typeof($rhs) eq 'Str') {
            _runtime_error("Cannot compare string and Int");
        }
        return $lhs == $rhs ? true() : false();
    } elsif ($type eq 'Double') {
        if (typeof($rhs) eq 'Str') {
            _runtime_error("Cannot compare string and Double");
        }
        return $lhs == $rhs ? true() : false();
    } elsif ($type eq 'Str') {
        return $lhs eq $rhs ? true() : false();
    } elsif ($type eq 'Bytes') {
        my $rtype = typeof($rhs);
        if ($rtype eq 'Bytes') {
            return $lhs->data eq $rhs->data ? true() : false();
        } elsif ($rtype eq 'Str') {
            return $lhs->data eq $rhs ? true() : false();
        } else {
            _runtime_error "You cannot compare Bytes and $rtype";
        }
    } elsif ($type eq 'Bool') {
        return $lhs == tora_boolean($rhs);
    } else {
        die "OOPS. Cannot compare $type";
    }
}

sub tora_op_not {
    return tora_boolean($_[0]) ? JSON::false() : JSON::true();
}

sub tora_boolean {
    my $type = typeof($_[0]);
    if ($type eq 'Bool') {
        return $_[0];
    } elsif (!defined $_[0]) {
        return JSON::false();
    } else {
        return JSON::true();
    }
}

sub tora_op_ne {
    my ($lhs, $rhs) = @_;
    my $flags = B::svref_2object(\$lhs)->FLAGS;
    if (!defined $rhs) {
        return defined $lhs;
    }
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

sub tora_op_mul {
    my ($lhs, $rhs) = @_;
    my $flags = B::svref_2object(\$lhs)->FLAGS;
    if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
        return $lhs * $rhs;
    } elsif ($flags & B::SVp_POK) {
        return $lhs x $rhs;
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
    my $x;
    if (ref $lhs eq 'ARRAY') {
        $lhs->[$rhs];
    } elsif (ref $lhs eq 'HASH') {
        $lhs->{$rhs};
    } elsif (!defined $lhs) {
        die "You cannot get item from Undef";
        $lhs; # workaround. perl5 needs lvalue on die.
    } elsif (ref $lhs eq 'Nana::Translator::Perl::RegexpMatched') {
        if (typeof($rhs) eq 'Int') {
            $lhs->parens->[$rhs];
        } else {
            die "There is no good solution.";
            $lhs; # dummy
        }
    } else {
        ...;
        $lhs; # dummy
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

sub tora_use {
    my ($pkg, $klass, $import) = @_;
    # TODO: $NANALIB
    (my $path = $klass) =~ s!::!\/!g;
    require Nana::Parser;
    require Nana::Translator::Perl;
    state $parser   = Nana::Parser->new();
    state $compiler = Nana::Translator::Perl->new();
    local $Nana::Translator::Perl::Runtime::CURRENT_PACKAGE;
    my $file_package = Nana::Translator::Perl::FilePackage->new($klass);
    for my $libdir (@$LIBPATH) {
        my $fname = "$libdir/$path.tra";
        if (-f $fname) {
            open(my $fh, '<', $fname)
                or die "Cannot open module file $fname: $!";
            my $src = do { local $/; <$fh> };
            my $perl = eval {
                my $ast = $parser->parse($src, $fname);
                $compiler->compile($ast, $fname);
            };
            if ($@) {
                die "Compilation failed in use: $@";
            }

            eval $perl;
            if ($@) {
                die "Compilation failed in use(Phase 2): $@";
            }

            for my $key (grep /^[^_]/, keys %$Nana::Translator::Perl::Runtime::CURRENT_PACKAGE) {
                if ($pkg->{$key}) {
                    warn "overriding $key at " . (caller(0))[1] . ' line ' . (caller(0))[2] . "\n";
                }
                $pkg->{$key} = $Nana::Translator::Perl::Runtime::CURRENT_PACKAGE->{$key};
                $file_package->add($key, $Nana::Translator::Perl::Runtime::CURRENT_PACKAGE->{$key});
            }
            $pkg->{$klass} ||= $file_package;

            return;
        }
    }
    die "Cannot find module $klass from:\n" . join("\n", @$LIBPATH);
}

sub tora_bytes {
    my $str = shift;
    $TORA_BUILTIN_CLASSES{Bytes}->create_instance($str);
}

1;


package Nana::Translator::Perl::Builtins;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);
use 5.10.0;
use B;
use Data::Dumper;
use Devel::Peek;
use Nana::Translator::Perl::RegexpMatched;
use Nana::Translator::Perl::Class;
use Carp;
use Cwd;

our @EXPORT = qw(
    %TORA_BUILTIN_FUNCTIONS
    %TORA_BUILTIN_CLASSES
);

our %TORA_BUILTIN_CLASSES;

sub __say {
    for my $x (@_) {
        if (defined $x) {
            if (ref $x eq 'ARRAY') {
                __say(@$x);
            } else {
                say($x);
            }
        } else {
            say('undef');
        }
    }
}

our %TORA_BUILTIN_FUNCTIONS = (
    'say' => \&__say,
    'typeof' => \&typeof,
    getcwd => \&Cwd::getcwd,
    'sprintf' => sub {
        my $format = shift;
        return CORE::sprintf($format, @_);
    },
    '__DUMP' => sub {
        Dump($_[0]);
    },
    'p' => sub {
        warn Dumper(@_);
    },
    'print' => sub {
        print(@_);
    },
    'printf' => sub {
        printf(@_);
    },
    'stat' => sub {
        return File::stat::stat(@_);
    },
    'eval' => sub {
        my $src = shift;
        require Nana::Translator::Perl;
        state $parser = Nana::Parser->new();
        state $compiler = Nana::Translator::Perl->new();
        my $ast = $parser->parse($src);
        my $perl = $compiler->compile($ast);
        my $ret = eval($perl);
        die $@ if $@;
        return $ret;
    },
    'open' => sub {
        ...
    },
    'caller' => do {
        my $class = Nana::Translator::Perl::Class->new(
            'Caller'
        );
        $class->add_method(
            'package' => sub {
            warn "PKG";
                $_[0]->[0];
            }
        );
        $class->add_method(
            'code' => sub {
                return $Nana::Translator::Perl::Runtime::TORA_SELF->data->[0];
            }
        );
        sub {
            my @stack = @Nana::Translator::Perl::Runtime::CALLER_STACK;
            pop @stack; # ignore current stack
            if (@_==1) {
                my $need = shift;
                my $n = 0;
                for my $caller (reverse @stack) {
                    if ($n == $need) {
                        return Nana::Translator::Perl::Object->new(
                            $class,
                            $caller
                        );
                    }
                    $n++;
                }
                return undef;
            } else {
                my @ret;
                for my $caller (reverse @stack) {
                    push @ret, Nana::Translator::Perl::Object->new(
                        $class,
                        $caller
                    );
                }
                return \@ret;
            }
        },
    },
);

%TORA_BUILTIN_CLASSES = (
    'Code' => {
        package => sub {
            my $code = shift;
            my $obj = B::svref_2object($code);
            return $obj->GV->STASH->NAME;
        },
        name => sub {
            my $code = shift;
            my $obj = B::svref_2object($code);
            return $obj->GV->NAME;
        },
    },
    'Array' => {
        push => sub { CORE::push(@{$_[0]}, $_[1]); return $_[0]; },
        pop => sub { return CORE::pop(@{$_[0]}); },
        shift => sub { return CORE::shift(@{$_[0]}); },
        unshift => sub { CORE::unshift(@{$_[0]}, $_[1]); return $_[0]; },
        reverse => sub {
            return [reverse @{$_[0]}];
        },
        size => sub {
            return 0+@{$_[0]};
        },
        sort => sub {
            return [sort @{$_[0]}];
        },
    },
    'Hash' => {
        keys => sub {
            return [CORE::keys(%{$_[0]})];
        },
        delete => sub {
            return CORE::delete($_[0]->{$_[1]});
        },
        exists => sub {
            return CORE::exists($_[0]->{$_[1]})
                ? JSON::true() : JSON::false();
        },
        values => sub {
            return [CORE::values(%{$_[0]})];
        },
    },
    'Class' => {
        bless => sub { # self.bless($data)
            return Nana::Translator::Perl::Object->new($_[0], $_[1]);
        },
        name => sub {
            return $_[0]->name;
        },
    },
    'Str' => {
        length => sub {
            return length $_[0];
        },
        match => sub {
            return $_[0] =~ $_[1] ? Nana::Translator::Perl::RegexpMatched->new() : undef;
        },
        substr => sub {
            if (@_==2) {
                return substr($_[0], $_[1]);
            } elsif (@_==3) {
                return substr($_[0], $_[1], $_[2]);
            } else {
                die "ARGUMENT MISSING";
            }
        },
    },
    'Object' => {
        tora => sub {
            return to_tora($_[0]);
        },
        class => sub {
            if ($_[0]->isa("Nana::Translator::Perl::Object")) {
                return $_[0]->class;
            } else {
                ...
            }
        },
    },
);

sub typeof {
    my $stuff = shift;

    if (ref $stuff eq 'ARRAY') {
        return 'Array';
    } elsif (ref $stuff eq 'HASH') {
        return 'Hash';
    } elsif (!defined $stuff) {
        return 'Undef';
    } elsif (ref $stuff eq 'Nana::Translator::Perl::Range') {
        return 'Range';
    } elsif (ref $stuff eq 'Nana::Translator::Perl::Object') {
        return $stuff->class->name;
    } elsif (ref $stuff eq 'Nana::Translator::Perl::Class') {
        return 'Class';
    } elsif (ref $stuff eq 'CODE') {
        return 'Code';
    } elsif (ref $stuff) {
        ...
    } else {
        my $flags = B::svref_2object(\$stuff)->FLAGS;
        # TODO: support NV class.
        if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
            if ($flags & B::SVp_IOK) {
                return "Int";
            } else {
                return "Double";
            }
        } else {
            return "Str";
        }
    }
}

sub to_tora {
    my $stuff = shift;
    my $type = typeof $stuff;
    if ($type eq 'Array') {
        return '[' . join(',', map { to_tora($_) } @$stuff) . ']';
    } elsif ($type eq 'Hash') {
        my @x;
        for (keys %$stuff) {
            push @x, to_tora($_) . '=>' . to_tora($stuff->{$_});
        }
        return '{' . join(',', @x) . '}';
    } elsif ($type eq 'Undef') {
        return 'undef';
    } elsif ($type eq 'Str') {
        $stuff =~ s/'/\\'/g;
        return "'" . $stuff . "'";
    } elsif ($type eq 'Int') {
        return $stuff;
    } elsif ($type eq 'Double') {
        return $stuff;
    } else {
        die "$type.tora is not implemented yet.";
        ...
    }
}

1;


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

our @EXPORT = qw(
    %TORA_BUILTIN_FUNCTIONS
    %TORA_BUILTIN_CLASSES
);

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
);

our %TORA_BUILTIN_CLASSES = (
    'Array' => {
        push => sub {
            CORE::push(@{$_[0]}, $_[1]);
            return $_[0];
        },
        size => sub {
            return 0+@{$_[0]};
        },
    },
    'Hash' => {
        keys => sub {
            return [CORE::keys(%{$_[0]})];
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
        'Range';
    } elsif (ref $stuff eq 'Nana::Translator::Perl::Object') {
        return 'Object';
    } elsif (ref $stuff eq 'Nana::Translator::Perl::Class') {
        return 'Class';
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
    } else {
        die "$type.tora is not implemented yet.";
        ...
    }
}

1;


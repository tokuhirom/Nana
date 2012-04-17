package Nana::Translator::Perl;
use strict;
use warnings;
use utf8;
use Data::Dumper;
use Carp;

sub new {
    my $self = shift;
}

our $FILENAME;
our $IN_CLASS;

sub compile {
    my ($self, $ast, $no_header, $filename) = @_;

    local $FILENAME = $filename || "<eval>";

    my $res = '';
    unless ($no_header) {
        $res .= join('',
            'use 5.12.0;',
            'use strict;',
            'use warnings;',
            'use warnings FATAL => "recursion";',
            'use utf8;',
            'use Nana::Translator::Perl::Runtime;',
            'use JSON;',
            'use boolean -truth;',
            'my $TORA_PACKAGE;',
        ) . "\n";
    }
    $res .= _compile($ast);
}

sub _compile {
    my ($node) = @_;

    confess "Bad AST" unless $node;
    confess "Bad AST" unless @$node > 0;

    for (qw(
        **
        * % x /
        + -
        >> <<
        lt gt le ge
        != <=> eq ne cmp ~~
        &
        | ^
        &&
        || //
        ...
        = *= += /= %= x= -= <<= >>= **= &= |= ^=
        and
        or xor
    ), ',') {
        my $op = $_;
        if ($node->[0] eq $op) {
            if ($op =~ /[a-z]/) {
                # 'cmp' to ' cmp '
                $op = " $op ";
            }
            return '('. _compile($node->[2]) . $op . _compile($node->[3]).')';
        }
    }

    if ($node->[0] eq '<') {
        return 'tora_op_lt('. _compile($node->[2]) .','. _compile($node->[3]).')';
    } elsif ($node->[0] eq '>') {
        return 'tora_op_gt('. _compile($node->[2]) .','. _compile($node->[3]).')';
    } elsif ($node->[0] eq '<=') {
        return 'tora_op_le('. _compile($node->[2]) .','. _compile($node->[3]).')';
    } elsif ($node->[0] eq '>=') {
        return 'tora_op_ge('. _compile($node->[2]) .','. _compile($node->[3]).')';
    } elsif ($node->[0] eq '==') {
        return 'tora_op_equal('. _compile($node->[2]) .','. _compile($node->[3]).')';
    } elsif ($node->[0] eq '..') {
        return 'tora_make_range('. _compile($node->[2]) .','. _compile($node->[3]).')';
    } elsif ($node->[0] eq '~') {
        # string concat operator
        return '('. _compile($node->[2]) . '.' . _compile($node->[3]).')';
    } elsif ($node->[0] eq '?:') {
        return join(
            '',

            '((',
            _compile($node->[2]),
            ')?(',
            _compile($node->[3]),
            '):(',
            _compile($node->[4]),
            '))'
        );
    } elsif ($node->[0] eq '()') {
        return '('. _compile($node->[2]) .')';
    } elsif ($node->[0] eq 'PREINC') {
        return '++(' . _compile($node->[2]) . ')';
    } elsif ($node->[0] eq 'PREDEC') {
        return '--(' . _compile($node->[2]) . ')';
    } elsif ($node->[0] eq 'POSTINC') {
        return '(' . _compile($node->[2]) . ')++';
    } elsif ($node->[0] eq 'POSTDEC') {
        return '(' . _compile($node->[2]) . ')--';
    } elsif ($node->[0] eq 'MY') {
        if (ref $node->[2] eq 'ARRAY') {
            return 'my (' . join(', ', map { _compile($_) } @{$node->[2]}) . ')';
        } else {
            return 'my ' . _compile($node->[2]);
        }
    } elsif ($node->[0] eq 'QW') {
        my $make_string = sub {
            local $_ = shift;
            s/'/\\'/g;
            q{'} . $_ . q{'};
        };
        return '[' . join(', ', map { $make_string->($_) } @{$node->[2]}) .']';
    } elsif ($node->[0] eq 'DO') {
        my $ret = "do {\n";
        $ret .= _compile($node->[2]) . '}';
        return $ret;
    } elsif ($node->[0] eq 'SUB') {
        my $ret = sprintf(qq{#line %d "$FILENAME"\n}, $node->[1]);
        my $pkg = $IN_CLASS ? '$TORA_CLASS' : '$TORA_PACKAGE';
        $ret .= $pkg . "->{" . _compile($node->[2]) . "} = sub {\n";
        if ($node->[3]) {
            for (@{$node->[3]}) {
                $ret .= "my ";
                $ret .= _compile($_);
                $ret .= "=shift;";
            }
        }
        $ret .= _compile($node->[4]) . ' }';
        return $ret;
    } elsif ($node->[0] eq 'CALL') {
        if ($node->[2]->[0] eq 'IDENT') {
            my $ret = 'tora_call_func($TORA_PACKAGE, q{' . $node->[2]->[2] . '}, (';
            $ret .= join(',', map { sprintf('scalar(%s)', _compile($_)) } @{$node->[3]});
            $ret .= '))';
            return $ret;
        } else {
            die "Compilation failed.";
        }
    } elsif ($node->[0] eq 'IDENT') {
        return 'q{' . $node->[2] . '}';
    } elsif ($node->[0] eq 'NOP') {
        return '';
    } elsif ($node->[0] eq 'REGEXP') {
        my $re = $node->[2];
        $re =~ s!/!\\/!g;
        return "/$re/$node->[3]";
    } elsif ($node->[0] eq 'STR') {
        return '"' . $node->[2] . '"';
    } elsif ($node->[0] eq 'HEREDOC') {
        my $buf = ${$node->[2]};
        $buf =~ s/'/\\'/;
        return qq{'$buf'};
    } elsif ($node->[0] eq 'INT') {
        return $node->[2];
    } elsif ($node->[0] eq 'RETURN') {
        return 'return (' . _compile($node->[2]) . ');';
    } elsif ($node->[0] eq 'UNLESS') {
        return 'unless (' . _compile($node->[2]) . ') {' . _compile($node->[3]) . '}';
    } elsif ($node->[0] eq 'IF') {
        my $ret = 'if (' . _compile($node->[2]) . ') {' . _compile($node->[3]) . '}';
        if ($node->[4]) {
            $ret .= _compile($node->[4]);
        }
        return $ret;
    } elsif ($node->[0] eq 'WHILE') {
        return 'while (' . _compile($node->[2]) . ') {' . _compile($node->[3]) . '}';
    } elsif ($node->[0] eq 'ELSIF') {
        my $ret = ' elsif ('. _compile($node->[2]) . ') {' . _compile($node->[3]) . '}';
        if ($node->[4]) {
            $ret .= _compile($node->[4]);
        }
        return $ret;
    } elsif ($node->[0] eq 'ELSE') {
        return ' else {' . _compile($node->[2]) . '}';
    } elsif ($node->[0] eq 'CLASS') {
        my $ret = '{my $TORA_CLASS=($TORA_PACKAGE->{' . _compile($node->[2]) . '} = +{});';
        $ret .= join(',', map { sprintf "BEGIN{extends '%s';}", _compile($_) } @{$node->[3]});
        $ret .= "\n";
        local $IN_CLASS=1;
        $ret .= _compile($node->[4]);
        $ret .= ";}";
        return $ret;
    } elsif ($node->[0] eq 'METHOD_CALL') {
        return 'tora_call_method($TORA_PACKAGE, '._compile($node->[2]) . ', ' . _compile($node->[3]) . ', (' . join(',', map { _compile($_) } @{$node->[4]}) . '))';
    } elsif ($node->[0] eq 'STMTS') {
        my $ret = '';
        for (@{$node->[2]}) {
            $ret .= sprintf(qq{#line %d "$FILENAME"\n}, $_->[1]);
            $ret .= _compile($_) . ";\n";
        }
        return $ret;
    } elsif ($node->[0] eq 'FOR') {
        my $ret = 'for ';
        if (@{$node->[3]}) {
            $ret .= join(',', map { 'my ' . _compile($_) } @{$node->[3]});
        }
        $ret .= '(ref(' . _compile($node->[2]) . ') eq "ARRAY" ? @{'._compile($node->[2]).'} : '._compile($node->[2]).') {' . _compile($node->[4]) . '}';
    } elsif ($node->[0] eq 'UNDEF') {
        return 'undef';
    } elsif ($node->[0] eq 'FALSE') {
        return 'JSON::false()';
    } elsif ($node->[0] eq 'TRUE') {
        return 'JSON::true()';
    } elsif ($node->[0] eq 'DOUBLE') {
        return $node->[2];
    } elsif ($node->[0] eq 'EXPRESSIONS') {
        die;
    } elsif ($node->[0] eq '{}') {
        return '{' . join(',', map { _compile($_) } @{$node->[2]}) . '}';
    } elsif ($node->[0] eq 'ARRAY') {
        return '[' . join(',', map { _compile($_) } @{$node->[2]}) . ']';
    } elsif ($node->[0] eq 'VARIABLE') {
        return $node->[2];
    } elsif ($node->[0] eq 'UNARY+') {
        return '+' . _compile($node->[2]);
    } elsif ($node->[0] eq 'UNARY-') {
        return '-' . _compile($node->[2]);
    } elsif ($node->[0] eq 'UNARY!') {
        return '!' . _compile($node->[2]);
    } elsif ($node->[0] eq 'UNARY~') {
        return '~' . _compile($node->[2]);
    } elsif ($node->[0] eq 'UNARY*') {
        return '@{' . _compile($node->[2]) . '}';
    } elsif ($node->[0] eq 'UNARY\\') {
        return '\\' . _compile($node->[2]);
    } elsif ($node->[0] eq '=~') {
        return '('. _compile($node->[2]) . '=~' . _compile($node->[3]) .')';
    } else {
        die "Unknown node type " . Dumper($node);
    }
}

1;
__END__

=head1 SYNOPSIS

    use Nana::Translator::Perl;

    my $compiler = Nana::Translator::Perl->new();
    my $perl = $compiler->compile($ast);
    eval $perl;


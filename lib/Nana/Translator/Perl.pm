package Nana::Translator::Perl;
use strict;
use warnings;
use utf8;
use Data::Dumper;
use Carp;
use Nana::Node;

sub new {
    my $self = shift;
}

our $FILENAME;
our $IN_CLASS;

sub compile {
    my ($self, $ast, $filename, $no_header) = @_;

    local $FILENAME = $filename || "<eval>";

    my $res = '';
    unless ($no_header) {
        $res .= join('',
            'package main;',
            'use strict;',
            'use warnings;',
            'use warnings FATAL => "recursion";',
            'use utf8;',
            'use Nana::Translator::Perl::Runtime;',
            'use Nana::Translator::Perl::Builtins qw(%TORA_BUILTIN_CLASSES);',
            'use JSON::XS;',
            'use Sub::Name;',
            'my $LIBPATH=$Nana::Translator::Perl::Runtime::LIBPATH;',
            'my $STDOUT=$Nana::Translator::Perl::Runtime::STDOUT;',
            'my $STDERR=$Nana::Translator::Perl::Runtime::STDERR;',
            'my $STDIN=$Nana::Translator::Perl::Runtime::STDIN;',
            'my $ARGV=$Nana::Translator::Perl::Runtime::ARGV;',
            '$Nana::Translator::Perl::Runtime::CURRENT_PACKAGE = my $TORA_PACKAGE = {};',
            'local $Nana::Translator::Perl::Runtime::TORA_FILENAME="' . $FILENAME .'";',
        ) . "\n";
    }
    $res .= _compile($ast);
    return $res;
}

my @DISPATCHER;
$DISPATCHER[NODE_STMTS()] = sub {
    my $node = shift;
    my $ret = '';
    for (@{$node->[2]}) {
        $ret .= sprintf(qq{#line %d "$FILENAME"\n}, $_->[1]);
        $ret .= _compile($_) . ";\n";
    }
    return $ret;
};
$DISPATCHER[NODE_COMMA()] = sub {
    my $node = shift;
    return '('. _compile($node->[2]) . ',' . _compile($node->[3]).')';
};
$DISPATCHER[NODE_MINUS()] = sub {
    my $node = shift;
    return '('. _compile($node->[2]) . '-' . _compile($node->[3]).')';
};
$DISPATCHER[NODE_MOD()] = sub {
    my $node = shift;
    return '('. _compile($node->[2]) . '%' . _compile($node->[3]).')';
};
$DISPATCHER[NODE_RSHIFT()] = sub {
    my $node = shift;
    return '('. _compile($node->[2]) . '>>' . _compile($node->[3]).')';
};
$DISPATCHER[NODE_LSHIFT()] = sub {
    my $node = shift;
    return '('. _compile($node->[2]) . '<<' . _compile($node->[3]).')';
};
{
    my @foo = (
        NODE_DIV_ASSIGN, NODE_DIV,
        NODE_MUL_ASSIGN, NODE_MUL,
        NODE_PLUS_ASSIGN, NODE_PLUS,
        NODE_MOD_ASSIGN, NODE_MOD,
        NODE_MINUS_ASSIGN, NODE_MINUS,
        NODE_LSHIFT_ASSIGN, NODE_LSHIFT,
        NODE_RSHIFT_ASSIGN, NODE_RSHIFT,
        NODE_POW_ASSIGN, NODE_POW,
        NODE_AND_ASSIGN, NODE_BITAND,
        NODE_OR_ASSIGN, NODE_BITOR,
        NODE_XOR_ASSIGN, NODE_BITXOR,
        NODE_OROR_ASSIGN, NODE_LOGICAL_OR,
    );
    while (my ($x, $y) = splice @foo, 0, 2) {
        $DISPATCHER[$x] = sub {
            my $node = shift;
            return _compile([
                NODE_ASSIGN(),
                $node->[1],
                $node->[2],
                [
                    $y,
                    $node->[1],
                    $node->[2],
                    $node->[3],
                ]
            ]);
        };
    }
}
$DISPATCHER[NODE_CMP()] = sub {
    my $node = shift;
    return '('. _compile($node->[2]) . '<=>' . _compile($node->[3]).')';
};
{
    my @foo = (
        '|' => NODE_BITOR,
        '&' => NODE_BITAND,
        '^' => NODE_BITXOR,
        ' and ' => NODE_LOGICAL_AND,
        ' or ' => NODE_LOGICAL_OR,
        ' xor ' => NODE_LOGICAL_XOR,
    );
    while (my ($x, $y) = splice @foo, 0, 2) {
        $DISPATCHER[$y] = sub {
            my $node = shift;
            return '('. _compile($node->[2]) . $x . _compile($node->[3]).')';
        };
    }
}
{
    my %binops = (
        NODE_LT()  => 'tora_op_lt',
        NODE_GT()  => 'tora_op_gt',
        NODE_LE() => 'tora_op_le',
        NODE_GE() => 'tora_op_ge',
        NODE_EQ() => 'tora_op_eq',
        NODE_NE() => 'tora_op_ne',
        NODE_DOTDOT() => 'tora_make_range',
        NODE_PLUS()  => 'tora_op_add',
        NODE_DIV()  => 'tora_op_div',
        NODE_MUL()  => 'tora_op_mul',
        NODE_POW()  => 'tora_op_pow',
    );
    while (my ($op, $func) = each %binops) {
        $DISPATCHER[$op] = sub {
            my $node = shift;
            return "$func(". _compile($node->[2]) . ',' . _compile($node->[3]).')';
        };
    }
}
$DISPATCHER[NODE_BLOCK()] = sub { my $node = shift;
    return '{' . _compile($node->[2]) . '}';
};
$DISPATCHER[NODE_MAKE_HASH()] = sub { my $node = shift;
    return '{' . join(',', map { _compile($_) } @{$node->[2]}) . '}';
};
$DISPATCHER[NODE_MAKE_ARRAY()] = sub { my $node = shift;
    return '[' . join(',', map { _compile($_) } @{$node->[2]}) . ']';
};
$DISPATCHER[NODE_VARIABLE()] = sub { my $node = shift;
    return $node->[2];
};
$DISPATCHER[NODE_UNARY_PLUS()] = sub { my $node = shift;
    return '(+' . _compile($node->[2]) . ')';
};
$DISPATCHER[NODE_UNARY_MINUS()] = sub { my $node = shift;
    return '(-' . _compile($node->[2]) . ')';
};
$DISPATCHER[NODE_UNARY_NOT()] = sub { my $node = shift;
    return 'tora_op_not('._compile($node->[2]).')';
};
$DISPATCHER[NODE_UNARY_TILDE()] = sub { my $node = shift;
    return '~' . _compile($node->[2]);
};
$DISPATCHER[NODE_UNARY_MUL()] = sub { my $node = shift;
    return '@{' . _compile($node->[2]) . '}';
};
$DISPATCHER[NODE_UNARY_REF()] = sub { my $node = shift;
    return '\\' . _compile($node->[2]);
};
$DISPATCHER[NODE_REGEXP_MATCH()] = sub { my $node = shift;
    return '('. _compile($node->[2]) . '=~' . _compile($node->[3]) .')';
};

sub _compile {
    my ($node) = @_;

    confess "Bad AST" unless $node;
    confess "Bad AST" unless ref $node eq 'ARRAY';
    confess "Bad AST" unless @$node > 0;

    my $code = $DISPATCHER[$node->[0]];
    return $code->($node) if $code;

    if ($node->[0] eq NODE_ASSIGN) {
        return _compile($node->[2]) . '=' . _compile($node->[3]);
    }

    if ($node->[0] eq NODE_FILE_TEST) {
        if ($node->[2] eq '-s') {
            return "(-s(" . _compile($node->[3]).'))';
        } else {
            return "(($node->[2](" . _compile($node->[3]).'))?JSON::XS::true():JSON::XS::false())';
        }
    }

    if ($node->[0] eq NODE_THREE) {
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
    } elsif ($node->[0] eq NODE_PRE_INC) {
        return '++(' . _compile($node->[2]) . ')';
    } elsif ($node->[0] eq NODE_PRE_DEC) {
        return '--(' . _compile($node->[2]) . ')';
    } elsif ($node->[0] eq NODE_POST_INC) {
        return '(' . _compile($node->[2]) . ')++';
    } elsif ($node->[0] eq NODE_POST_DEC) {
        return '(' . _compile($node->[2]) . ')--';
    } elsif ($node->[0] eq NODE_MY) {
        if (ref $node->[2] eq 'ARRAY') {
            return 'my (' . join(', ', map { _compile($_) } @{$node->[2]}) . ')';
        } else {
            return 'my ' . _compile($node->[2]);
        }
    } elsif ($node->[0] eq NODE_QW) {
        my $make_string = sub {
            local $_ = shift;
            s/'/\\'/g;
            q{'} . $_ . q{'};
        };
        return '[' . join(', ', map { $make_string->($_) } @{$node->[2]}) .']';
    } elsif ($node->[0] eq NODE_DIE) {
        return "die Nana::Translator::Perl::Exception->new(" . _compile($node->[2]) . ')';
    } elsif ($node->[0] eq NODE_TRY) {
        my $ret = "sub {my \@ret = eval {\n";
        $ret .= _compile($node->[2]);
        $ret .= '}; my @ret2=($@ ? $@->val : undef, @ret); wantarray ? @ret2 : $ret2[0]; }->();';
        return $ret;
    } elsif ($node->[0] eq NODE_GETITEM) {
        return 'tora_get_item(' . _compile($node->[2]) . ',' . _compile($node->[3]) .')';
    } elsif ($node->[0] eq NODE_USE) {
        return 'tora_use($TORA_PACKAGE,' . _compile($node->[2]) . ',' . ($node->[3] && $node->[3] eq '*' ? 'q{*}' : _compile($node->[3])) . ')';
    } elsif ($node->[0] eq NODE_DO) {
        my $ret = "do {\n";
        $ret .= _compile($node->[2]) . '}';
        return $ret;
    } elsif ($node->[0] eq NODE_LAMBDA) {
        my $ret = sprintf(qq{\n#line %d "$FILENAME"\n}, $node->[1]);
        $ret .= "(sub {;\n";
        if (@{$node->[2]}) { # have args
            for (my $i=0; $i<@{$node->[2]}; $i++) {
                my $p = $node->[2]->[$i];
                if ($p->[0] eq NODE_PARAMS_DEFAULT) {
                    $ret .= "my ";
                    $ret .= _compile($p->[2]);
                    $ret .= "=\@_>0?shift \@_:" ._compile($p->[3]) .";";
                } else {
                    $ret .= "my ";
                    $ret .= _compile($p);
                    $ret .= "=shift;";
                }
            }

            # remove arguments from stack.
            # for 'sub foo ($n) { }'
            $ret .= 'undef;';
        } else {
            $ret .= "local \$_ = shift;";
            # remove arguments from stack.
            # for 'sub foo ($n) { }'
            $ret .= 'undef;';
        }
        my $block = _compile($node->[3]);
        if ($block =~ qr!\A\{\s*\}\Z!) {
            $block = '';
        }
        $ret .= $block . '; })';
        return $ret;
    } elsif ($node->[0] eq NODE_SUB) {
        my $ret = sprintf(qq{\n#line %d "$FILENAME"\n}, $node->[1]);
        my $end = '';
        if ($node->[2]) {
            $ret .= 'local $Nana::Translator::Perl::Runtime::TORA_FILENAME="' . $FILENAME .'";',
            my $pkg = $IN_CLASS ? '$TORA_CLASS->{methods}' : '$TORA_PACKAGE';
            $ret .= $pkg . "->{" . _compile($node->[2]) . "} = subname(" . _compile($node->[2]) .", sub {;\n";
        } else {
            $ret .= "(sub {;\n";
        }
        if ($node->[3]) {
            for (my $i=0; $i<@{$node->[3]}; $i++) {
                my $p = $node->[3]->[$i];
                if ($p->[0] eq NODE_PARAMS_DEFAULT) {
                    $ret .= "my ";
                    $ret .= _compile($p->[2]);
                    $ret .= "=\@_>0?shift \@_:" ._compile($p->[3]) .";";
                } else {
                    $ret .= "my ";
                    $ret .= _compile($p);
                    $ret .= "=shift;";
                }
            }

            # remove arguments from stack.
            # for 'sub foo ($n) { }'
            $ret .= 'undef;';
        } else {
            $ret .= 'local $_ = [@_];undef;';
        }
        my $block = _compile($node->[4]);
        if ($block =~ qr!\A\{\s*\}\Z!) {
            $block = '';
        }
        $ret .= $block . '; })';
        return $ret;
    } elsif ($node->[0] eq NODE_CALL) {
        if ($node->[2]->[0] eq NODE_IDENT || $node->[2]->[0] eq NODE_PRIMARY_IDENT) {
            my $ret = 'tora_call_func($TORA_PACKAGE, q{' . $node->[2]->[2] . '}, (';
            $ret .= join(',', map { sprintf('%s(%s)', $_->[0] eq 'CALL' ? 'scalar' : '', _compile($_)) } @{$node->[3]});
            $ret .= '))';
            return $ret;
        } elsif ($node->[2]->[0] eq NODE_VARIABLE) {
            my $ret = 'tora_call_func($TORA_PACKAGE, (' . _compile($node->[2]) . '), (';
            $ret .= join(',', map { sprintf('%s(%s)', $_->[0] eq 'CALL' ? 'scalar' : '', _compile($_)) } @{$node->[3]});
            $ret .= '))';
            return $ret;
        } else {
            die "Compilation failed in subroutine call.";
        }
    } elsif ($node->[0] eq NODE_PRIMARY_IDENT) {
        return '($TORA_PACKAGE->{q!' . $node->[2] . '!} || $TORA_BUILTIN_CLASSES{q!' . $node->[2] . '!} || die qq{Unknown stuff named ' . $node->[2] . '})';
    } elsif ($node->[0] eq NODE_IDENT) {
        return 'q{' . $node->[2] . '}';
    } elsif ($node->[0] eq NODE_DEREF) {
        return 'tora_deref(' . _compile($node->[2]) . ')';
    } elsif ($node->[0] eq NODE_NOP) {
        return '';
    } elsif ($node->[0] eq NODE_REGEXP) {
        my $re = $node->[2];
        $re =~ s!/!\\/!g;
        my $mode = $node->[3];
        my $global = 0;
        if ($mode =~ s/g//) {
            $global++;
        }
        return join('',
            'do {',
                'Nana::Translator::Perl::Regexp->new(',
                    "qr/$re/$mode,",
                    ($global ? '1' : '0'),
                ');',
            '}',
        );
    } elsif ($node->[0] eq NODE_NEXT) {
        return 'next;'
    } elsif ($node->[0] eq NODE_LAST) {
        return 'last;'
    } elsif ($node->[0] eq NODE_STRCONCAT) {
        return '('. _compile($node->[2]) .'.'. $node->[3].'.'._compile($node->[4]).')';
    } elsif ($node->[0] eq NODE_STR2) {
        my $str = ${$node->[2]};
        # TODO: more escape?
        $str =~ s/!/\\!/g; # escape
        return 'q!' . $str . '!';
    } elsif ($node->[0] eq NODE_STR) {
        my $str = $node->[2];
        # TODO: more escape?
        $str =~ s/!/\\!/g; # escape
        return 'q!' . $str . '!';
    } elsif ($node->[0] eq NODE_BYTES) {
        my $str = $node->[2];
        $str =~ s/!/\\!/g; # escape
        # TODO: more escape?
        return 'do { no utf8; tora_bytes(qq!' . $str . '!) }';
    } elsif ($node->[0] eq NODE_HEREDOC) {
        my $buf = ${$node->[2]};
        $buf =~ s/'/\\'/g;
        return qq{'$buf'};
    } elsif ($node->[0] eq NODE_INT) {
        return $node->[2];
    } elsif ($node->[0] eq NODE_RETURN) {
        return 'return (' . _compile($node->[2]) . ');';
    } elsif ($node->[0] eq NODE_IF) {
        my $ret = 'if (' . _compile($node->[2]) . ')' . _compile($node->[3]);
        if ($node->[4]) {
            $ret .= _compile($node->[4]);
        }
        return $ret;
    } elsif ($node->[0] eq NODE_WHILE) {
        return 'while (' . _compile($node->[2]) . ')' . _compile($node->[3]);
    } elsif ($node->[0] eq NODE_ELSIF) {
        my $ret = ' elsif ('. _compile($node->[2]) . ')' . _compile($node->[3]);
        if ($node->[4]) {
            $ret .= _compile($node->[4]);
        }
        return $ret;
    } elsif ($node->[0] eq NODE_ELSE) {
        return ' else {' . _compile($node->[2]) . '}';
    } elsif ($node->[0] eq NODE_CLASS) {
        my $ret = '{my $TORA_CLASS=$Nana::Translator::Perl::Runtime::TORA_SELF=($TORA_PACKAGE->{' . _compile($node->[2]) . '} = Nana::Translator::Perl::Class->new(' . _compile($node->[2]) . ',' . ($node->[3] ? _compile($node->[3]) : 'undef') .'));';
        $ret .= "\n";
        $ret .= do {
            local $IN_CLASS=1;
            _compile($node->[4]);
        };
        $ret .= ";}";
        return $ret;
    } elsif ($node->[0] eq NODE_GET_METHOD) {
        return join('',
            'do {',
                '[tora_get_method($TORA_PACKAGE,',
                    _compile($node->[2]) .',',
                    _compile($node->[3]),
                ')]->[0]',
            '}'
        );
    } elsif ($node->[0] eq NODE_METHOD_CALL) {
        return join('',
            'do {',
                'my $self='._compile($node->[2]).';',
                'my @args = tora_get_method($TORA_PACKAGE,',
                    '$self,',
                    _compile($node->[3]) . ',',
                    '(' . join(',', map { _compile($_) } @{$node->[4]}) . ')',
                ');',
                'local $Nana::Translator::Perl::Runtime::TORA_SELF=$self;',
                'tora_call_method(@args);',
            '}'
        );
    } elsif ($node->[0] eq NODE_FOREACH) {
    # use Data::Dumper; warn Dumper($node);
        my $ret = '{my $__tora_iteratee = (' . _compile($node->[2]) .");\n";
        if (@{$node->[3]} > 2) {
            die "Too many parameters for foreach statement at line $node->[1].";
        } elsif (@{$node->[3]} == 2) {
            # for hash
            $ret .= join('',
                qq!if (ref(\$__tora_iteratee) eq "HASH") {\n!,
                qq!  for (keys \%\$__tora_iteratee) {\n!,
        sprintf(qq!    my %s = \$_;\n!, _compile($node->[3]->[0])),
        sprintf(qq!    my %s = \$__tora_iteratee->{\$_};\n!, _compile($node->[3]->[1])),
                    _compile($node->[4]),
                qq!  }\n!,
                qq!} else {\n!,
                qq!  die "This is not a hash type. You cannot iterate by 2 or more variables."!,
                qq!}\n!,
            );
            $ret .= '}';
        } else { # 1 args
            $ret .= 'if (ref $__tora_iteratee eq "Nana::Translator::Perl::Object" && $__tora_iteratee->has_method("__iter__")) {' . "\n";
            $ret .= '  my $__tora_iterator = ' . _compile(
                [NODE_METHOD_CALL, $node->[1],
                    [NODE_VARIABLE, $node->[1], '$__tora_iteratee'],
                    [NODE_IDENT,    $node->[1], '__iter__'],
                    []]
            ) . ';';
            $ret .= sprintf('  while (%s = %s)', (@{$node->[3]} ? ('my ' . _compile($node->[3]->[0])) : 'local $_'), _compile(
                [NODE_METHOD_CALL, $node->[1],
                    [NODE_VARIABLE, $node->[1], '$__tora_iterator'],
                    [NODE_IDENT,    $node->[1], '__next__'],
                    []]
            ));
            $ret .= _compile($node->[4]);
            $ret .= '} else {' . "\n";
            {
                $ret .= 'for ';
                if (@{$node->[3]}) {
                    $ret .= join(',', map { 'my ' . _compile($_) } @{$node->[3]});
                }
                $ret .= join('',
                    '(',
                          'ref($__tora_iteratee) eq "ARRAY"',
                        '? @{$__tora_iteratee}',
                        ': ref($__tora_iteratee) eq "Nana::Translator::Perl::Range"',
                        '? $__tora_iteratee->list',
                        ': $__tora_iteratee',
                    ') '
                ). "\n". _compile($node->[4]) . '';
            }
            $ret .= '}'; # if-else
            $ret .= '}';
        }
        return $ret;
    } elsif ($node->[0] eq NODE_FOR) {
        join('',
            'for (',
                _compile($node->[2]),
            ';',
                _compile($node->[3]),
            ';',
                _compile($node->[4]),
            ')',
                _compile($node->[5]), # block
        );
    } elsif ($node->[0] eq NODE_UNDEF) {
        return 'undef';
    } elsif ($node->[0] eq NODE_FALSE) {
        return 'JSON::XS::false()';
    } elsif ($node->[0] eq NODE_SELF) {
        return '($Nana::Translator::Perl::Runtime::TORA_SELF || die "Do not call self out of class.")';
    } elsif ($node->[0] eq NODE___FILE__) {
        return '__FILE__';
    } elsif ($node->[0] eq NODE_TRUE) {
        return 'JSON::XS::true()';
    } elsif ($node->[0] eq NODE_DOUBLE) {
        my $ret = "$node->[2]";
        $ret .= ".0" unless $ret =~ /\./;
        return $ret;
    } else {
        die "Unknown node type " . node_name($node->[0]);
        # die "Unknown node type " . Dumper($node);
    }
}

1;
__END__

=head1 NAME

Nana::Translator::Perl - AST to Perl

=head1 SYNOPSIS

    use Nana::Translator::Perl;

    my $compiler = Nana::Translator::Perl->new();
    my $perl = $compiler->compile($ast);
    eval $perl;

=head1 DESCRIPTION

This class translates tora AST to perl code. And you can eval() the code.

=head1 MEHOTDS

=over 4

=item my $compiler = Nana::Translator::Perl->new()

Create a new instance.

=item my $perl = $compiler->compile(ArrayRef $ast, Str $filename)

Compile a AST to perl code.

=back

=head1 AUTHOR

Tokuhiro Matsuno

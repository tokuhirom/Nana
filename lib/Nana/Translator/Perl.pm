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
            'use JSON;',
            'use Sub::Name;',
            'my $LIBPATH=$Nana::Translator::Perl::Runtime::LIBPATH;',
            'my $STDOUT=$Nana::Translator::Perl::Runtime::STDOUT;',
            'my $STDERR=$Nana::Translator::Perl::Runtime::STDERR;',
            'my $STDIN=$Nana::Translator::Perl::Runtime::STDIN;',
            '$Nana::Translator::Perl::Runtime::CURRENT_PACKAGE = my $TORA_PACKAGE = {};',
            'local $Nana::Translator::Perl::Runtime::TORA_FILENAME="' . $FILENAME .'";',
        ) . "\n";
    }
    $res .= _compile($ast);
    return $res;
}

sub _compile {
    my ($node) = @_;

    confess "Bad AST" unless $node;
    confess "Bad AST" unless @$node > 0;

    for (qw(
        *= += /= %= x= -= <<= >>= **= &= |= ^= ||=
    )) {
        if ($node->[0] eq $_) {
            (my $op = $_) =~ s/=$//;
            return _compile([
                '=',
                $node->[1],
                $node->[2],
                [
                    $op,
                    $node->[1],
                    $node->[2],
                    $node->[3],
                ]
            ]);
        }
    }

    for (qw(
        %
        -
        >> <<
        <=> ~~
        &
        | ^
        &&
        || //
        ...
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

    for my $op (qw(=)) {
        if ($node->[0] eq $op) {
            return _compile($node->[2]) . $op . _compile($node->[3]);
        }
    }

    for my $op(qw(-f -d -x -e)) {
        if ($node->[0] eq "UNARY$op") {
            return "(($op(" . _compile($node->[2]).'))?JSON::true():JSON::false())';
        }
    }
    if ($node->[0] eq 'UNARY-s') {
        return "(-s(" . _compile($node->[2]).'))';
    }

    my %binops = (
        '<'  => 'tora_op_lt',
        '>'  => 'tora_op_gt',
        '<=' => 'tora_op_le',
        '>=' => 'tora_op_ge',
        '==' => 'tora_op_eq',
        '!=' => 'tora_op_ne',
        '..' => 'tora_make_range',
        '+'  => 'tora_op_add',
        '/'  => 'tora_op_div',
        '*'  => 'tora_op_mul',
        '**'  => 'tora_op_pow',
    );
    if (my $func = $binops{$node->[0]}) {
        return "$func(". _compile($node->[2]) . ',' . _compile($node->[3]).')';
    }

    if ($node->[0] eq '?:') {
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
    } elsif ($node->[0] eq 'DIE') {
        return "die Nana::Translator::Perl::Exception->new(" . _compile($node->[2]) . ')';
    } elsif ($node->[0] eq 'TRY') {
        my $ret = "sub {my \@ret = eval {\n";
        $ret .= _compile($node->[2]);
        $ret .= '}; my @ret2=($@ ? $@->val : undef, @ret); wantarray ? @ret2 : $ret2[0]; }->();';
        return $ret;
    } elsif ($node->[0] eq 'GETITEM') {
        return 'tora_get_item(' . _compile($node->[2]) . ',' . _compile($node->[3]) .')';
    } elsif ($node->[0] eq 'USE') {
        return 'tora_use($TORA_PACKAGE,' . _compile($node->[2]) . ',' . ($node->[3] && $node->[3] eq '*' ? 'q{*}' : _compile($node->[3])) . ')';
    } elsif ($node->[0] eq 'DO') {
        my $ret = "do {\n";
        $ret .= _compile($node->[2]) . '}';
        return $ret;
    } elsif ($node->[0] eq 'LAMBDA') {
        my $ret = sprintf(qq{\n#line %d "$FILENAME"\n}, $node->[1]);
        $ret .= "(sub {;\n";
        if (@{$node->[2]}) { # have args
            for (my $i=0; $i<@{$node->[2]}; $i++) {
                my $p = $node->[2]->[$i];
                if ($p->[0] eq 'PARAMS_DEFAULT') {
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
    } elsif ($node->[0] eq 'SUB') {
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
                if ($p->[0] eq 'PARAMS_DEFAULT') {
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
    } elsif ($node->[0] eq 'CALL') {
        if ($node->[2]->[0] eq 'IDENT' || $node->[2]->[0] eq 'PRIMARY_IDENT') {
            my $ret = 'tora_call_func($TORA_PACKAGE, q{' . $node->[2]->[2] . '}, (';
            $ret .= join(',', map { sprintf('%s(%s)', $_->[0] eq 'CALL' ? 'scalar' : '', _compile($_)) } @{$node->[3]});
            $ret .= '))';
            return $ret;
        } elsif ($node->[2]->[0] eq 'VARIABLE') {
            my $ret = 'tora_call_func($TORA_PACKAGE, (' . _compile($node->[2]) . '), (';
            $ret .= join(',', map { sprintf('%s(%s)', $_->[0] eq 'CALL' ? 'scalar' : '', _compile($_)) } @{$node->[3]});
            $ret .= '))';
            return $ret;
        } else {
            die "Compilation failed in subroutine call.";
        }
    } elsif ($node->[0] eq 'PRIMARY_IDENT') {
        return '($TORA_PACKAGE->{q!' . $node->[2] . '!} || $TORA_BUILTIN_CLASSES{q!' . $node->[2] . '!} || die qq{Unknown stuff named ' . $node->[2] . '})';
    } elsif ($node->[0] eq 'IDENT') {
        return 'q{' . $node->[2] . '}';
    } elsif ($node->[0] eq 'DEREF') {
        return 'tora_deref(' . _compile($node->[2]) . ')';
    } elsif ($node->[0] eq 'NOP') {
        return '';
    } elsif ($node->[0] eq 'REGEXP') {
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
    } elsif ($node->[0] eq 'NEXT') {
        return 'next;'
    } elsif ($node->[0] eq 'LAST') {
        return 'last;'
    } elsif ($node->[0] eq 'STRCONCAT') {
        return '('. _compile($node->[2]) .'.'. $node->[3].'.'._compile($node->[4]).')';
    } elsif ($node->[0] eq 'STR2') {
        my $str = ${$node->[2]};
        # TODO: more escape?
        $str =~ s/!/\\!/g; # escape
        return 'q!' . $str . '!';
    } elsif ($node->[0] eq 'STR') {
        my $str = $node->[2];
        # TODO: more escape?
        $str =~ s/!/\\!/g; # escape
        return 'q!' . $str . '!';
    } elsif ($node->[0] eq 'BYTES') {
        my $str = $node->[2];
        $str =~ s/!/\\!/g; # escape
        # TODO: more escape?
        return 'do { no utf8; tora_bytes(qq!' . $str . '!) }';
    } elsif ($node->[0] eq 'HEREDOC') {
        my $buf = ${$node->[2]};
        $buf =~ s/'/\\'/;
        return qq{'$buf'};
    } elsif ($node->[0] eq 'INT') {
        return $node->[2];
    } elsif ($node->[0] eq 'RETURN') {
        return 'return (' . _compile($node->[2]) . ');';
    } elsif ($node->[0] eq 'UNLESS') {
        return 'unless (' . _compile($node->[2]) . ')' . _compile($node->[3]);
    } elsif ($node->[0] eq 'IF') {
        my $ret = 'if (' . _compile($node->[2]) . ')' . _compile($node->[3]);
        if ($node->[4]) {
            $ret .= _compile($node->[4]);
        }
        return $ret;
    } elsif ($node->[0] eq 'WHILE') {
        return 'while (' . _compile($node->[2]) . ')' . _compile($node->[3]);
    } elsif ($node->[0] eq 'ELSIF') {
        my $ret = ' elsif ('. _compile($node->[2]) . ')' . _compile($node->[3]);
        if ($node->[4]) {
            $ret .= _compile($node->[4]);
        }
        return $ret;
    } elsif ($node->[0] eq 'ELSE') {
        return ' else {' . _compile($node->[2]) . '}';
    } elsif ($node->[0] eq 'CLASS') {
        my $ret = '{my $TORA_CLASS=$Nana::Translator::Perl::Runtime::TORA_SELF=($TORA_PACKAGE->{' . _compile($node->[2]) . '} = Nana::Translator::Perl::Class->new(' . _compile($node->[2]) . ',' . ($node->[3] ? _compile($node->[3]) : 'undef') .'));';
        $ret .= "\n";
        $ret .= do {
            local $IN_CLASS=1;
            _compile($node->[4]);
        };
        $ret .= ";}";
        return $ret;
    } elsif ($node->[0] eq 'GET_METHOD') {
        return join('',
            'do {',
                '[tora_get_method($TORA_PACKAGE,',
                    _compile($node->[2]) .',',
                    _compile($node->[3]),
                ')]->[0]',
            '}'
        );
    } elsif ($node->[0] eq 'METHOD_CALL') {
        return join('',
            'do {local $Nana::Translator::Perl::Runtime::TORA_SELF='._compile($node->[2]).';',
                'tora_call_method(',
                    'tora_get_method($TORA_PACKAGE,',
                        '$Nana::Translator::Perl::Runtime::TORA_SELF,',
                        _compile($node->[3]) . ',',
                        '(' . join(',', map { _compile($_) } @{$node->[4]}) . ')',
                    '),',
                ')',
            '}'
        );
    } elsif ($node->[0] eq 'STMTS') {
        my $ret = '';
        for (@{$node->[2]}) {
            $ret .= sprintf(qq{#line %d "$FILENAME"\n}, $_->[1]);
            $ret .= _compile($_) . ";\n";
        }
        return $ret;
    } elsif ($node->[0] eq 'FOREACH') {
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
                ['METHOD_CALL', $node->[1],
                    ['VARIABLE', $node->[1], '$__tora_iteratee'],
                    ['IDENT',    $node->[1], '__iter__'],
                    []]
            ) . ';';
            $ret .= sprintf('  while (%s = %s)', (@{$node->[3]} ? ('my ' . _compile($node->[3]->[0])) : 'local $_'), _compile(
                ['METHOD_CALL', $node->[1],
                    ['VARIABLE', $node->[1], '$__tora_iterator'],
                    ['IDENT',    $node->[1], '__next__'],
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
    } elsif ($node->[0] eq 'FOR') {
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
    } elsif ($node->[0] eq 'UNDEF') {
        return 'undef';
    } elsif ($node->[0] eq 'FALSE') {
        return 'JSON::false()';
    } elsif ($node->[0] eq 'SELF') {
        return '($Nana::Translator::Perl::Runtime::TORA_SELF || die "Do not call self out of class.")';
    } elsif ($node->[0] eq '__FILE__') {
        return '__FILE__';
    } elsif ($node->[0] eq '__LINE__') {
        return '__LINE__';
    } elsif ($node->[0] eq 'TRUE') {
        return 'JSON::true()';
    } elsif ($node->[0] eq 'DOUBLE') {
        my $ret = "$node->[2]";
        $ret .= ".0" unless $ret =~ /\./;
        return $ret;
    } elsif ($node->[0] eq 'BLOCK') {
        return '{' . _compile($node->[2]) . '}';
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
        return 'tora_op_not('._compile($node->[2]).')';
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

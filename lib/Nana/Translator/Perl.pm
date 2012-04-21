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
            'package main;',
            'use strict;',
            'use warnings;',
            'use warnings FATAL => "recursion";',
            'use utf8;',
            'use Nana::Translator::Perl::Runtime;',
            'use JSON;',
            'use Sub::Name;',
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
        **
        * % x
        -
        >> <<
        <=> ~~
        &
        | ^
        &&
        || //
        ...
        *= += /= %= x= -= <<= >>= **= &= |= ^=
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

    my %binops = (
        '<'  => 'tora_op_lt',
        '>'  => 'tora_op_gt',
        '<=' => 'tora_op_le',
        '>=' => 'tora_op_ge',
        '==' => 'tora_op_equal',
        '!=' => 'tora_op_ne',
        '..' => 'tora_make_range',
        '+'  => 'tora_op_add',
        '/'  => 'tora_op_div',
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
        my $ret = "do {my \@ret = eval {\n";
        $ret .= _compile($node->[2]);
        $ret .= '}; ($@ || undef, @ret); };';
        return $ret;
    } elsif ($node->[0] eq 'GETITEM') {
        return 'tora_get_item(' . _compile($node->[2]) . ',' . _compile($node->[3]) .')';
    } elsif ($node->[0] eq 'USE') {
        return 'tora_use($TORA_PACKAGE,' . _compile($node->[2]) . ',' . ($node->[3] eq '*' ? 'q{*}' : _compile($node->[3])) . ')';
    } elsif ($node->[0] eq 'DO') {
        my $ret = "do {\n";
        $ret .= _compile($node->[2]) . '}';
        return $ret;
    } elsif ($node->[0] eq 'SUB') {
        my $ret = sprintf(qq{#line %d "$FILENAME"\n}, $node->[1]);
        if ($node->[2]) {
            $ret .= 'local $Nana::Translator::Perl::Runtime::TORA_FILENAME="' . $FILENAME .'";',
            my $pkg = $IN_CLASS ? '$TORA_CLASS' : '$TORA_PACKAGE';
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
        return '($TORA_PACKAGE->{q!' . $node->[2] . '!} || die qq{Unknown stuff naemd ' . $node->[2] . '})';
    } elsif ($node->[0] eq 'IDENT') {
        return 'q{' . $node->[2] . '}';
    } elsif ($node->[0] eq 'DEREF') {
        return 'tora_deref(' . _compile($node->[2]) . ')';
    } elsif ($node->[0] eq 'NOP') {
        return '';
    } elsif ($node->[0] eq 'REGEXP') {
        my $re = $node->[2];
        $re =~ s!/!\\/!g;
        return "qr/$re/$node->[3]";
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
        my $ret = '{my $TORA_CLASS=$Nana::Translator::Perl::Runtime::TORA_SELF=($TORA_PACKAGE->{' . _compile($node->[2]) . '} = Nana::Translator::Perl::Class->new(' . _compile($node->[2]) . ',+{}));';
        $ret .= join(',', map { sprintf "BEGIN{extends '%s';}", _compile($_) } @{$node->[3]});
        $ret .= "\n";
        local $IN_CLASS=1;
        $ret .= _compile($node->[4]);
        $ret .= ";}";
        return $ret;
    } elsif ($node->[0] eq 'METHOD_CALL') {
        return 'do {local $Nana::Translator::Perl::Runtime::TORA_SELF='._compile($node->[2]).';tora_call_method($TORA_PACKAGE, $Nana::Translator::Perl::Runtime::TORA_SELF, ' . _compile($node->[3]) . ', (' . join(',', map { _compile($_) } @{$node->[4]}) . '))}';
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
        } else {
            $ret .= 'for ';
            if (@{$node->[3]}) {
                $ret .= join(',', map { 'my ' . _compile($_) } @{$node->[3]});
            }
            $ret .= '(ref($__tora_iteratee) eq "ARRAY" ? @{$__tora_iteratee} : ref($__tora_iteratee) eq "Nana::Translator::Perl::Range" ? $__tora_iteratee->list : $__tora_iteratee) ' . "\n". _compile($node->[4]) . '';
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
        return $node->[2];
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


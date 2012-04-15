package Nana::Parser;
use strict;
use warnings;
use warnings FATAL => 'recursion';
use utf8;
use Carp;
use Data::Dumper;
use Scalar::Util qw(refaddr);
use Sub::Name;

# TODO:
# qr() q() qq()
# "" ''
# <<'...' <<"..."
# method call
# class call
# -> { } lambda.
# arguments with types
# do-while?
# //x
# postfix for
# postfix if
# postfix while
# postfix unless

our $LINENO;
our $START;
our $CACHE;
our $MATCH;

sub new { bless {}, shift }

# rule($name, $code);
sub rule {
    my ($name, $patterns) = @_;
    no strict 'refs';
    *{"@{[ __PACKAGE__ ]}::$name"} = subname $name, sub {
        local $START = $LINENO;
        my $src = skip_ws(shift);
        if (my $cache = $CACHE->{$name}->{length($src)}) {
            return @$cache;
        }
        for (@$patterns) {
        $MATCH++;

            local $LINENO = $LINENO;
            my @a = $_->($src);

            if (@a) {
                $CACHE->{$name}->{length($src)} = \@a;
                return @a;
            }
        }
        $CACHE->{$name}->{length($src)} = [];
        return ();
    };
}

sub any {
    my $src = shift;
    local $START = $LINENO;
    for (@_) {
        local $LINENO = $LINENO;
        my @a = $_->($src);
        return @a if @a;
    }
    return ();
}

# see http://en.wikipedia.org/wiki/Parsing_expression_grammar#Indirect_left_recursion
# %left operator.
sub left_op {
    my ($upper, $ops) = @_;
    confess "\$ops must be ArrayRef" unless ref $ops eq 'ARRAY';

    sub {
        my $c = shift;
        ($c, my $lhs) = $upper->($c)
            or return;
        my $ret = $lhs;
        while (my ($c2, $op) = match($c, @$ops)) {
            $c = $c2;
            ($c, my $rhs) = $upper->($c)
                or die "syntax error  after '$op' line $LINENO";
            $ret = _node($op, $ret, $rhs);
        }
        return ($c, $ret);
    },
}

sub nonassoc_op {
    my ($upper, $ops) = @_;

    sub {
        my $c = shift;
        ($c, my $lhs) = $upper->($c)
            or return;
        ($c, my $op) = match($c, @$ops)
            or return;
        ($c, my $rhs) = $upper->($c)
            or die "Expression required after $op line $LINENO";
        return ($c, _node2($op, $START, $lhs, $rhs));
    },
}

sub match {
    my ($c, @words) = @_;
    croak "[BUG]" if @_ == 1;
    confess unless defined $c;
    $c = skip_ws($c);
    for my $word (@words) {
        if (ref $word eq 'ARRAY') {
            if ($c =~ s/$word->[0]//) {
                return ($c, $word->[1]);
            }
        } else {
            my $qword = quotemeta($word);
            if ($c =~ s/^$qword(?![&|+>-])//) {
                return ($c, $word);
            }
        }
    }
    return;
}

sub parse {
    my ($class, $src) = @_;
    confess unless defined $src;
    local $Data::Dumper::Terse = 1;
    local $LINENO = 1;
    local $CACHE  = {};
    local $MATCH = 0;

    my ($rest, $ret) = program($src);
    if ($rest =~ /[^\n \t]/) {
        die "Parse failed: " . Dumper($rest);
    }
    # warn $MATCH;
    $ret;
}

sub _node {
    my ($type, @rest) = @_;
    [$type, $LINENO, @rest];
}

sub _node2 {
    my ($type, $lineno, @rest) = @_;
    [$type, $lineno, @rest];
}

rule('program', [
    sub {
        my $c = shift;
        ($c, my $ret) = statement_list($c)
            or return;
        ($c, $ret);
    },
    sub {
        return (shift, _node('NOP'));
    },
]);

rule('statement_list', [
    sub {
        my $src = skip_ws(shift);

        my $start = $LINENO;
        my $ret = [];
        LOOP: while (1) {
            my ($tmp, $stmt) = statement($src)
                or return ($src, _node2('STMTS', $start, $ret));
            $src = $tmp;
            push @$ret, $stmt;

            # skip spaces.
            $src =~ s/^[ \t\f]*//s;
            # read next statement if found ';' or '\n'
            $src =~ s/^;//s
                and next;
            $src =~ s/^\n//s
                and do { ++$LINENO; next LOOP; };
            # there is no more statements, just return!
            return ($src, _node('STMTS', $ret));
        }
    }
]);

rule('statement', [
    sub {
        my $c = shift;
        # class Name [isa Parent] {}
        ($c) = match($c, 'class')
            or return;
        ($c, my $name) = identifier($c)
            or die "identifier expected after 'class' keyword";
        my @base;
        if ((my $c2) = match($c, 'isa')) {
            $c = $c2;
            ($c, my $base) = identifier($c)
                or die "identifier expected after 'isa' keyword";
            push @base, $base;
        }
        ($c, my $block) = block($c)
            or return;
        return ($c, _node2('CLASS', $START, $name, \@base, $block));
    },
    sub {
        my $c = shift;
        ($c) = match($c, 'return')
            or return;
        ($c, my $expression) = expression($c)
            or die "expression expected after 'return' keyword";
        return ($c, _node2('RETURN', $START, $expression));
    },
    sub {
        my $c = shift;
        ($c) = match($c, 'unless')
            or return;
        ($c, my $expression) = expression($c)
            or die "expression is required after 'unless' keyword";
        ($c, my $block) = block($c)
            or die "block is required after unless keyword.";
        return ($c, _node2('UNLESS', $START, $expression, $block));
    },
    sub {
        my $c = shift;
        ($c) = match($c, 'if')
            or return;
        ($c, my $expression) = expression($c)
            or die "expression is required after 'if' keyword line $LINENO";
        ($c, my $block) = block($c)
            or die "block is required after if keyword line $LINENO.";
        my $else;
        if ((my $c2, $else) = else_clause($c)) { # optional
            $c = $c2;
        }
        return ($c, _node2('IF', $START, $expression, $block, $else));
    },
    sub {
        my $c = shift;
        ($c) = match($c, 'while')
            or return;
        ($c, my $expression) = expression($c)
            or die "expression is required after 'while' keyword";
        ($c, my $block) = block($c)
            or die "block is required after while keyword.";
        return ($c, _node2('WHILE', $START, $expression, $block));
    },
    sub {
        my $c = shift;
        ($c) = match($c, 'for')
            or return;
        ($c, my $expression) = expression($c)
            or die "expression is required after 'for' keyword";
        ($c) = match($c, '->')
            or die "'->' missing after for keyword";
        my @vars;
        while (my ($c2, $var) = variable($c)) {
            push @vars, $var;
            $c = $c2;
            (my $c3) = match($c, ',')
                or last;
            $c = $c3;
        }
        ($c, my $block) = block($c)
            or die "block is required after 'for' keyword.";
        return ($c, _node2('FOR', $START, $expression, \@vars, $block));
    },
    sub {
        my $c = shift;
        ($c) = match($c, 'do')
            or return;
        ($c, my $block) = block($c)
            or die "block is required after 'do' keyword.";
        return ($c, _node2('DO', $START, $block));
    },
    \&expression,
    \&block,
]);

rule('else_clause', [
    sub {
        my $c = shift;
        ($c) = match($c, 'elsif')
            or return;
        ($c, my $expression) = expression($c)
            or die "expression is required after 'elsif' keyword";
        ($c, my $block) = block($c)
            or die "block is required after elsif keyword.";
        my $else;
        if ((my $c2, $else) = else_clause($c)) { # optional
            $c = $c2;
        }
        return ($c, _node2('ELSIF', $START, $expression, $block, $else));
    },
    sub {
        my $c = shift;
        ($c) = match($c, 'else')
            or return;
        ($c, my $block) = block($c)
            or die "block is required after elsif keyword.";
        return ($c, _node2('ELSE', $START, $block));
    },
]);

# skip whitespace with line counting
sub skip_ws {
    local $_ = shift;
    confess "[BUG]" unless defined $_;

std:
    s/^[ \t\f]// && goto std;
    s/^\n/++$LINENO;''/ge && goto std;

    $_;
}

rule('expression', [
    sub {
        my $c = shift;

        ($c)           = match($c, 'sub') or return;
        ($c, my $name) = identifier($c)   or die "Parsing error";

        my $params;
        if ((my $c2, $params) = parameters($c)) {
            # optional
            $c = $c2;
        }

        ($c, my $block) = block($c)
            or die "expected block after sub in $name->[1]";
        return ($c, _node2('SUB', $START, $name, $params, $block));
    },
    sub {
        # say()
        my $c = shift;
        ($c, my $lhs) = addive_expression($c) or return;
        ($c, my $args) = arguments($c) or return;
        return ($c, _node('CALL', $lhs, $args));
    },
    \&str_or_expression,
]);

rule('block', [
    sub {
        my $src = shift;
        ($src) = match($src, '{')
            or return;

        ($src, my $body) = statement_list($src)
            or return;

        ($src) = match($src, '}')
            or return;
        return ($src, $body || _node('NOP'));
    }
]);

rule('str_or_expression', [
    left_op(\&str_and_expression, ['or', 'xor']),
]);

rule('str_and_expression', [
    left_op(\&not_expression, ['and']),
]);

rule('not_expression', [
    sub {
        my $src = shift;
        ($src) = match($src, 'not')
            or return;
        ($src, my $body) = not_expression($src)
            or die "Cannot get expression after 'not'";
        return ($src, _node('not', $body));
    },
    \&comma_expression,
]);

rule('comma_expression', [
    left_op(\&assign_expression, [','])
]);

# %right
rule('assign_expression', [
    sub {
        my $c = shift;
        ($c, my $rhs) = three_expression($c)
            or return;
        ($c, my $op) = match($c, qw(= *= += /= %= x= -= <<= >>= **= &= |= ^=))
            or return;
        ($c, my $lhs) = assign_expression($c)
            or die "Cannot get expression after $op";
        return ($c, _node($op, $rhs, $lhs));
    },
    \&three_expression
]);

# %right
rule('three_expression', [
    sub {
        my $c = shift;
        ($c, my $t1) = dotdot_expression($c)
            or return;
        ($c) = match($c, '?')
            or return;
        ($c, my $t2) = three_expression($c)
            or return;
        ($c) = match($c, ':')
            or return;
        ($c, my $t3) = three_expression($c)
            or return;
        return ($c, _node('?:', $t1, $t2, $t3));
    },
    \&dotdot_expression
]);

rule('dotdot_expression', [
    left_op(\&oror_expression, ['..', '...'])
]);

rule('oror_expression', [
    left_op(\&andand_expression, ['||', '//'])
]);

rule('andand_expression', [
    left_op(\&or_expression, ['&&'])
]);

rule('or_expression', [
    left_op(\&and_expression, ['|', '^'])
]);

rule('and_expression', [
    left_op(\&equality_expression, ['&'])
]);

rule('equality_expression', [
    nonassoc_op(\&cmp_expression, [qw(== != <=> eq ne cmp ~~)]),
    \&cmp_expression
]);

rule('cmp_expression', [
    nonassoc_op(\&shift_expression, [qw(< > <= >= lt gt le ge)]),
    \&shift_expression
]);

rule('shift_expression', [
    left_op(\&addive_expression, ['<<', '>>'])
]);

rule('addive_expression', [
    left_op(\&term, ['-', '+', '~'])
]);

rule('term', [
    left_op(\&regexp_match, ['*', '/', '%', [
        qr{^x(?![a-zA-Z])}, 'x'
    ]]),
]);

rule('regexp_match', [
    left_op(\&unary, ['=~', '!~'])
]);

rule('unary', [
    sub {
        my $c = shift;
        ($c, my $op) = match($c, '!', '~', '\\', '+', '-')
            or return;
        ($c, my $ex) = pow($c);
        return ($c, _node("UNARY$op", $ex));
    },
    \&pow
]);

# $i ** $j
# right.
rule('pow', [
    sub {
        my $c = shift;
        ($c, my $lhs) = incdec($c)
            or return;
        ($c) = match($c, '**')
            or return;
        ($c, my $rhs) = pow($c)
            or die "Missing expression after '**'";
        return ($c, _node("**", $lhs, $rhs));
    },
    \&incdec,
]);

rule('incdec', [
    sub {
        # $i++
        my $c = shift;
        ($c, my $object) = method_call($c)
            or return;
        ($c) = match($c, '++')
            or return;
        return ($c, _node2("POSTINC", $START, $object));
    },
    sub {
        # $i--
        my $c = shift;
        ($c, my $object) = method_call($c)
            or return;
        ($c) = match($c, '--')
            or return;
        return ($c, _node2("POSTDEC", $START, $object));
    },
    sub {
        # ++$i
        my $c = shift;
        ($c) = match($c, '++')
            or return;
        ($c, my $object) = method_call($c)
            or return;
        return ($c, _node2("PREINC", $START, $object));
    },
    sub {
        # --$i
        my $c = shift;
        ($c) = match($c, '--')
            or return;
        ($c, my $object) = method_call($c)
            or return;
        return ($c, _node2("PREDEC", $START, $object));
    },
    \&method_call
]);

rule('method_call', [
    sub {
        my $c = shift;
        ($c, my $object) = primary($c)
            or return;
        ($c) = match($c, '.')
            or return;
        ($c, my $method) = identifier($c)
            or return;
        ($c, my $param) = arguments($c)
            or return;
        return ($c, _node2('METHOD_CALL', $START, $object, $method, $param));
    },
    \&primary
]);

rule('parameters', [
    sub {
        my $src = shift;

        ($src) = match($src, "(")
            or return;
        confess unless defined $src;

        ($src, my $ret) = parameter_list($src);
        confess unless defined $src;

        ($src) = match($src, ")")
            or die "Parse failed: missing ')'";

        return ($src, $ret);
    }
]);

rule('parameter_list', [
    sub {
        my $src = shift;
        confess unless defined $src;

        my $ret = [];

        while (my ($src2, $var) = variable($src)) {
            $src = $src2;
            push @$ret, $var;

            (my $src3) = match($src, ',')
                or return ($src, $ret);
            $src = $src3;
        }
        return ($src, $ret);
    }
]);

rule('arguments', [
    sub {
        my $src = shift;

        ($src) = match($src, "(") or return;
        confess unless defined $src;

        ($src, my $ret) = argument_list($src);
        confess unless defined $src;

        ($src) = match($src, ")")
            or die "Parse failed: missing ')' line $LINENO";

        return ($src, $ret);
    }
]);

rule('argument_list', [
    sub {
        my $src = shift;

        my $ret = [];

        while (1) {
            (my $src2, my $var) = assign_expression($src)
                or return ($src, $ret);
            $src = $src2;
            push @$ret, $var;

            ($src) = (match($src, ',')
                or return ($src, $ret));
        }
    }
]);

rule('identifier', [
    sub {
        local $_ = shift;
        s/^\s*//;
        s/^([A-Za-z_][A-Za-z0-9_]*)// or return;
        return ($_, _node('IDENT', $1));
    }
]);

rule('variable', [
    sub {
        my $src = shift;
        confess unless defined $src;
        $src =~ s!^(\$[A-Za-z_]+)!!
            or return;
        return ($src, _node('VARIABLE', $1));
    }
]);

rule('primary', [
    sub {
        # int
        my $c = shift;
        $c =~ s/^(0x[0-9a-fA-F]+|0|[1-9][0-9]*)//
            or return;
        return ($c, _node('INT', $1));
    },
    sub {
        # NV
        my $c = shift;
        $c =~ s/^([1-9][0-9]*\.[0-9]*)// or return;
        return ($c, _node('DOUBLE', $1));
    },
    sub {
        my $c = shift;
        ($c, my $ret) = string($c)
            or return;
        return ($c, _node('STR', $ret));
    },
    sub {
        my $c = shift;
        ($c, my $ret) = _qw_literal($c)
            or return;
        ($c, $ret);
    },
    sub {
        my $c = shift;
        $c =~ s/^my\b//
            or return;
        ($c, my @body) = any(
            $c,
            sub {
                my $c = shift;
                ($c, my $body) = variable($c)
                    or return;
                return ($c, $body);
            },
            sub {
                my $c = shift;
                ($c) = match($c, '(')
                    or return;
                my @body;
                while ((my $c2, my $body) = variable($c)) {
                    $c = $c2;
                    push @body, $body;
                    (my $c3) = match($c, ',')
                        or last;
                    $c = $c3;
                }
                ($c) = match($c, ')')
                    or die "Missing ')' in my expression.";
                return ($c, @body);
            }
        );
        return unless defined $c;
        return ($c, _node2('MY', $START, \@body));
    },
    sub {
        my $c = shift;
        ($c, my $ret) = identifier($c)
            or return;
        ($c, $ret);
    },
    sub {
        my $c = shift;
        ($c, my $ret) = variable($c)
            or return;
        ($c, $ret);
    },
    sub {
        my $c = shift;
        $c =~ s/^__LINE__//
            or return;
        return ($c, _node('INT', $LINENO));
    },
    sub {
        my $c = shift;
        ($c) = match($c, "[")
            or return;
        my @body;
        while (my ($c2, $part) = assign_expression($c)) {
            $c = $c2;
            push @body, $part;

            my ($c3) = match($c, ',');
            last unless defined $c3;
            $c = $c3;
        }
        ($c) = match($c, "]")
            or return;
        return ($c, _node2('ARRAY', $START, \@body));
    },
    sub {
        my $c = shift;
        ($c) = match($c, "{")
            or return;
        my @content;
        while (my ($c2, $lhs) = assign_expression($c)) {
            push @content, $lhs;
            $c = $c2;
            ($c) = match($c, '=>')
                or die "Missing => in hash creation line $LINENO\n";
            ($c, my $rhs) = assign_expression($c);
            push @content, $rhs;

            my ($c3) = match($c, ',');
            last unless defined $c3;
            $c = $c3;
        }
        ($c) = match($c, "}")
            or die "} not found on hash at line $LINENO";
        return ($c, _node2('{}', $START, \@content));
    },
    sub {
        my $c = shift;
        ($c) = match($c, "(")
            or return;
        ($c, my $body) = expression($c);
        ($c) = match($c, ")")
            or return;
        return ($c, _node2('()', $START, $body));
    },
    sub {
        my $c = shift;
        $c =~ s/^undef\b//
            or return;
        return ($c, _node2('UNDEF', $START));
    },
]);

rule('_qw_literal', [
    sub {
        my $src = shift;

        $src =~ s!^qw([\(\[\!\{"])!!smx or return;
        my $close = quotemeta +{
            '(' => ')',
            '[' => ']',
            '{' => '}',
            '!' => '!',
            '"' => '"',
        }->{$1};
        my $ret = [];
        while (1) {
            $src = skip_ws($src);
            if ($src =~ s!^([A-Za-z0-9_]+)!!) {
                push @$ret, $1;
            } elsif ($src =~ s!^$close!!smx) {
                return ($src, _node('QW', $ret));
            } else {
                die "Parse failed in qw() literal: $src";
            }
        }
    }
]);

rule('string', [
    sub {
        # escape chars, etc.
        my $src = shift;

        $src =~ s/^"([^"]+?)"// or return;
        return ($src, $1);
    }
]);

1;
__END__

=head1 SYNOPSIS

    use Nana::Parser;

    my $parser = Nana::Parser->new();
    my $ast = $parser->parse();


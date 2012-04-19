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
# #{ } in string literal
# <<'...' <<"..."
# class call
# -> { } lambda.
# arguments with types
# do-while?
# //x
# last
# next

our $LINENO;
our $START;
our $CACHE;
our $MATCH;
our $END;

my @HEREDOC_BUFS;
my @HEREDOC_MARKERS;

our @KEYWORDS = qw(
    class sub
    return
    unless if for while do else elsif
    not
    or xor and
    lt gt eq cmp le ge ne
    isa
    undef
    true false
    self
    try die
);
my %KEYWORDS = map { $_ => 1 } @KEYWORDS;

sub new { bless {}, shift }

# rule($name, $code);
sub rule {
    my ($name, $patterns) = @_;
    no strict 'refs';
    *{"@{[ __PACKAGE__ ]}::$name"} = subname $name, sub {
        local $START = $LINENO;
        my $src = skip_ws(shift);
        return if $END;
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
    }
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
        } elsif ($word =~ /^[a-z]+$/) {
            die "Is not registered to keyword: $word"
                unless $KEYWORDS{$word};
            if ($c =~ s/^$word(?![a-zA-Z0-9_])//) {
                return ($c, $word);
            }
        } else {
            my $qword = quotemeta($word);
            if ($c =~ s/^$qword(?![&|>=])//) {
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
    local $END;

    my ($rest, $ret) = program($src);
    if (!$END && $rest =~ /[^\n \t]/) {
        die "Parse failed: " . Dumper($rest);
    }
    if (@HEREDOC_BUFS || @HEREDOC_MARKERS) {
        die "Unexpected EOF in heredoc: @HEREDOC_MARKERS";
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
        my $c = shift;
        return ($c, _node('NOP'));
    },
]);

rule('statement_list', [
    sub {
        my $src = skip_ws(shift);

        my $ret = [];
        LOOP: while (1) {
            my ($tmp, $stmt) = statement($src)
                or return ($src, _node2('STMTS', $START, $ret));
            $src = $tmp;
            push @$ret, $stmt;

            # skip spaces.
            $src =~ s/^[ \t\f]*//s;
            my $found_semicolon;
            # read next statement if found ';' or '\n'
            $src =~ s/^;//s
                and $found_semicolon++;
            $src =~ s/^\n//s
                and do {
                    ++$LINENO;
                START:
                    if (defined(my $marker = shift @HEREDOC_MARKERS)) {
                        while ($src =~ s/^(([^\n]+)(\n|$))//) {
                            if ($2 eq $marker) {
                                shift @HEREDOC_BUFS;
                                goto START;
                            } else {
                                ${$HEREDOC_BUFS[0]} .= $1;
                            }
                        }
                    } else {
                        if ($src =~ s/^__END__\n.+//s) {
                            $END++;
                            last LOOP;
                        }
                        next LOOP;
                    }
                };
            next if $found_semicolon;
            # there is no more statements, just return!
            return ($src, _node('STMTS', $ret));
        }
        return ($src, _node('STMTS', $ret));
    }
]);

rule('statement', [
    sub {
        my $c = shift;
        # class Name [isa Parent] {}
        ($c) = match($c, 'class')
            or return;
        ($c, my $name) = class_name($c)
            or die "class name expected after 'class' keyword";
        my @base;
        if ((my $c2) = match($c, 'isa')) {
            $c = $c2;
            ($c, my $base) = class_name($c)
                or die "class name expected after 'isa' keyword";
            push @base, $base;
        }
        ($c, my $block) = block($c)
            or die "Expected block after 'class' but not matched";
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
    sub { # foreach
        my $c = shift;
        ($c) = match($c, 'for')
            or return;
        ($c, my $expression) = expression($c)
            or return;
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
        return ($c, _node2('FOREACH', $START, $expression, \@vars, $block));
    },
    sub { # c-style for
        my $c = shift;
        ($c) = match($c, 'for')
            or return;
        ($c) = match($c, '(')
            or return;
        my ($e1, $e2, $e3);
        if ((my $c2, $e1) = expression($c)) { # optional
            $c = $c2;
        }
        ($c) = match($c, ';')
            or return;
        if ((my $c2, $e2) = expression($c)) {
            $c = $c2;
        }
        ($c) = match($c, ';')
            or return;
        if ((my $c2, $e3) = expression($c)) {
            $c = $c2;
        }
        ($c) = match($c, ')')
            or die "closing paren is required after 'for' keyword.";;
        ($c, my $block) = block($c)
            or die "block is required after 'for' keyword.";
        return ($c, _node2('FOR', $START, $e1, $e2, $e3, $block));
    },
    sub {
        my $c = shift;
        ($c) = match($c, 'do')
            or return;
        ($c, my $block) = block($c)
            or die "block is required after 'do' keyword.";
        return ($c, _node2('DO', $START, $block));
    },
    sub {
        # foo if bar
        my $c = shift;
        ($c, my $block) = expression($c)
            or return;
        ($c) = match($c, 'if')
            or return;
        ($c, my $expression) = expression($c)
            or die "expression required after postfix-if statement";
        return ($c, _node2('IF', $START, $expression, $block, undef));
    },
    sub {
        # foo if bar
        my $c = shift;
        ($c, my $block) = expression($c)
            or return;
        ($c) = match($c, 'unless')
            or return;
        ($c, my $expression) = expression($c)
            or die "expression required after postfix-if statement";
        return ($c, _node2('UNLESS', $START, $expression, $block, undef));
    },
    sub {
        # foo if bar
        my $c = shift;
        ($c, my $block) = expression($c)
            or return;
        ($c) = match($c, 'for')
            or return;
        ($c, my $expression) = expression($c)
            or die "expression required after postfix-if statement";
        return ($c, _node2('FOREACH', $START, $expression, [], $block));
    },
    sub {
        # foo while bar
        my $c = shift;
        ($c, my $block) = expression($c)
            or return;
        ($c) = match($c, 'while')
            or return;
        ($c, my $expression) = expression($c)
            or die "expression required after postfix-if statement";
        return ($c, _node2('WHILE', $START, $expression, $block));
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
    s/^#[^\n]+\n/++$LINENO;''/ge && goto std;
    if (s/^__END__\n.+//s) {
        $END++;
        return '';
    }
    s/^\n/++$LINENO;''/e && goto std;


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
        my $c = shift;
        ($c) = match($c, 'try') or return;
        ($c, my $block) = block($c)
            or die "expected block after try keyword";
        return ($c, _node2('TRY', $START, $block));
    },
    sub {
        my $c = shift;
        ($c) = match($c, 'die') or return;
        ($c, my $block) = expression($c)
            or die "expected expression after die keyword";
        return ($c, _node2('DIE', $START, $block));
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

        if ($END) {
            die "Invalid __END__ found in block at line $LINENO";
        }


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
        ($c, my $lhs) = expression($c)
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
    left_op(\&additive_expression, ['<<', '>>'])
]);

rule('additive_expression', [
    left_op(\&term, [[qr{^-(?![a-z>-])}, '-'], [qr{^\+(?![\+])}, '+']])
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
        ($c, my $op) = match($c, '!', '~', '\\', , [qr{^\+(?![\+])}, '+'], [qr{^-(?![>a-z-])}, '-'], '*',
                +[qr{^-e(?=[\( \t])}, "-e"],
                +[qr{^-f(?=[\( \t])}, "-f"],
                +[qr{^-x(?=[\( \t])}, "-x"],
                +[qr{^-d(?=[\( \t])}, "-d"],
            ) or return;
        ($c, my $ex) = pow($c)
            or return;
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
        # say()
        my $c = shift;
        ($c, my $lhs) = primary($c) or return;
        ($c, my $args) = arguments($c) or return;
        return ($c, _node('CALL', $lhs, $args));
    },
    sub {
        # $thing[$n]
        my $c = shift;
        ($c, my $lhs) = primary($c) or return;
        ($c) = match($c, '[')
            or return;
        ($c, my $rhs) = primary($c)
            or return;
        $rhs->[0] = 'IDENT' if $rhs->[0] eq 'PRIMARY_IDENT';
        ($c) = match($c, ']')
            or die "Unmatched bracket line $START";
        return ($c, _node('GETITEM', $lhs, $rhs));
    },
    sub {
        my $c = shift;
        ($c, my $object) = primary($c)
            or return;
        my $ret = $object;
        while (my ($c2, $op) = match($c, [qr{^\.(?!\.)}, '.'])) {
            $c = $c2;
            ($c, my $rhs) = identifier($c)
                or die "There is no identifier after '.' operator line $LINENO";
            ($c, my $param) = arguments($c)
                or return;
            $ret = _node2('METHOD_CALL', $START, $ret, $rhs, $param);
        }
        return ($c, $ret);
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

        my @args;
        while (my ($c2, $arg) = assign_expression($src)) {
            $src = $c2;
            push @args, $arg;
            (my $c3) = match($src, ',')
                or last;
            $src = $c3;
        }

        ($src) = match($src, ")")
            or die "Parse failed: missing ')' in argument parsing. line $LINENO";

        return ($src, \@args);
    }
]);

rule('identifier', [
    sub {
        local $_ = shift;
        s/^([A-Za-z_][A-Za-z0-9_]*)//
            or return;
        return if $KEYWORDS{$1} && $1 ne 'class'; # keyword is not a identifier
        return ($_, _node('IDENT', $1));
    }
]);

rule('class_name', [
    sub {
        local $_ = shift;
        s/^([A-Za-z_][A-Za-z0-9_]*)(::[A-Za-z_][A-Za-z0-9_]*)*//
            or return;
        return if $KEYWORDS{$1}; # keyword is not a identifier
        return ($_, _node('IDENT', $1));
    }
]);

rule('variable', [
    sub {
        my $src = shift;
        confess unless defined $src;
        $src =~ s!^(\$[A-Za-z_][A-Z0-9a-z_]*)!!
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
    \&string,
    \&regexp,
    sub {
        my $c = shift;
        ($c) = match($c, '${')
            or return;
        ($c, my $ret) = expression($c)
            or return;
        ($c) = match($c, '}')
            or return;
        ($c, _node("DEREF", $ret));
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
        $c =~ s/^__LINE__//
            or return;
        return ($c, _node('INT', $LINENO));
    },
    sub {
        my $c = shift;
        ($c, my $ret) = identifier($c)
            or return;
        $ret->[0] = "PRIMARY_IDENT";
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
            $lhs->[0] = 'IDENT' if $lhs->[0] eq 'PRIMARY_IDENT';
            push @content, $lhs;
            $c = $c2;
            ($c2) = match($c, '=>')
                or return;
                # or die "Missing => in hash creation '@{[ substr($c, 10) ]}...' line $LINENO\n";
            $c = $c2;
            ($c, my $rhs) = assign_expression($c);
            push @content, $rhs;

            my ($c3) = match($c, ',');
            last unless defined $c3;
            $c = $c3;
        }
        ($c) = match($c, "}")
            or return;
            # or die "} not found on hash at line $LINENO";
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
        ($c, my $word) = match($c, 'undef', 'true', 'false', 'self')
            or return;
        return ($c, _node2(uc($word), $START));
    },
    sub {
        my $c = shift;
        ($c) = match($c, q{<<'})
            or return;
        $c =~ s/^([^, \t\n']+)//
            or die "Parsing failed on heredoc LINE $LINENO";
        my $marker = $1;
        ($c) = match($c, q{'})
            or die "Parsing failed on heredoc LINE $LINENO";
        my $buf = '';
        push @HEREDOC_BUFS, \$buf;
        push @HEREDOC_MARKERS, $marker;
        return ($c, _node2('HEREDOC', $START, \$buf));
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
            if ($src =~ s!^([^ \t\Q$close\E]+)!!) {
                push @$ret, $1;
            } elsif ($src =~ s!^$close!!smx) {
                return ($src, _node('QW', $ret));
            } else {
                die "Parse failed in qw() literal: $src";
            }
        }
    }
]);

rule('regexp', [
    sub {
        my $src = shift;

        ($src) = match($src, q{/})
            or return;
        my $buf = '';
        while (1) {
            if ($src =~ s!^/!!) {
                last;
            } elsif (length($src) == 0) {
                die "Unexpected EOF in regexp literal line $START";
            } elsif ($src =~ s!^\\/!!) {
                $buf .= q{/};
            } elsif ($src =~ s/^(.)//) {
                $buf .= $1;
            } elsif ($src =~ s/^\n//) {
                $buf .= "\n";
                $LINENO++;
            } else {
                die 'should not reach here';
            }
        }
        my $flags = '';
        if ($src =~ s/^([sxmi]+)(?![a-z0-9_-])//) {
            $flags = $1;
        }
        return ($src, _node('REGEXP', $buf, $flags));
    },
]);

rule('string', [
    sub {
        # TODO: escape chars, etc.
        my $src = shift;

        ($src) = match($src, q{"})
            or return;
        my $buf = '';
        while (1) {
            if ($src =~ s/^"//) {
                last;
            } elsif (length($src) == 0) {
                die "Unexpected EOF in string literal line $START";
            } elsif ($src =~ s/^\\"//) {
                $buf .= q{"};
            } elsif ($src =~ s/^(.)//) {
                $buf .= $1;
            } else {
                die 'should not reach here';
            }
        }
        return ($src, _node('STR', $buf));
    },
    sub {
        # TODO: escape chars, etc.
        my $src = shift;

        ($src) = match($src, q{'})
            or return;
        my $buf = '';
        while (1) {
            if ($src =~ s/^'//) {
                last;
            } elsif (length($src) == 0) {
                die "Unexpected EOF in string literal line $START";
            } elsif ($src =~ s/^\\'//) {
                $buf .= q{'};
            } elsif ($src =~ s/^(.)//) {
                $buf .= $1;
            } else {
                die 'should not reach here';
            }
        }
        return ($src, _node('STR', $buf));
    },
]);

1;
__END__

=head1 NAME

Nana::Parser - parser for Nana

=head1 SYNOPSIS

    use Nana::Parser;

    my $parser = Nana::Parser->new();
    my $ast = $parser->parse();


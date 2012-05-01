package Nana::Parser;
use strict;
use warnings;
use warnings FATAL => 'recursion';
use utf8;
use 5.10.0;
use JSON::XS;
use Carp;
use Data::Dumper;
use Scalar::Util qw(refaddr);
use Sub::Name;
use XSLoader;
use Nana::Token;
use Nana::Node;

our $VERSION='0.09';

XSLoader::load('Nana::Parser', $VERSION);

# TODO:
# #{ } in string literal
# <<'...' <<"..."
# arguments with types
# do-while?
# //x

our $LINENO;
our $START;
our $CACHE;
our $MATCH;
our $FILENAME;

my @HEREDOC_BUFS;
my @HEREDOC_MARKERS;

our @KEYWORDS = qw(
    class sub
    return
    unless if for while do else elsif
    not
    or xor and
    is
    undef
    true false
    self
    use
    try die
    __FILE__ __LINE__
    last next
);
my %KEYWORDS = map { $_ => 1 } @KEYWORDS;

sub new { bless {}, shift }

# rule($name, $code);
sub rule {
    my ($name, $patterns) = @_;
    no strict 'refs';
    *{"@{[ __PACKAGE__ ]}::$name"} = subname $name, sub {
        local $START = $LINENO;
        my ($src, $got_end) = skip_ws(shift);
        return () if $got_end;
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
sub left_op2 {
    my ($upper, $ops) = @_;
    confess "\$ops must be HashRef" unless ref $ops eq 'HASH';

    sub {
        my $c = shift;
        ($c, my $lhs) = $upper->($c)
            or return;
        my $ret = $lhs;
        while (1) {
            my ($used, $token_id) = _token_op($c);
            last unless $token_id;

            my $op = $ops->{$token_id}
                or last;

            $c = substr($c, $used);
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
        my ($used, $token_id) = _token_op($c);
        return ($c, $lhs) unless $token_id;
        my $op = $ops->{$token_id}
            or return ($c, $lhs);
        $c = substr($c, $used);
        ($c, my $rhs) = $upper->($c)
            or die "Expression required after $op line $LINENO";
        return ($c, _node2($op, $START, $lhs, $rhs));
    },
}

sub match {
    my ($c, @words) = @_;
    croak "[BUG]" if @_ == 1;
    confess unless defined $c;
    ($c, my $got_end) = skip_ws($c);
    return if $got_end;
    for my $word (@words) {
        if ($word =~ /^[a-z]+$/) {
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
    my ($class, $src, $fname) = @_;
    confess unless defined $src;
    local $Data::Dumper::Terse = 1;
    local $LINENO = 1;
    local $CACHE  = {};
    local $MATCH = 0;
    local $FILENAME = $fname || '<eval>';

    my ($rest, $ret, $got_end) = program($src);
    if (!$got_end && $rest =~ /[^\n \t]/ && ![skip_ws($rest)]->[1]) {
        die "Parse failed: " . Dumper($rest);
    }
    if (@HEREDOC_BUFS || @HEREDOC_MARKERS) {
        die "Unexpected EOF in heredoc: @HEREDOC_MARKERS";
    }
    # warn $MATCH;
    $ret;
}

sub _err {
    die "@_ at $FILENAME line $LINENO\n";
}

sub _node {
    my ($type, @rest) = @_;
    confess "Obsolete type: $type" if $type =~ /\D/;
    [$type, $LINENO, @rest];
}

sub _node2 {
    my ($type, $lineno, @rest) = @_;
    confess "Obsolete type: $type" if $type =~ /\D/;
    [$type, $lineno, @rest];
}

rule('program', [
    sub {
        my $c = shift;
        ($c, my $ret, my $got_end) = statement_list($c)
            or return;
        ($c, $ret);
    },
    sub {
        my $c = shift;
        return ($c, _node(NODE_NOP));
    },
]);

rule('statement_list', [
    sub {
        my ($src, $got_end) = skip_ws(shift);
        return if $got_end;

        my $ret = [];
        LOOP: while (1) {
            my ($tmp, $stmt) = statement($src)
                or do {
                    return ($src, _node2(NODE_STMTS, $START, $ret), $got_end)
                };
            $src = $tmp;
            push @$ret, $stmt;

            # skip spaces.
            $src =~ s/^[ \t\f]*//s;
            my $have_next_stmt;
            # read next statement if found ';' or '\n'
            $src =~ s/^;//s
                and $have_next_stmt++;
            $src =~ s/^\n//s
                and do {
                    ++$LINENO;
                    $have_next_stmt++;
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
                        if ($src =~ s/\A__END__\n.+//s) {
                            $got_end++;
                            last LOOP;
                        }
                        next LOOP;
                    }
                };
            next if $have_next_stmt;
            # there is no more statements, just return!
            return ($src, _node(NODE_STMTS, $ret), $got_end);
        }
        return ($src, _node(NODE_STMTS, $ret), $got_end);
    }
]);

rule('statement', [
    sub {
        my $c = shift;
        # class Name [isa Parent] {}
        my ($used, $token_id) = _token_op($c);
        if ($token_id == TOKEN_CLASS) {
            $c = substr($c, $used);
            ($c, my $name) = class_name($c)
                or die "class name expected after 'class' keyword";
            my $base;
            if ((my $c2) = match($c, 'is')) {
                $c = $c2;
                ($c, $base) = class_name($c)
                    or die "class name expected after 'is' keyword";
                $base->[0] = NODE_PRIMARY_IDENT;
            }
            ($c, my $block) = block($c)
                or _err "Expected block after 'class' but not matched";
            return ($c, _node2(NODE_CLASS, $START, $name, $base, $block));
        } elsif ($token_id == TOKEN_RETURN) {
            $c = substr($c, $used);
            ($c, my $expression) = expression($c)
                or die "expression expected after 'return' keyword";
            return ($c, _node2(NODE_RETURN, $START, $expression));
        } elsif ($token_id == TOKEN_USE) {
            $c = substr($c, $used);
            ($c, my $klass) = class_name($c)
                or _err "class name is required after 'use' keyword";
            my $type;
            if ((my $c2) = match($c, '*')) {
                $c = $c2;
                $type = '*';
            } elsif (my ($c3, $primary) = primary($c)) {
                $c = $c3;
                $type = $primary;
            } else {
                $type = _node(NODE_UNDEF);
            }
            return ($c, _node2(NODE_USE, $START, $klass, $type));
        } elsif ($token_id == TOKEN_UNLESS) {
            $c = substr($c, $used);
            ($c, my $expression) = expression($c)
                or die "expression is required after 'unless' keyword";
            ($c, my $block) = block($c)
                or die "block is required after unless keyword.";
            return ($c, _node2(NODE_IF, $START, _node2(NODE_UNARY_NOT, $START, $expression), $block));
        } elsif ($token_id == TOKEN_IF) {
            $c = substr($c, $used);
            ($c, my $expression) = expression($c)
                or die "expression is required after 'if' keyword line $LINENO";
            ($c, my $block) = block($c)
                or die "block is required after if keyword line $LINENO.";
            my $else;
            if ((my $c2, $else) = else_clause($c)) { # optional
                $c = $c2;
            }
            return ($c, _node2(NODE_IF, $START, $expression, $block, $else));
        } elsif ($token_id == TOKEN_WHILE) {
            $c = substr($c, $used);
            ($c, my $expression) = expression($c)
                or die "expression is required after 'while' keyword";
            ($c, my $block) = block($c)
                or die "block is required after while keyword.";
            return ($c, _node2(NODE_WHILE, $START, $expression, $block));
        } elsif ($token_id == TOKEN_DO) {
            $c = substr($c, $used);
            ($c, my $block) = block($c)
                or die "block is required after 'do' keyword.";
            return ($c, _node2(NODE_DO, $START, $block));
        } elsif ($token_id == TOKEN_LBRACE) {
            return block($c);
        } elsif ($token_id == TOKEN_FOR) {
            any(
                substr($c, $used),
                sub { # foreach
                    my $c = shift;
                    ($c, my $expression) = expression($c)
                        or return;
                    (my $c2) = match($c, '->')
                        or _err "'->' missing after for keyword '" . substr($c, 0, 15) . "..'";
                    $c = $c2;
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
                    return ($c, _node2(NODE_FOREACH, $START, $expression, \@vars, $block));
                },
                sub { # C style for
                    my $c = shift;
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
                    return ($c, _node2(NODE_FOR, $START, $e1, $e2, $e3, $block));
                }
            );
        } else {
            return;
        }
    },
    sub {
        my $c = shift;
        ($c, my $block) = expression($c)
            or return;
        my ($used, $token_id) = _token_op($c);
        if ($token_id == TOKEN_IF) {
            # foo if bar
            $c = substr($c, $used);
            ($c, my $expression) = expression($c)
                or die "expression required after postfix-if statement";
            return ($c, _node2(NODE_IF, $START, $expression, _node(NODE_BLOCK, $block), undef));
        } elsif ($token_id == TOKEN_UNLESS) {
            # foo unless bar
            $c = substr($c, $used);
            ($c, my $expression) = expression($c)
                or die "expression required after postfix-unless statement";
            return ($c, _node2(NODE_IF, $START, _node(NODE_UNARY_NOT, $expression), _node(NODE_BLOCK, $block), undef));
        } elsif ($token_id == TOKEN_FOR) {
            # foo for bar
            $c = substr($c, $used);
            ($c, my $expression) = expression($c)
                or die "expression required after postfix-for statement";
            return ($c, _node2(NODE_FOREACH, $START, $expression, [], _node(NODE_BLOCK, $block)));
        } elsif ($token_id == TOKEN_WHILE) {
            # foo while bar
            $c = substr($c, $used);
            ($c, my $expression) = expression($c)
                or die "expression required after postfix-if statement";
            return ($c, _node2(NODE_WHILE, $START, $expression, _node(NODE_BLOCK, $block)));
        } else {
            return ($c, $block);
        }
    },
]);

rule('else_clause', [
    sub {
        my $c = shift;
        my ($used, $token_id) = _token_op($c);
        if ($token_id == TOKEN_ELSIF) {
            $c = substr($c, $used);
            ($c, my $expression) = expression($c)
                or _err "expression is required after 'elsif' keyword";
            ($c, my $block) = block($c)
                or _err "block is required after elsif keyword.";
            my $else;
            if ((my $c2, $else) = else_clause($c)) { # optional
                $c = $c2;
            }
            return ($c, _node2(NODE_ELSIF, $START, $expression, $block, $else));
        } elsif ($token_id == TOKEN_ELSE) {
            $c = substr($c, $used);
            ($c, my $block) = block($c)
                or _err "block is required after else keyword.";
            return ($c, _node2(NODE_ELSE, $START, $block));
        } else {
            return;
        }
    },
]);

# skip whitespace with line counting

rule('expression', [
    sub {
        my $c = shift;
        my ($used, $token_id) = _token_op($c);
        if ($token_id == TOKEN_LAST) {
            return (substr($c, $used), _node2(NODE_LAST, $START));
        } elsif ($token_id == TOKEN_NEXT) {
            return (substr($c, $used), _node2(NODE_NEXT, $START));
        } elsif ($token_id == TOKEN_SUB) {
            $c = substr($c, $used);
            # name is optional thing.
            # you can use anon sub.
            my $name;
            if ((my $c2, $name) = identifier($c)) {
                $c = $c2;
            }

            my $params;
            if ((my $c2, $params) = parameters($c)) {
                # optional
                $c = $c2;
            }

            ($c, my $block) = block($c)
                or _err "expected block after sub in $name->[2]";
            return ($c, _node2(NODE_SUB, $START, $name, $params, $block));
        } elsif ($token_id == TOKEN_TRY) {
            $c = substr($c, $used);
            ($c, my $block) = block($c)
                or _err "expected block after try keyword";
            return ($c, _node2(NODE_TRY, $START, $block));
        } elsif ($token_id == TOKEN_DIE) {
            $c = substr($c, $used);
            ($c, my $block) = expression($c)
                or die "expected expression after die keyword";
            return ($c, _node2(NODE_DIE, $START, $block));
        } else {
            return str_or_expression($c);
        }
    },
]);

rule('block', [
    sub {
        my $src = shift;
        ($src) = match($src, '{')
            or return;

        ($src, my $body, my $got_end) = statement_list($src)
            or return;

        if ($got_end) {
            die "Invalid __END__ found in block at line $LINENO";
        }


        ($src) = match($src, '}')
            or return;
        return ($src, $body ? _node2(NODE_BLOCK, $START, $body) : _node(NODE_NOP));
    }
]);

rule('str_or_expression', [
    left_op2(\&str_and_expression, +{ TOKEN_STR_OR() => NODE_LOGICAL_OR, TOKEN_STR_XOR() => NODE_LOGICAL_XOR}),
]);

rule('str_and_expression', [
    left_op2(\&not_expression, +{ TOKEN_STR_AND() => NODE_LOGICAL_AND}),
]);

rule('not_expression', [
    sub {
        my $src = shift;
        my ($used, $token_id) = _token_op($src);
        if ($token_id == TOKEN_STR_NOT) {
            $src = substr($src, $used);
            ($src, my $body) = not_expression($src)
                or die "Cannot get expression after 'not'";
            return ($src, _node(NODE_UNARY_NOT, $body));
        } else {
            return comma_expression($src);
        }
    },
]);

rule('comma_expression', [
    left_op2(\&assign_expression, +{TOKEN_COMMA() => NODE_COMMA})
]);

# %right
rule('assign_expression', [
    sub {
        my $c = shift;
        ($c, my $rhs) = three_expression($c)
            or return;
        my ($used, $token_id) = _token_op($c);
        my $op = +{
            TOKEN_ASSIGN()        => NODE_ASSIGN,
            TOKEN_MUL_ASSIGN()    => NODE_MUL_ASSIGN,
            TOKEN_PLUS_ASSIGN()   => NODE_PLUS_ASSIGN,
            TOKEN_DIV_ASSIGN()    => NODE_DIV_ASSIGN,
            TOKEN_MOD_ASSIGN()    => NODE_MOD_ASSIGN,
            TOKEN_MINUS_ASSIGN()  => NODE_MINUS_ASSIGN,
            TOKEN_LSHIFT_ASSIGN() => NODE_LSHIFT_ASSIGN,
            TOKEN_RSHIFT_ASSIGN() => NODE_RSHIFT_ASSIGN,
            TOKEN_POW_ASSIGN()    => NODE_POW_ASSIGN,
            TOKEN_AND_ASSIGN()    => NODE_AND_ASSIGN,
            TOKEN_OR_ASSIGN()     => NODE_OR_ASSIGN,
            TOKEN_XOR_ASSIGN()    => NODE_XOR_ASSIGN,
            TOKEN_OROR_ASSIGN()   => NODE_OROR_ASSIGN,
        }->{$token_id};
        if ($op) {
            $c = substr($c, $used);
            ($c, my $lhs) = expression($c)
                or _err "Cannot get expression after $op";
            return ($c, _node($op, $rhs, $lhs));
        } else {
            return ($c, $rhs);
        }
    }
]);

# %right
rule('three_expression', [
    sub {
        my $c = shift;
        ($c, my $t1) = dotdot_expression($c)
            or return;
        my ($used, $token_id) = _token_op($c);
        if ($token_id == TOKEN_QUESTION) {
            $c = substr($c, $used);
            ($c, my $t2) = three_expression($c)
                or return;
            ($c) = match($c, ':')
                or return;
            ($c, my $t3) = three_expression($c)
                or return;
            return ($c, _node(NODE_THREE, $t1, $t2, $t3));
        } else {
            return ($c, $t1);
        }
    },
]);

rule('dotdot_expression', [
    left_op2(\&oror_expression, +{ TOKEN_DOTDOT() => NODE_DOTDOT, TOKEN_DOTDOTDOT() => NODE_DOTDOTDOT})
]);

rule('oror_expression', [
    left_op2(\&andand_expression, +{ TOKEN_OROR() => NODE_LOGICAL_OR })
]);

rule('andand_expression', [
    left_op2(\&or_expression, {TOKEN_ANDAND() => NODE_LOGICAL_AND})
]);

rule('or_expression', [
    left_op2(\&and_expression, +{TOKEN_OR() => NODE_BITOR, TOKEN_XOR() => NODE_BITXOR})
]);

rule('and_expression', [
    left_op2(\&equality_expression, {TOKEN_AND() => NODE_BITAND})
]);

rule('equality_expression', [
    nonassoc_op(\&cmp_expression, {TOKEN_EQUAL_EQUAL() => NODE_EQ, TOKEN_NOT_EQUAL() => NODE_NE, TOKEN_CMP() => NODE_CMP})
]);

rule('cmp_expression', [
    nonassoc_op(\&shift_expression, {TOKEN_GT() => NODE_GT, TOKEN_LT() => NODE_LT, TOKEN_GE() => NODE_GE, TOKEN_LE() => NODE_LE})
]);

rule('shift_expression', [
    left_op2(\&additive_expression, +{ TOKEN_LSHIFT() => NODE_LSHIFT, TOKEN_RSHIFT() => NODE_RSHIFT})
]);

rule('additive_expression', [
    left_op2(\&term, +{ TOKEN_MINUS() => NODE_MINUS, TOKEN_PLUS() => NODE_PLUS})
]);

rule('term', [
    left_op2(\&regexp_match, +{
        TOKEN_MUL() => NODE_MUL,
        TOKEN_DIV() => NODE_DIV,
        TOKEN_MOD() => NODE_MOD,
    }),
]);

rule('regexp_match', [
    left_op2(\&unary, +{ TOKEN_REGEXP_MATCH() => NODE_REGEXP_MATCH, TOKEN_REGEXP_NOT_MATCH() => NODE_REGEXP_NOT_MATCH})
]);

rule('unary', [
    sub {
        my $c = shift;
        my ($used, $token_id) = _token_op($c);
        if ($token_id == TOKEN_FILETEST) {
            # file test
            my $op = substr($c, $used-2, 2);
            $c = substr($c, $used);
            ($c, my $ex) = pow($c)
                or return;
            return ($c, _node(NODE_FILE_TEST, $op, $ex));
        } else {
            my $op = +{
                TOKEN_NOT() => NODE_UNARY_NOT,
                TOKEN_TILDE() => NODE_UNARY_TILDE,
                TOKEN_REF() => NODE_UNARY_REF,
                TOKEN_PLUS() => NODE_UNARY_PLUS,
                TOKEN_MINUS() => NODE_UNARY_MINUS,
                TOKEN_MUL() => NODE_UNARY_MUL,
            }->{$token_id};
            return unless $op;
            $c = substr($c, $used);
            ($c, my $ex) = unary($c)
                or _err "Missing expression after $op";
            return ($c, _node($op, $ex));
        }
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
        my ($len, $token) = _token_op($c);
        if ($token && $token == TOKEN_POW) {
            $c = substr($c, $len);
            ($c, my $rhs) = pow($c)
                or die "Missing expression after '**'";
            return ($c, _node(NODE_POW, $lhs, $rhs));
        } else {
            return ($c, $lhs);
        }
    },
]);

rule('incdec', [
    sub {
        # ++$i or --$i
        my $c = shift;
        my ($len, $token) = _token_op($c);
        if ($token) {
            if ($token == TOKEN_PLUSPLUS) {
                $c = substr($c, $len);
                ($c, my $object) = method_call($c)
                    or return;
                return ($c, _node2(NODE_PRE_INC, $START, $object));
            } elsif ($token == TOKEN_MINUSMINUS) {
                $c = substr($c, $len);
                ($c, my $object) = method_call($c)
                    or return;
                return ($c, _node2(NODE_PRE_DEC, $START, $object));
            }
        }
        return ();
    },
    sub {
        # $i++ or $i--
        my $c = shift;
        ($c, my $object) = method_call($c)
            or return;

        my ($len, $token) = _token_op($c);
        if ($token) {
            if ($token == TOKEN_PLUSPLUS) {
                $c = substr($c, $len);
                return ($c, _node2(NODE_POST_INC, $START, $object));
            } elsif ($token == TOKEN_MINUSMINUS) {
                $c = substr($c, $len);
                return ($c, _node2(NODE_POST_DEC, $START, $object));
            } else {
                return ($c, $object); # ++, -- is optional
            }
        } else {
            return ($c, $object); # ++, -- is optional
        }
    },
]);

rule('method_call', [
    sub {
        my $c = shift;
        ($c, my $object) = funcall($c)
            or return;
        my $ret = $object;
        while (1) {
            my ($used, $token_id, $val) = _token_op($c);
            last unless $token_id == TOKEN_DOT;
            $c = substr($c, $used);
            ($c, my $rhs) = identifier($c)
                or _err "There is no identifier after '.' operator in method call";
            if ((my $c3, my $param) = arguments($c)) {
                $c = $c3;
                $ret = _node2(NODE_METHOD_CALL, $START, $ret, $rhs, $param);
            } else {
                $ret = _node2(NODE_GET_METHOD, $START, $ret, $rhs);
            }
        }
        return ($c, $ret);
    },
    \&funcall
]);

rule('funcall', [
    sub {
        my $c = shift;
        ($c, my $lhs) = primary($c)
            or return;
        if (my ($c2) = match($c, '[')) {
            # $thing[$n]
            $c = $c2;
            ($c, my $rhs) = expression($c)
                or return;
            $rhs->[0] = NODE_IDENT if $rhs->[0] eq NODE_PRIMARY_IDENT;
            ($c) = match($c, ']')
                or die "Unmatched bracket line $START";
            return ($c, _node(NODE_GETITEM, $lhs, $rhs));
        } elsif (my ($c3, $args) = arguments($c)) {
            # say()
            $c = $c3;
            return ($c, _node(NODE_CALL, $lhs, $args));
        } else {
            # primary
            return ($c, $lhs);
        }
    },
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
            or die "Parse failed: missing ')' on subroutine parameters line $LINENO";

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

            if (my ($c2) = match($src, '=')) {
                $src = $c2;
                ($src, my $default) = primary($src)
                    or _err "Missing primary expression after '=' in parametes";
                push @$ret, _node(NODE_PARAMS_DEFAULT, $var, $default);
            } else {
                push @$ret, $var;
            }

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

        my ($src2) = match($src, ")")
            or _err "Parse failed: missing ')' in argument parsing: '" . substr($src, 0, 20) . q{...'};
        $src = $src2;

        return ($src, \@args);
    }
]);

rule('identifier', [
    sub {
        local $_ = shift;
        s/^([A-Za-z_][A-Za-z0-9_]*)//
            or return;
        my $name = $1;
        return if $KEYWORDS{$name} && $name ne 'class' && $name ne 'is'; # keyword is not a identifier
        return ($_, _node(NODE_IDENT, $name));
    }
]);

rule('class_name', [
    sub {
        local $_ = shift;
        s/^(([A-Za-z_][A-Za-z0-9_]*)(::[A-Za-z_][A-Za-z0-9_]*)*)//
            or return;
        return if $KEYWORDS{$1}; # keyword is not a identifier
        return ($_, _node(NODE_IDENT, $1));
    }
]);

rule('variable', [
    sub {
        my $src = shift;
        confess unless defined $src;
        $src =~ s!^(\$[A-Za-z_][A-Z0-9a-z_]*)!!
            or return;
        return ($src, _node(NODE_VARIABLE, $1));
    }
]);

rule('primary', [
    sub {
        my $c = shift;

        my ($used, $token_id, $val) = _token_op($c);
        if ($token_id == TOKEN_LAMBDA) { # -> $x { }
            $c = substr($c, $used);

            my @params;
            while ((my $c2, my $param) = variable($c)) {
                push @params, $param;
                $c = $c2;
                my ($c3) = match($c, ',')
                    or last;
                $c = $c3;
            }

            ($c, my $block) = block($c)
                or _err "expected block after ->";
            return ($c, _node2(NODE_LAMBDA, $START, \@params, $block));
        } elsif ($token_id == TOKEN_DEREF) {
            $c = substr($c, $used);

            ($c, my $ret) = expression($c)
                or return;
            ($c) = match($c, '}')
                or _err "Closing brace is not found after \${ operator";
            return ($c, _node(NODE_DEREF, $ret));
        } elsif ($token_id == TOKEN_LBRACKET) {
            # array creation
            # [1, 2, 3]

            $c = substr($c, $used);
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
            return ($c, _node2(NODE_MAKE_ARRAY, $START, \@body));
        } elsif ($token_id == TOKEN_STRING_SQ) { # '
            return _sq_string(substr($c, $used), q{'});
        } elsif ($token_id == TOKEN_STRING_Q_START) { # q{
            return _sq_string(substr($c, $used), _closechar(substr($c, $used-1, 1)));
        } elsif ($token_id == TOKEN_STRING_DQ) { # "
            return _dq_string(substr($c, $used), q{"});
        } elsif ($token_id == TOKEN_STRING_QQ_START) { # qq{
            return _dq_string(substr($c, $used), _closechar(substr($c, $used-1, 1)));
        } elsif ($token_id == TOKEN_DIV) { # /
            return _regexp(substr($c, $used), q{/});
        } elsif ($token_id == TOKEN_REGEXP_QR_START) { # qr{
            return _regexp(substr($c, $used), _closechar(substr($c, $used-1, 1)));
        } elsif ($token_id == TOKEN_QW_START) { # qw{
            return _qw_literal(substr($c, $used), _closechar(substr($c, $used-1, 1)));
        } elsif ($token_id ==TOKEN_HEREDOC_SQ_START) { # <<'
            $c = substr($c, $used);
            $c =~ s/^([^, \t\n']+)//
                or die "Parsing failed on heredoc LINE $LINENO";
            my $marker = $1;
            ($c) = match($c, q{'})
                or die "Parsing failed on heredoc LINE $LINENO";
            my $buf = '';
            push @HEREDOC_BUFS, \$buf;
            push @HEREDOC_MARKERS, $marker;
            return ($c, _node2(NODE_HEREDOC, $START, \$buf));
        } elsif ($token_id ==TOKEN_BYTES_SQ) { # b'
            return _bytes_sq(substr($c, $used), 0);
        } elsif ($token_id ==TOKEN_BYTES_DQ) { # b"
            return _bytes_dq(substr($c, $used), 0);
        } elsif ($token_id == TOKEN_LPAREN) { # (
            $c = substr($c, $used);
            ($c, my $body) = expression($c)
                or return;
            ($c) = match($c, ")")
                or return;
            return ($c, $body);
        } elsif ($token_id == TOKEN_LBRACE) { # {
            $c = substr($c, $used);
            my @content;
            while (my ($c2, $lhs) = assign_expression($c)) {
                $lhs->[0] = NODE_IDENT if $lhs->[0] eq NODE_PRIMARY_IDENT;
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
            return ($c, _node2(NODE_MAKE_HASH, $START, \@content));
        } elsif ($token_id == TOKEN_INTEGER) {
            return (substr($c, $used), _node(NODE_INT, $val));
        } elsif ($token_id == TOKEN_DOUBLE) {
            return (substr($c, $used), _node(NODE_DOUBLE, $val));
        } elsif ($token_id == TOKEN_UNDEF) {
            $c = substr($c, $used);
            return ($c, _node(NODE_UNDEF, $LINENO));
        } elsif ($token_id == TOKEN_TRUE) {
            $c = substr($c, $used);
            return ($c, _node(NODE_TRUE, $LINENO));
        } elsif ($token_id == TOKEN_FALSE) {
            $c = substr($c, $used);
            return ($c, _node(NODE_FALSE, $LINENO));
        } elsif ($token_id == TOKEN_SELF) {
            $c = substr($c, $used);
            return ($c, _node(NODE_SELF, $LINENO));
        } elsif ($token_id == TOKEN_FILE) {
            $c = substr($c, $used);
            return ($c, _node(NODE___FILE__, $LINENO));
        } elsif ($token_id == TOKEN_LINE) {
            $c = substr($c, $used);
            return ($c, _node(NODE_INT, $LINENO));
        } elsif ($token_id == TOKEN_IDENT) {
            return (substr($c, $used), _node(NODE_PRIMARY_IDENT, $val));
        } elsif ($token_id == TOKEN_CLASS_NAME) {
            return (substr($c, $used), _node(NODE_PRIMARY_IDENT, $val));
        } elsif ($token_id == TOKEN_VARIABLE) {
            return (substr($c, $used), _node(NODE_VARIABLE, $val));
        } elsif ($token_id == TOKEN_MY) {
            $c = substr($c, $used);
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
            return ($c, _node2(NODE_MY, $START, \@body));
        } else {
            return;
        }
    },
]);

sub _qw_literal {
    my ($src, $close) = @_;
    $close = quotemeta($close);

    my $ret = [];
    while (1) {
        ($src, my $got_end) = skip_ws($src);
        return if $got_end;
        if ($src =~ s!^([^ \t\Q$close\E]+)!!) {
            push @$ret, $1;
        } elsif ($src =~ s!^$close!!smx) {
            return ($src, _node(NODE_QW, $ret));
        } else {
            die "Parse failed in qw() literal: $src";
        }
    }
}

sub _regexp {
    my ($src, $close) = @_;

    my $buf = '';
    while (1) {
        if ($src =~ s!^$close!!) {
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
    if ($src =~ s/^([sxmig]+)(?![a-z0-9_-])//) {
        $flags = $1;
    }
    return ($src, _node(NODE_REGEXP, $buf, $flags));
}

sub _bytes_dq {
    # TODO: escape chars, etc.
    my $src = shift;

    my $buf = '';
    while (1) {
        if ($src =~ s/^"//) {
            last;
        } elsif (length($src) == 0) {
            die "Unexpected EOF in bytes literal line $START";
        } elsif ($src =~ s/^\\"//) {
            $buf .= q{"};
        } elsif ($src =~ s/^(\\[0-7]{3})//) {
            $buf .= $1;
        } elsif ($src =~ s/^(\\x[0-9a-f]{2})//) {
            $buf .= $1;
        } elsif ($src =~ s/^(.)//) {
            $buf .= $1;
        } else {
            die 'should not reach here';
        }
    }
    return ($src, _node(NODE_BYTES, $buf));
}

sub _bytes_sq {
    # TODO: escape chars, etc.
    my $src = shift;

    my $buf = '';
    while (1) {
        if ($src =~ s/^'//) {
            last;
        } elsif (length($src) == 0) {
            die "Unexpected EOF in bytes literal line $START";
        } elsif ($src =~ s/^\\'//) {
            $buf .= q{'};
        } elsif ($src =~ s/^(\\[0-7]{3})//) {
            $buf .= $1;
        } elsif ($src =~ s/^(\\x[0-9a-f]{2})//) {
            $buf .= $1;
        } elsif ($src =~ s/^(.)//) {
            $buf .= $1;
        } else {
            die 'should not reach here';
        }
    }
    return ($src, _node(NODE_BYTES, $buf));
}

sub _dq_string {
    # TODO: escape chars, etc.
    my ($src, $close) = @_;

    my $bufref = \do { my $o="" };
    my $node = _node(NODE_STR2, $bufref);
    while (1) {
        if ($src =~ s/^$close//) {
            last;
        } elsif (length($src) == 0) {
            die "Unexpected EOF in string literal line $START";
        } elsif ($src =~ s/^(\\0[0-7]{2})//) {
            $$bufref .= eval 'qq{'.$1.'}';
        } elsif ($src =~ s/^(\$[a-zA-Z_][a-zA-Z0-9_]*)//) {
            $bufref = \do { my $o="" };
            my $node2 = _node(NODE_STR2, $bufref);
            $node = _node(NODE_STRCONCAT, $node, $1, $node2);
        } elsif ($src =~ s/^\\0//) {
            $$bufref.= qq{\0};
        } elsif ($src =~ s/^\\r//) {
            $$bufref .= qq{\r};
        } elsif ($src =~ s/^\\t//) {
            $$bufref .= qq{\t};
        } elsif ($src =~ s/^\\n//) {
            $$bufref .= qq{\n};
        } elsif ($src =~ s/^\\n//) {
            $$bufref .= qq{\n};
        } elsif ($src =~ s/^\\"//) {
            $$bufref .= q{"};
        } elsif ($src =~ s/^(.)//ms) {
            $$bufref .= $1;
        } else {
            _err 'should not reach here';
        }
    }
    return ($src, $node);
}

sub _sq_string {
    my ($src, $close) = @_;
    my $buf = '';
    while (1) {
        if ($src =~ s/^$close//) {
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
    return ($src, _node(NODE_STR, $buf));
}

sub _closechar {
    my $openchar = shift;
    {
        '!' => '!',
        '{' => '}',
        '[' => ']',
        '"' => '"',
        "'" => "'",
        "(" => ")",
    }->{$openchar};
}

1;
__END__

=head1 NAME

Nana::Parser - parser for Tora language

=head1 SYNOPSIS

    use Nana::Parser;

    my $parser = Nana::Parser->new();
    my $ast = $parser->parse();

=head1 DESCRIPTION

This is a parser class for Tora language.

=head1 METHODS

=over 4

=item my $parser = Nana::Parser->new();

Create a new instance of Nana::Parser.

=item my $ast = $parser->parse(Str $src[, Str $fname])

Parse a $src and return abstract syntax tree. AST is pure perl arrayref. It's not object.

You can pass $fname for debuggability and __FILE__.

=back

=head1 NOTE

This version of Nana::Parser is very slow. I want to rewrite this class by C.

=head1 AUTHOR

Tokuhiro Matsuno

=head1 SEE ALSO

L<http://tora-lang.org> for more details.


package Nana::Parser;
use strict;
use warnings;
use warnings FATAL => 'recursion';
use utf8;
use Carp;
use Data::Dumper;
use Scalar::Util qw(refaddr);

our $LINENO;
our $START;
our $CACHE;
our $MATCH;

sub new { bless {}, shift }

# rule($name, $code);
sub rule {
    my ($name, $patterns) = @_;
    no strict 'refs';
    *{"@{[ __PACKAGE__ ]}::$name"} = sub {
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
    local $START = $LINENO;
    for (@_) {
        local $LINENO = $LINENO;
        my @a = $_->();
        return @a if @a;
    }
    return ();
}

sub match {
    my ($c, @words) = @_;
    croak "[BUG]" if @_ == 1;
    confess unless defined $c;
    $c =~ s/^\s*//;
    for my $word (@words) {
        my $qword = quotemeta($word);
        if ($c =~ s/^$qword//) {
            return ($c, $word);
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

rule('expression_list', [
    sub {
        my $src = shift;

        my $start = $LINENO;
        my $ret = [];
        LOOP: while (1) {
            my ($tmp, $stmt) = expression($src)
                or return ($src, _node2('EXPRESSIONS', $start, $ret));
            $src = $tmp;
            push @$ret, $stmt;

            # skip spaces.
            $src = skip_ws($src);
            # read next statement if found ','
            $src =~ s/^,//s
                and next;
            # there is no more statements, just return!
            return ($src, _node('EXPRESSIONS', $ret));
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
        ($c) = match($c, 'if')
            or return;
        ($c, my $expression) = expression($c)
            or die "expression is required after 'if' keyword";
        ($c, my $block) = block($c)
            or die "block is required after if keyword.";
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
        ($c, my $ret) = expression($c)
            or return;
        return ($c, $ret);
    },
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
    \&addive_expression
]);

rule('addive_expression', [
    sub {
        # see http://en.wikipedia.org/wiki/Parsing_expression_grammar#Indirect_left_recursion
        my $c = shift;
        my $ret;
        ($c, my $lhs) = term($c)
            or return;
        $ret = $lhs;
        while ((my $c2, my $op) = match($c, '-', '+', '~')) {
            $c = $c2;
            ($c, my $rhs) = term($c)
                or die "term is required after '$op' operator";
            $ret = _node($op, $ret, $rhs);
        }
        return () if "$ret" eq "$lhs";
        return ($c, $ret);
    },
    \&term
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

rule('term', [
    sub {
        my $c = shift;
        ($c, my $lhs) = pow($c)
            or return;
        ($c) = match($c, '*')
            or return;
        ($c, my $rhs) = term($c)
            or return;
        return ($c, _node('*', $lhs, $rhs));
    },
    sub {
        my $c = shift;
        ($c, my $lhs) = pow($c)
            or return;
        ($c) = match($c, '/')
            or return;
        ($c, my $rhs) = term($c)
            or return;
        return ($c, _node('/', $lhs, $rhs));
    },
    \&pow,
]);

rule('pow', [
    sub {
        # $i ** $j
        my $c = shift;
        ($c, my $lhs) = incdec($c)
            or return;
        ($c) = match($c, "**")
            or return;
        ($c, my $rhs) = incdec($c)
            or return;
        return ($c, _node2('**', $START, $lhs, $rhs));
    },
    \&incdec
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
            (my $src2, my $var) = expression($src)
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
        $c =~ s/^([1-9][0-9]*)//
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
        ($c, my $body) = expression_list($c);
        ($c) = match($c, "]")
            or return;
        return ($c, _node2('ARRAY', $START, $body));
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
]);

rule('_qw_literal', [
    sub {
        my $src = shift;

        $src =~ s!^qw([\(\[\!\{])!!smx or return;
        my $close = quotemeta +{
            '(' => ')',
            '[' => ']',
            '{' => '}',
            '!' => '!',
        }->{$1};
        my $ret = [];
        while (1) {
            $src =~ s/^\s*//;
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


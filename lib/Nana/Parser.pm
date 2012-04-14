package Nana::Parser;
use strict;
use warnings;
use warnings FATAL => 'recursion';
use utf8;
use Carp;
use Data::Dumper;

our $LINENO;
our $START;

sub new { bless {}, shift }


sub parse {
    my ($class, $src) = @_;
    confess unless defined $src;
    local $Data::Dumper::Terse = 1;
    local $LINENO = 1;

    my ($rest, $ret) = program($src);
    if ($rest =~ /[^\n \t]/) {
        die "Parse failed: " . Dumper($rest);
    }
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

sub program {
    my $src = skip_ws(shift);

    any(
        sub {
            my $c = $src;
            ($c, my $ret) = statement_list($c)
                or return;
            ($c, $ret);
        },
        sub {
            return ($src, _node('NOP'));
        },
    );
}

sub statement_list {
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

sub expression_list {
    my $src = skip_ws(shift);

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

sub statement {
    my $src = skip_ws(shift);

    any(
        sub {
            my $c = $src;
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
            my $c = $src;
            ($c) = match($c, 'return')
                or return;
            ($c, my $expression) = expression($c)
                or die "expression expected after 'return' keyword";
            return ($c, _node2('RETURN', $START, $expression));
        },
        sub {
            my $c = $src;
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
            my $c = $src;
            ($c) = match($c, 'while')
                or return;
            ($c, my $expression) = expression($c)
                or die "expression is required after 'while' keyword";
            ($c, my $block) = block($c)
                or die "block is required after while keyword.";
            return ($c, _node2('WHILE', $START, $expression, $block));
        },
        sub {
            my $c = $src;
            ($c, my $ret) = expression($c)
                or return;
            return ($c, $ret);
        },
    );
}

sub else_clause {
    my $src = skip_ws(shift);
    any(
        sub {
            my $c = $src;
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
            my $c = $src;
            ($c) = match($c, 'else')
                or return;
            ($c, my $block) = block($c)
                or die "block is required after elsif keyword.";
            return ($c, _node2('ELSE', $START, $block));
        },
    );
}

# skip whitespace with line counting
sub skip_ws {
    local $_ = shift;
    s/^[ \t\f]//;
    s/^\n/++$LINENO;''/ge;
    $_;
}

sub expression {
    my $src = skip_ws(shift);

    any(
        sub {
            my $c = $src;

            ($c)           = match($c, 'sub') or return;
            ($c, my $name) = identifier($c)   or die "Parsing error";

            my $params;
            if ((my $c2, $params) = parameters($c)) {
                # optional
                $c = $c2;
            }

            ($c, my $block) = block($c)
                or die "expected block after sub in $name->[1] : " . substr($c, 1024);
            return ($c, _node2('SUB', $START, $name, $params, $block));
        },
        sub {
            # say()
            my $c = $src;
            ($c, my $lhs) = addive_expression($c) or return;
            ($c, my $args) = arguments($c) or return;
            return ($c, _node('CALL', $lhs, $args));
        },
        sub {
            my $c = $src;
            ($c, my $ret) = addive_expression($c)
                or return;
            return ($c, $ret);
        }
    );
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

sub addive_expression {
    my $src = skip_ws(shift);

    any(
        sub {
            my $c = $src;
            ($c, my $lhs) = term($c)
                or return;
            ($c) = match($c, '+')
                or return;
            ($c, my $rhs) = expression($c)
                or return;
            return ($c, _node('+', $lhs, $rhs));
        },
        sub {
            my $c = $src;
            ($c, my $lhs) = term($c)
                or return;
            ($c) = match($c, '-')
                or return;
            ($c, my $rhs) = expression($c)
                or return;
            return ($c, _node('-', $lhs, $rhs));
        },
        sub {
            my $c = $src;
            ($c, my $lhs) = term($c)
                or return;
            ($c) = match($c, '~')
                or return;
            ($c, my $rhs) = expression($c)
                or return;
            return ($c, _node('~', $lhs, $rhs));
        },
        sub {
            my $c = $src;
            ($c, my $ret) = term($c)
                or return;
            return ($c, $ret);
        }
    );
}

sub block {
    my $src = skip_ws(shift);
    ($src) = match($src, '{')
        or return;

    ($src, my $body) = statement_list($src)
        or return;

    ($src) = match($src, '}')
        or return;
    return ($src, $body || _node('NOP'));
}

sub term {
    my $src = skip_ws(shift);

    any(
        sub {
            my $c = $src;
            ($c, my $lhs) = method_call($c)
                or return;
            ($c) = match($c, '*')
                or return;
            ($c, my $rhs) = term($c)
                or return;
            return ($c, _node('*', $lhs, $rhs));
        },
        sub {
            my $c = $src;
            ($c, my $lhs) = method_call($c)
                or return;
            ($c) = match($c, '/')
                or return;
            ($c, my $rhs) = term($c)
                or return;
            return ($c, _node('/', $lhs, $rhs));
        },
        sub {
            my $c = $src;
            ($c, my $ret) = method_call($c)
                or return;
            return ($c, $ret);
        },
    );
}

sub method_call {
    my $src = skip_ws(shift);
    any(
        sub {
            my $c = $src;
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
        sub {
            my $c = $src;
            ($c, my $ret) = primary($c)
                or return;
            return ($c, $ret);
        },
    );
}

sub match {
    my ($c, $word) = @_;
    die "[BUG]" unless @_ == 2;
    confess unless defined $c;
    $word = quotemeta($word);
    $c =~ s/^\s*//;
    $c =~ s/^$word//
        or return ();
    return ($c);
}

sub parameters {
    my $src = skip_ws(shift);

    ($src) = match($src, "(")
        or return;
    confess unless defined $src;

    ($src, my $ret) = parameter_list($src);
    confess unless defined $src;

    ($src) = match($src, ")")
        or die "Parse failed: missing ')'";

    return ($src, $ret);
}

sub parameter_list {
    my $src = skip_ws(shift);
    confess unless defined $src;

    my $ret = [];

    while (1) {
        (my $src2, my $var) = variable($src)
            or return ($src, $ret);
        $src = $src2;
        push @$ret, $var;

        ($src) = (match($src, ',')
            or return ($src, $ret));
    }
}

sub arguments {
    my $src = skip_ws(shift);

    ($src) = match($src, "(") or return;
    confess unless defined $src;

    ($src, my $ret) = argument_list($src);
    confess unless defined $src;

    ($src) = match($src, ")")
        or die "Parse failed: missing ')' line $LINENO";

    return ($src, $ret);
}

sub argument_list {
    my $src = skip_ws(shift);

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

sub identifier {
    local $_ = shift;
    s/^\s*//;
    s/^([A-Za-z_][A-Za-z0-9_]*)// or return;
    return ($_, _node('IDENT', $1));
}

sub variable {
    my $src = skip_ws(shift);
    confess unless defined $src;
    $src =~ s!^(\$[A-Za-z_]+)!!
        or return;
    return ($src, _node('VARIABLE', $1));
}

sub primary {
    my $src = skip_ws(shift);

    any(
        sub {
            # int
            my $c = $src;
            $c =~ s/^([1-9][0-9]*)//
                or return;
            return ($c, _node('INT', $1));
        },
        sub {
            # NV
            my $c = $src;
            $c =~ s/^([1-9][0-9]*\.[0-9]*)// or return;
            return ($c, _node('DOUBLE', $1));
        },
        sub {
            my $c = $src;
            ($c, my $ret) = string($c)
                or return;
            return ($c, _node('STR', $ret));
        },
        sub {
            my $c = $src;
            ($c, my $ret) = _qw_literal($c)
                or return;
            ($c, $ret);
        },
        sub {
            my $c = $src;
            ($c, my $ret) = identifier($c)
                or return;
            ($c, $ret);
        },
        sub {
            my $c = $src;
            ($c, my $ret) = variable($c)
                or return;
            ($c, $ret);
        },
        sub {
            my $c = $src;
            $c =~ s/^__LINE__//
                or return;
            return ($c, _node('INT', $LINENO));
        },
        sub {
            my $c = $src;
            ($c) = match($c, "[")
                or return;
            ($c, my $body) = expression_list($c);
            ($c) = match($c, "]")
                or return;
            return ($c, _node2('ARRAY', $START, $body));
        },
    );
}

sub _qw_literal {
    my $src = skip_ws(shift);

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

sub string {
    # escape chars, etc.
    my $src = skip_ws(shift);

    $src =~ s/^"([^"]+?)"// or return;
    return ($src, $1);
}

1;
__END__

=head1 SYNOPSIS

    use Nana::Parser;

    my $parser = Nana::Parser->new();
    my $ast = $parser->parse();


package Tora::Parser;
use strict;
use warnings;
use utf8;
use Carp;

sub new { bless {}, shift }

sub parse {
    my ($class, $src) = @_;
    my ($rest, $ret) = expression($src);
    if ($rest) {
        die "Parse failed: $rest";
    }
    $ret;
}

sub expression {
    my $src = $_[0];
    $src =~ s/^\s*//;

    {
        my @ret = sub {
            my $c = $src;
            ($c)           = match($c, 'sub') or return;
            ($c, my $name) = identifier($c)   or die "Parsing error";

            my $params;
            if ((my $c2, $params) = parameters($c, "(")) {
                # optional
                $c = $c2;
            }

            ($c)           = match($c, '{')   or die "Parsing error";
            ($c, my $body) = expression($c)   or return;
            ($c)           = match($c, '}')   or return;
            return ($c, ['SUB', $name, $params, $body]);
        }->();
        return @ret if @ret;
    }
n3:
    {
        my $c = $src;
        ($c, my $lhs) = term($c) or goto n1;
        ($c) = match($c, '+') or goto n1;
        ($c, my $rhs) = expression($c) or goto n1;
        return ($c, ['+', $lhs, $rhs]);
    }
n1:
    {
        my $c = $src;
        ($c, my $lhs) = term($c) or goto n2;
        ($c) = match($c, '-') or goto n2;
        ($c, my $rhs) = expression($c) or goto n2;
        return ($c, ['-', $lhs, $rhs]);
    }
n2:
    {
        my $c = $src;
        ($c, my $ret) = term($c) or goto err;
        return ($c, $ret);
    }
err:

    die "Parse Error";
}

sub term {
    my $src = shift;
    {
        my $c = $src;
        ($c, my $lhs) = primary($c) or goto n1;
        ($c) = match($c, '*') or goto n1;
        ($c, my $rhs) = term($c) or goto n1;
        return ($c, ['*', $lhs, $rhs]);
    }
n1:
    {
        my $c = $src;
        ($c, my $lhs) = primary($c) or goto n2;
        ($c) = match($c, '/') or goto n2;
        ($c, my $rhs) = term($c) or goto n2;
        return ($c, ['/', $lhs, $rhs]);
    }
n2:
    {
        my $c = $src;
        ($c, my $ret) = primary($c) or goto err;
        return ($c, $ret);
    }
err:
    die "Parse failed";
}

sub match {
    my ($c, $word) = @_;
    confess unless defined $c;
    $word = quotemeta($word);
    $c =~ s/^\s*//;
    $c =~ s/^$word//
        or return ();
    return ($c);
}

sub parameters {
    my $src = shift;
    my $ret = [];
    ($src) = match($src, "(") or return;
start:
    if ((my $src2) = match($src, ")")) {
        return ($src2, $ret);
    }
    ($src, my $var) = variable($src)
        or die "Parse failed in parameters";
    push @$ret, $var;

    if ((my $src2) = match($src, ",")) {
        $src = $src2;
        goto start;
    }
    if ((my $src2) = match($src, ")")) {
        return ($src2, $ret);
    }
    die "Parse failed";
}

sub identifier {
    local $_ = shift;
    s/^\s*//;
    s/^([A-Za-z_][A-Za-z0-9_]*)// or return;
    ($_, ['IDENT', $1]);
}

sub variable {
    my $src = shift;
    confess unless defined $src;
    $src =~ s/^\s*//;
    $src =~ s!^(\$[A-Za-z_]+)!!;
    return ($src, ['VARIABLE', $1]);
}

sub primary {
    my $src = shift;
    $src =~ s/^\s*//;

    my @a = sub {
        # int
        my $c = $src;
        $c =~ s/^([1-9][0-9]*)// or return;
        ($c, ['INT', $1]);
    }->();
    return @a if @a;

    my @c = sub {
        # NV
        my $c = $src;
        $c =~ s/^([1-9][0-9]*\.[0-9]*)// or return;
        ($c, ['DOUBLE', $1]);
    }->();
    return @c if @c;

    my @b = sub {
        my $c = $src;
        ($c, my $ret) = string($c) or return;
        ($c, ['STR', $ret]);
    }->();
    return @b if @b;

    die "Parse failed. : $src";
}

sub string {
    # escape chars, etc.
    my $src = shift;
    $src =~ s/^"([^"]+?)"// or return;
    return ($src, $1);
}

sub space {
    s/^\s*//;
    1;
}

1;
__END__

=head1 SYNOPSIS

    use Tora::Parser;

    my $parser = Tora::Parser->new();
    my $ast = $parser->parse();


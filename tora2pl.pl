#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use 5.010000;
use autodie;
use warnings FATAL => 'recursion';


=pod

code = expr
expr = term
     / expression "+" term
term = primary
     / term "*" primary
primary = /[1-9][0-9]*/

=cut

use Test::More;

my $src = "11*3+2/2";
use Data::Dumper;

say Dumper(parse($src));
exit;

sub parse {
    my $src = shift;
    my ($rest, $ret) = expression($src);
    if ($rest) {
        die "Parse failed: $rest";
    }
    $ret;
}

sub expression {
    my $src = $_[0];
    {
        my $c = $src;
        ($c, my $lhs) = term($c) or goto n1;
        ($c) = match($c, '+') or goto n1;
        ($c, my $rhs) = expression($c) or goto n1;
        return ($c, [$lhs, '+', $rhs]);
    }
n1:
    {
        my $c = $src;
        ($c, my $lhs) = term($c) or goto n2;
        ($c) = match($c, '-') or goto n2;
        ($c, my $rhs) = expression($c) or goto n2;
        return ($c, [$lhs, '-', $rhs]);
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
        return ($c, [$lhs, '*', $rhs]);
    }
n1:
    {
        my $c = $src;
        ($c, my $lhs) = primary($c) or goto n2;
        ($c) = match($c, '/') or goto n2;
        ($c, my $rhs) = term($c) or goto n2;
        return ($c, [$lhs, '/', $rhs]);
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
    $word = quotemeta($word);
    $c =~ s/^\s*//;
    $c =~ s/^$word//
        or return ();
        warn "O";
    return ($c);
}

sub primary {
    local $_ = shift;
    s/^([1-9][0-9]*)//;
    ($_, $1);
}

sub space {
    s/^\s*//;
    1;
}

__END__

package Tokens;

use parent qw(Exporter);

BEGIN {
require constant;
my @vars = qw(
    TOKEN_IDENTIFIER
    TOKEN_STRING
    TOKEN_VARIABLE
    TOKEN_LPAREN
    TOKEN_RPAREN
    TOKEN_INTEGER
);
constant->import(@vars);
our @EXPORT = @vars;
}

package Scanner;
BEGIN {
    Tokens->import();
}

sub take {
    my ($class, $src) = @_;

start:
    if ($src =~ s/^([A-Za-z0-9]+)//) {
        return [TOKEN_IDENTIFIER, $1];
    } elsif ($src =~ s/^(\$[A-Za-z][A-za-z0-9]*)//) {
        return [TOKEN_VARIABLE, $1];
    } elsif ($src =~ s/^([1-9][0-9]*)//) {
        return [TOKEN_INTEGER, $1];
    } elsif ($src =~ s/^\(//) {
        return [TOKEN_LPAREN];
    } elsif ($src =~ s/^\)//) {
        return [TOKEN_RPAREN];
    } elsif ($src =~ s/^\s*//) {
        goto start;
    } else {
        $src =~ s/^(.)//;
        die "Unknown token: $1";
    }
}

package Parser;

sub match {
    my ($tokens, $pattern) = @_;
}

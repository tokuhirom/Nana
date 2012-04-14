package Nana::Compiler;
use strict;
use warnings;
use utf8;
use Data::Dumper;

sub new {
    my $self = shift;
}

sub compile {
    my ($self, $ast, $no_header) = @_;

    my $res = '';
    unless ($no_header) {
        $res .= 'use 5.12.0;use strict;use warnings;use warnings FATAL => "recursion";use utf8;use autobox;my $ENV=\%ENV;use File::stat;' . "\n";
    }
    $res .= _compile($ast);
}

sub _compile {
    my ($node) = @_;

    if ($node->[0] eq '+') {
        return _compile($node->[2]) . '+' . _compile($node->[3]);
    } elsif ($node->[0] eq '-') {
        return _compile($node->[2]) . '-' . _compile($node->[3]);
    } elsif ($node->[0] eq '*') {
        return _compile($node->[2]) . '*' . _compile($node->[3]);
    } elsif ($node->[0] eq '/') {
        return _compile($node->[2]) . '/' . _compile($node->[3]);
    } elsif ($node->[0] eq '~') {
        # string concat operator
        return _compile($node->[2]) . '.' . _compile($node->[3]);
    } elsif ($node->[0] eq 'SUB') {
        my $ret = sprintf("#line %d\n", $node->[1]);
        $ret .= 'sub ' . _compile($node->[2]);
        $ret .= ' { ';
        if ($node->[3]) {
            for (@{$node->[3]}) {
                $ret .= "my ";
                $ret .= _compile($_);
                $ret .= "=shift;";
            }
        }
        $ret .= _compile($node->[4]) . ' }';
        return $ret;
    } elsif ($node->[0] eq 'CALL') {
        if ($node->[2]->[0] eq 'IDENT') {
            my $ret = '' . $node->[2]->[2] . '(';
            $ret .= join(',', map { sprintf('scalar(%s)', _compile($_)) } @{$node->[3]});
            $ret .= ')';
            return $ret;
        } else {
            die "Compilation failed.";
        }
    } elsif ($node->[0] eq 'IDENT') {
        return $node->[2];
    } elsif ($node->[0] eq 'NOP') {
        return '';
    } elsif ($node->[0] eq 'STR') {
        return '"' . $node->[2] . '"';
    } elsif ($node->[0] eq 'INT') {
        return $node->[2];
    } elsif ($node->[0] eq 'RETURN') {
        return 'return (' . _compile($node->[2]) . ');';
    } elsif ($node->[0] eq 'IF') {
        my $ret = 'if (' . _compile($node->[2]) . ') {' . _compile($node->[3]) . '}';
        if ($node->[4]) {
            $ret .= _compile($node->[4]);
        }
        return $ret;
    } elsif ($node->[0] eq 'WHILE') {
        return 'while (' . _compile($node->[2]) . ') {' . _compile($node->[3]) . '}';
    } elsif ($node->[0] eq 'ELSIF') {
        my $ret = ' elsif ('. _compile($node->[2]) . ') {' . _compile($node->[3]) . '}';
        if ($node->[4]) {
            $ret .= _compile($node->[4]);
        }
        return $ret;
    } elsif ($node->[0] eq 'ELSE') {
        return ' else {' . _compile($node->[2]) . '}';
    } elsif ($node->[0] eq 'CLASS') {
        my $ret = '{package ' . _compile($node->[2]) . ';';
        $ret .= _compile($node->[3]);
        $ret .= "}";
        return $ret;
    } elsif ($node->[0] eq 'STMTS') {
        my $ret = '';
        for (@{$node->[2]}) {
            $ret .= _compile($_);
        }
        return $ret;
    } elsif ($node->[0] eq 'DOUBLE') {
        return $node->[2];
    } elsif ($node->[0] eq 'VARIABLE') {
        return $node->[2];
    } else {
        die "Unknown node type " . Dumper($node);
    }
}

1;
__END__

=head1 SYNOPSIS

    use Nana::Compiler;

    my $compiler = Nana::Compiler->new();
    my $perl = $compiler->compile($ast);
    eval $perl;


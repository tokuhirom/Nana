package Tora::Compiler;
use strict;
use warnings;
use utf8;
use Data::Dumper;

sub new {
    my $self = shift;
}

sub compile {
    my ($self, $ast) = @_;

    _compile($ast);
}

sub _compile {
    my ($node) = @_;

    if ($node->[0] eq '+') {
        return _compile($node->[1]) . '+' . _compile($node->[2]);
    } elsif ($node->[0] eq '-') {
        return _compile($node->[1]) . '-' . _compile($node->[2]);
    } elsif ($node->[0] eq '*') {
        return _compile($node->[1]) . '*' . _compile($node->[2]);
    } elsif ($node->[0] eq '/') {
        return _compile($node->[1]) . '/' . _compile($node->[2]);
    } elsif ($node->[0] eq '~') {
        # string concat operator
        return _compile($node->[1]) . '.' . _compile($node->[2]);
    } elsif ($node->[0] eq 'SUB') {
        my $ret = 'sub ' . _compile($node->[1]);
        $ret .= ' { ';
        if ($node->[2]) {
            for (@{$node->[2]}) {
                $ret .= "my ";
                $ret .= _compile($_);
                $ret .= "=shift;";
            }
        }
        $ret .= _compile($node->[3]) . ' }';
    } elsif ($node->[0] eq 'IDENT') {
        return $node->[1];
    } elsif ($node->[0] eq 'INT') {
        return $node->[1];
    } elsif ($node->[0] eq 'DOUBLE') {
        return $node->[1];
    } elsif ($node->[0] eq 'VARIABLE') {
        return $node->[1];
    } else {
        die "Unknown node type " . Dumper($node);
    }
}

1;
__END__

=head1 SYNOPSIS

    use Tora::Compiler;

    my $compiler = Tora::Compiler->new();
    my $perl = $compiler->compile($ast);
    eval $perl;


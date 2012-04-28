package Nana::Translator::Perl::PerlPackage;
use strict;
use warnings;
use utf8;
use Carp;
use Scalar::Util qw(blessed);

sub new {
    my ($class, $pkg) = @_;
    bless { pkg => $pkg }, $class;
}

sub __wrap {
    my @stuff = map {
        blessed $_ ? Nana::Translator::Perl::PerlObject->new($_) : $_
    } @_;
    wantarray ? $stuff[0] : (@stuff==1 ? $stuff[0] : [@stuff]);
}

sub get {
    my ($self, $method_name) = @_;
    if ($method_name eq 'CALL') {
        return sub {
            my $funcname = shift;
            my $code = $self->{pkg}->can($funcname);
            unless ($code) {
                croak "Unknown method $funcname for Perl package $self->{pkg}";
            }
            __wrap($code->(@_));
        };
    }
    my $code = $self->{pkg}->can($method_name);
    if ($code) {
        return sub {
            __wrap($code->($self->{pkg}, @_));
        };
    } else {
        return undef;
    }
}

package Nana::Translator::Perl::PerlObject;

sub new {
    my ($class, $object) = @_;
    bless { object => $object }, $class;
}

sub get {
    my ($self, $method_name) = @_;

    my $code = $self->{object}->can($method_name);
    if ($code) {
        return sub {
            Nana::Translator::Perl::PerlPackage::__wrap($code->($self->{object}, @_));
        };
    } else {
        return undef;
    }
}

1;


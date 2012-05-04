package Nana::Translator::Perl::PerlPackage;
use strict;
use warnings;
use utf8;
use Carp;
use Scalar::Util qw(blessed);
use B;

sub new {
    my ($class, $pkg) = @_;
    bless { pkg => $pkg }, $class;
}

sub __wrap {
    my @stuff = map { __wrap_inner($_) } @_;
    wantarray ? $stuff[0] : (@stuff==1 ? $stuff[0] : [@stuff]);
}

sub __wrap_inner {
    my $stuff = shift;
    if (blessed $stuff) {
        Nana::Translator::Perl::PerlObject->new($stuff);
    } elsif (my $type = ref $stuff) {
        if ($type eq 'ARRAY') {
            +[map { __wrap_inner($_) } @$stuff];
        } elsif ($type eq 'HASH') {
            +{map { $_ => __wrap_inner($stuff->{$_}) } keys %$stuff};
        } else {
            $stuff
        }
    } else {
        my $flags = B::svref_2object(\$stuff)->FLAGS;
        if ($flags & (B::SVp_IOK | B::SVp_NOK) and !( $flags & B::SVp_POK )) {
            $stuff
        } elsif (utf8::is_utf8($stuff)) {
            $stuff
        } else {
            Nana::Translator::Perl::Runtime::tora_bytes($stuff);
        }
    }
}

sub __tora2perl_wrap_inner {
    my $stuff = shift;
    if (ref $stuff eq 'HASH') {
        return +{
            map { $_ => __tora2perl_wrap_inner($stuff->{$_}) }
                keys %$stuff
        }
    } elsif (ref $stuff eq 'ARRAY') {
        return +[
            map { __tora2perl_wrap_inner($_) }
                @$stuff
        ];
    } elsif (ref $stuff eq 'Nana::Translator::Perl::Bytes') {
        return $stuff->data;
    } elsif (ref $stuff eq 'CODE') {
        sub {
            $stuff->(map {
                blessed $_
                    ? Nana::Translator::Perl::PerlObject->new($_)
                    : $_
            } @_);
        };
    } else {
        return $stuff;
    }
}

sub __tora2perl_wrap { map { __tora2perl_wrap_inner($_) } @_ }

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


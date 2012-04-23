package Nana::Translator::Perl::Object;
use strict;
use warnings;
use utf8;
use Devel::GlobalDestruction qw(in_global_destruction);

sub new {
    my ($class, $klass, $data) = @_;
    my $self = bless {klass => $klass, data => $data}, $class;
    $self;
}

sub data {
    my $self = shift;
    return $self->{data};
}

sub get_method {
    my ($self, $name) = @_;
    return $self->{klass}->get_method($name);
}

sub has_method {
    my ($self, $name) = @_;
    return $self->{klass}->get_method($name)
        ? JSON::true()
        : JSON::false();
}

sub class {
    my ($self) = @_;
    return $self->{klass};
}

sub DESTROY {
    my $self = shift;
    # my ($pkg, $klass, $methname, @args) = @_;
    if (in_global_destruction() && !$self->{klass}) {
        # this warning is very often...
        # print STDERR "  (in cleanup) Class object was destructed before object.\n";
        return;
    }
    if ($self->has_method('DESTROY')) {
        Nana::Translator::Perl::Runtime::tora_call_method(+{}, $self, 'DESTROY');
    }
}

1;


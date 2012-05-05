package Tlack::Runner;
use strict;
use warnings;
use utf8;
use parent qw(Plack::Runner);
use Nana::Parser;
use Nana::Translator::Perl;
use Plack::Builder;

# delay the build process for reloader
sub build(&;$) {
    my $block = shift;
    my $app   = shift || sub { };
    return sub { $block->($app->()) };
}

my $parser = Nana::Parser->new();
my $translator = Nana::Translator::Perl->new();
sub locate_app {
    my($self, @args) = @_;

    my $psgi = $self->{app} || $args[0];

    if (ref $psgi eq 'CODE') {
        return sub { $psgi };
    }

    if ($self->{eval}) {
        $self->loader->watch("lib");
        return build {
            no strict;
            no warnings;
            my $eval = "builder { ";
            $eval .= $translator->compile($parser->parse($self->{eval}));
            $eval .= "load_tsgi(\$psgi);" if $psgi;
            $eval .= "}";
            eval $eval or die $@;
        };
    }

    $psgi ||= "app.tsgi";

    require File::Basename;
    $self->loader->watch( File::Basename::dirname($psgi) . "/lib", $psgi );
    build { load_tsgi($psgi) };
}

sub load_tsgi {
    my $tsgi = shift;
    open my $fh, '<', $tsgi
        or die "Cannot open $tsgi: $!";
    my $src = do { local $/; <$fh> };
    my $eval = join('',
        'builder {',
            $translator->compile($parser->parse($src)),
        '}',
    );
    eval $eval or die $@;
}

1;

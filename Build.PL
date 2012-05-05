use strict;
use warnings FATAL => 'all';
use Module::Build;
use lib 'util/';

my $class = Module::Build->subclass(
    class => 'My::Builder',
    code => <<'...'
        sub ACTION_test {
            my $self = shift;
            $self->depends_on('code');
            exec($^X . q{ util/myprove --source T --source TRA --source EGTRA --source TCC -r t/ t/*/*/*.tcc t/*/*/*.egtra t/tra/*.tra t/tra/*/*.tra});
        }
        sub ACTION_code {
            my $self = shift;
            require Devel::PPPort;
            Devel::PPPort::WriteFile('ppport.h');
            $self->SUPER::process_PL_files();
            unless(
                   $self->up_to_date('lib/Nana/toke.re.PL' => 'lib/Nana/toke.c')
                && $self->up_to_date('lib/Nana/toke.re' => 'lib/Nana/toke.c')
            ) {
                $self->run_perl_script('lib/Nana/toke.re.PL', [], ['lib/Nana/toke.c']) or die "lib/Nana/toke.re.PL failed";
                $self->add_to_cleanup('lib/Nana/toke.c');
                $self->add_to_cleanup('lib/Nana/toke.o');
                unlink 'lib/Nana/Parser.c';
                unlink 'lib/Nana/Parser.o';
            }
            unless ($self->up_to_date('xs/operator.c.PL' => 'xs/operator.c')) {
                $self->run_perl_script('xs/operator.c.PL', [], ['xs/operator.c']) or die "xs/operator.c.PL failed";
                $self->add_to_cleanup('xs/operator.c');
                unlink 'lib/Nana/Parser.c';
                unlink 'lib/Nana/Parser.o';
            }
            $self->SUPER::ACTION_code(@_);
        }
...
);

my $build = $class->new(
    license              => 'perl',
    recursive_test_files => 1,
    dynamic_config       => 0,
    build_requires       => {
        'Test::More' => '0.98',
        'Capture::Tiny' => 0,
        'TAP::Harness' => '3.23',
        'Test::Base' => 0,
        'Test::Differences' => 0,
        'ExtUtils::CBuilder' => 0,
        'Text::MicroTemplate' => 0,
        'Devel::PPPort'       => 0,
    },
    configure_requires   => { 'Module::Build' => '0.38' },
    requires             => {
        'perl'               => '5.012000',
        'parent' => 0,
        'Sub::Name' => '0',
        'Scalar::Util' => '0',
        'File::stat' => '0',
        'Exporter'           => '5.58',
        'Getopt::Long::Descriptive' => 0,
        'File::ShareDir' => '1.03',
        'Devel::GlobalDestruction' => '0.04',
        'JSON::XS' => 2,
        'Plack' => 0,
    },
    no_index    => { 'directory' => [ 'inc', 't', 'xt' ] },
    name        => 'nana',
    dist_name   => 'nana',
    module_name => 'Nana::Parser',
    share_dir => {
        dist => [ 'share' ],
    },
    PL_files => {
        'Config.tra.PL' => 'share/lib/Config.tra',
        'lib/Nana/Token.pm.PL' => ['lib/Nana/Token.pm', 'lib/Nana/token.h'],
        'lib/Nana/Node.pm.PL' => ['lib/Nana/Node.pm'],
    },
    xs_files => +{
        'lib/Nana/Parser.xs' => 'lib/Nana/Parser.xs',
    },
    use_tap_harness => 1,
    test_files => [glob('t/*.t t/*/*/*.tcc t/*/*/*.egtra t/tra/*.tra t/tra/*/*.tra')],
    tap_harness_args => {
        sources => {
            'EGTRA' => [],
            'TCC' => [],
            'TRA' => [],
        },
    },
    script_files => 'bin/nana',
    extra_compiler_flags => (($^O eq 'linux' && -d '.git') ? ['-std=c90', '-Wall'] : []),

    test_files => ( -d '.git' || $ENV{RELEASE_TESTING} ) ? 't/ xt/' : 't/',

    create_readme  => 1,
    create_license => 1,
);
$build->create_build_script();

use strict;
use warnings FATAL => 'all';
use Module::Build;

my $build = Module::Build->new(
    license              => 'perl',
    recursive_test_files => 1,
    dynamic_config       => 0,
    build_requires       => {
        'Test::More' => '0.98',
        'Capture::Tiny' => 0,
        'TAP::Harness' => '3.23',
        'Test::Base' => 0,
        'Test::Differences' => 0,
    },
    configure_requires   => { 'Module::Build' => '0.38' },
    requires             => {
        'perl'               => '5.008001',
        'Module::Compile' => '0',
        'Sub::Name' => '0',
        'Scalar::Util' => '0',
        'File::stat' => '0',
        'Exporter'           => '5.58',
        'Getopt::Long::Descriptive' => 0,
        'File::ShareDir' => '1.03',
        'Devel::GlobalDestruction' => '0.04',
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
    },

    test_files => ( -d '.git' || $ENV{RELEASE_TESTING} ) ? 't/ xt/' : 't/',

    create_readme  => 1,
    create_license => 1,
);
$build->create_build_script();

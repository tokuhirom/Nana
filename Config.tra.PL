my $output_file = shift;
open my $fh, ">", $output_file or die "Can't open $output_file: $!";
use Config;

my $src = <<'END';
my $config = {
    TORA_OS => '[% $^O %]',
    TORA_CC => '[% $Config{cc} %]',
};
sub tora_config { $config }
END
$src =~ s/\[\%([^%]+)\%\]/$1/gee;
print $fh $src;


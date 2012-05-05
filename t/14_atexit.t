use strict;
use warnings;
use utf8;
use Test::More;
use IPC::Open3;

my ($wtr, $rdr, $err);
my $pid = open3($wtr, $rdr, $err, $^X, '-Mblib', 'bin/nana', '-e', <<'...');
atexit(-> {
    say("A")
})
atexit(-> {
    say("B")
})
say("o")
...
waitpid($pid, 0);

is(do { local $/; <$rdr> }, <<',,,');
o
A
B
,,,

done_testing;


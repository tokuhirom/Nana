use strict;
use warnings;
use Test::More;

use t::Util;

test_nana(
    <<'...', <<',,,', <<'!!!'
use Test::More *;
ok(undef);
done_testing();
...
not ok 1
1..1
,,,
#   Failed test at <eval> line 2.
# Looks like you failed 1 test of 1.
!!!
);

done_testing;

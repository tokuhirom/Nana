===
--- code
my ($x, $v); say($x); say($v);
--- stdout
undef
undef

===
--- code
(my $x, my $v); say($x); say($v);
--- stdout
undef
undef

===
--- code
my ($x, $v) = (4, 9); say($x); say($v);
--- stdout
4
9


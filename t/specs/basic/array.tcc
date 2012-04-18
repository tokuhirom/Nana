===
--- code
my ($a, $b, $c) = *[1,2,3];
say($a);
say($b);
say($c);
--- stdout
1
2
3
--- stderr

===
--- code
my $a = [1,2,3];
say($a[1]);
--- stdout
2

===
--- code
my $x = [1,2,3];
$x[1] = 4;
say(*$x);
--- stdout
1
4
3

===
--- code
my $x = [1,2,3];
say($x.size());
--- stdout
3

===
--- code
say("ho" + "ge");
--- stdout
hoge
--- stderr

===
--- code
say("ho" + 3);
--- stdout
ho3
--- stderr

===
--- code
say("3" + 4);
--- stdout
34
--- stderr

===
--- code
say(3 + '4');
--- stdout
7
--- stderr

===
--- code
my $i=0;
say($i++);
say($i++);
--- stdout
0
1
--- stderr

===
--- code
my $i=3;
say($i--);
say($i--);
say($i);
--- stdout
3
2
1
--- stderr

===
--- code
my $i=3;
say(++$i);
say(++$i);
say($i);
--- stdout
4
5
5
--- stderr

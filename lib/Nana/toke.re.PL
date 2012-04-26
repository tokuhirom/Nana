print("Running re2c\n");
system("re2c -o lib/Nana/toke.c lib/Nana/toke.re") == 0
    or die $!;

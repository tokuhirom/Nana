my @tokens = qw(
    TOKEN_PLUSPLUS
    TOKEN_MINUSMINUS
    TOKEN_PLUS
    TOKEN_MINUS
    TOKEN_MULMUL
    TOKEN_MUL
    TOKEN_LSHIFT
    TOKEN_RSHIFT
    TOKEN_LSHIFT_ASSIGN
    TOKEN_LT
    TOKEN_RSHIFT_ASSIGN
    TOKEN_GT
);

&output_header; &output_pm; exit 0;

# ---------------------------------------------------------------

sub output_pm {
open my $ofh, '>', 'lib/Nana/Token.pm';
print $ofh <<'...';
package Nana::Token;
use strict;
use warnings;
use parent qw(Exporter);

use constant {
    TOKEN_EOF => 0,
...
my $i=1;
for (@tokens) {
    print $ofh "    $_ => @{[ $i++ ]},\n";
}
print $ofh <<'...';
};

...
print $ofh sprintf(q{our @EXPORT=qw(TOKEN_EOF %s);%s}, join(' ', @tokens), qq{\n});
print $ofh <<'...';

1;
...
}

# ---------------------------------------------------------------
sub output_header {
open my $ofh, '>', 'lib/Nana/token.h';
print $ofh <<'...';
#pragma once
#define TOKEN_EOF 0
...
my $i=1;
for (@tokens) {
    print $ofh "#define $_ @{[ $i++ ]}\n";
}
}

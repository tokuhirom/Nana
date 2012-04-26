my %seen;
my @tokens = grep { !$seen{$_}++ } qw(
    TOKEN_CMP
    TOKEN_GE
    TOKEN_LE
    TOKEN_GT
    TOKEN_LT
    TOKEN_PLUSPLUS
    TOKEN_MINUSMINUS
    TOKEN_PLUS
    TOKEN_MINUS
    TOKEN_POW
    TOKEN_MUL
    TOKEN_MUL_ASSIGN
    TOKEN_LSHIFT
    TOKEN_RSHIFT
    TOKEN_LSHIFT_ASSIGN
    TOKEN_LT
    TOKEN_RSHIFT_ASSIGN
    TOKEN_GT
    TOKEN_AND
    TOKEN_ANDAND
    TOKEN_AND_ASSIGN
    TOKEN_OR
    TOKEN_OR_ASSIGN
    TOKEN_OROR
    TOKEN_OROR_ASSIGN
    TOKEN_DOT
    TOKEN_DOTDOT
    TOKEN_DOTDOTDOT
    TOKEN_XOR
    TOKEN_XOR_ASSIGN
    TOKEN_FILETEST
    TOKEN_LAMBDA
    TOKEN_PLUS_ASSIGN
    TOKEN_MINUS_ASSIGN
    TOKEN_REGEXP_MATCH
    TOKEN_REGEXP_NOT_MATCH
    TOKEN_EQUAL_EQUAL
    TOKEN_NOT_EQUAL
    TOKEN_ASSIGN
    TOKEN_FAT_COMMA
    TOKEN_NOT
    TOKEN_COMMA
    TOKEN_DIV
    TOKEN_MOD
    TOKEN_MOD_ASSIGN
    TOKEN_ASSIGN
    TOKEN_POW_ASSIGN
    TOKEN_DIV_ASSIGN
    TOKEN_DEREF
    TOKEN_REF
    TOKEN_TILDE
    TOKEN_LBRACKET
    TOKEN_STRING_QQ_START
    TOKEN_STRING_Q_START
    TOKEN_STRING_DQ
    TOKEN_STRING_SQ
    TOKEN_REGEXP_QR_START
    TOKEN_HEREDOC_SQ_START
    TOKEN_BYTES_SQ
    TOKEN_BYTES_DQ
    TOKEN_LPAREN
    TOKEN_LBRACE
    TOKEN_QW_START
    TOKEN_CLASS
    TOKEN_IDENT
    TOKEN_USE
    TOKEN_RETURN
    TOKEN_UNLESS
    TOKEN_IF
    TOKEN_WHILE
    TOKEN_FOR
    TOKEN_DO
    TOKEN_ELSIF
    TOKEN_ELSE
    TOKEN_LAST
    TOKEN_NEXT
    TOKEN_SUB
    TOKEN_TRY
    TOKEN_DIE
    TOKEN_STR_NOT
    TOKEN_QUESTION
    TOKEN_INTEGER
    TOKEN_DOUBLE
    TOKEN_MY
    TOKEN_LINE
    TOKEN_UNDEF
    TOKEN_TRUE
    TOKEN_FALSE
    TOKEN_SELF
    TOKEN_FILE
    TOKEN_STR_OR
    TOKEN_STR_XOR
    TOKEN_STR_AND
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

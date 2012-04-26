/* vim: set filetype=cpp: */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "../../ppport.h"

#include <stdio.h>
#include <stdlib.h>
#include "token.h"

/**
 * Take a token from string.
 *
 * @args src: source string.
 * @args len: length for 'src'.
 * @args output *used: used chars in src
 * @args output *found_end: make true if found __END__
 * @args output *lineno_inc: incremented line numbers.
 * @args output *yylval: value itself in string
 * @return int token id.
 */
int token_op(char *src, size_t len, int *used, int *found_end, int *lineno_inc, SV**yylval) {
#define OP(type) do { *used+=(cursor-orig); return type; } while (0)
    *used = skip_ws(src, len, found_end, lineno_inc);
    if (*found_end) {
        return TOKEN_EOF;
    }
    if (*used == len) {
        return TOKEN_EOF;
    }
    char *cursor = src+*used;
    char *orig = cursor;
    char *marker = cursor;

    /*!re2c
        re2c:define:YYCTYPE  = "char";
        re2c:define:YYCURSOR = cursor;
        re2c:define:YYMARKER = marker;
        re2c:yyfill:enable   = 0;
        re2c:yych:conversion = 1;
        re2c:indent:top      = 1;

        OPENCHAR = [!'\{\["\(];
        IDENT = [a-zA-Z_] [a-zA-Z0-9_]*;
        ANY_CHAR = [^];
        HEX = "0x" [0-9a-fA-F]+;
        INTEGER = HEX;
        DOUBLE = ([1-9] [0-9]* | "0") "." [0-9]+;
        CLASS_NAME = IDENT ( "::" IDENT )*;

        */

    /*!re2c
        "class" { OP(TOKEN_CLASS);  }
        "return" { OP(TOKEN_RETURN); }
        "use" { OP(TOKEN_USE); }
        "unless" { OP(TOKEN_UNLESS); }
        "if" { OP(TOKEN_IF); }
        "do" { OP(TOKEN_DO); }
        "sub" { OP(TOKEN_SUB); }
        "not" { OP(TOKEN_STR_NOT); }
        "die" { OP(TOKEN_DIE); }
        "try" { OP(TOKEN_TRY); }
        "or" { OP(TOKEN_STR_OR); }
        "xor" { OP(TOKEN_STR_XOR); }
        "and" { OP(TOKEN_STR_AND); }
        "elsif" { OP(TOKEN_ELSIF); }
        "last" { OP(TOKEN_LAST); }
        "next" { OP(TOKEN_NEXT); }
        "else" { OP(TOKEN_ELSE); }
        "while" { OP(TOKEN_WHILE); }
        "for" { OP(TOKEN_FOR); }
        "my" { OP(TOKEN_MY); }
        "undef" { OP(TOKEN_UNDEF); }
        "true" { OP(TOKEN_TRUE); }
        "false" { OP(TOKEN_FALSE); }
        "self" { OP(TOKEN_SELF); }
        "__FILE__" { OP(TOKEN_FILE); }
        "__LINE__" { OP(TOKEN_LINE); }

        "0" {
            *yylval = sv_2mortal(newSViv(0));
            OP(TOKEN_INTEGER);
        }
        [1-9] [0-9]* {
            *yylval = sv_2mortal(newSViv(strtol(orig, &cursor, 10)));
            OP(TOKEN_INTEGER);
        }
        "0x" [0-9a-fA-F]+ {
            *yylval = sv_2mortal(newSViv(strtol(orig+2, &cursor, 16)));
            OP(TOKEN_INTEGER);
        }
        IDENT {
            *yylval = sv_2mortal(newSVpvn(orig, cursor-orig));
            OP(TOKEN_IDENT);
        }
        CLASS_NAME {
            *yylval = sv_2mortal(newSVpvn(orig, cursor-orig));
            OP(TOKEN_CLASS_NAME);
        }
        "$" IDENT {
            *yylval = sv_2mortal(newSVpvn(orig, cursor-orig));
            OP(TOKEN_VARIABLE);
        }
        DOUBLE {
            *yylval = sv_2mortal(newSVnv(strtod(orig, &cursor)));
            OP(TOKEN_DOUBLE);
        }
        "?" { OP(TOKEN_QUESTION); }
        "++" { OP(TOKEN_PLUSPLUS); }
        "+="  { OP(TOKEN_PLUS_ASSIGN);  }
        "+"  { OP(TOKEN_PLUS);  }
        "b\""  { OP(TOKEN_BYTES_DQ);  }
        "b\'"  { OP(TOKEN_BYTES_SQ);  }
        "("  { OP(TOKEN_LPAREN);  }
        "<<'"  { OP(TOKEN_HEREDOC_SQ_START);  }
        "/=" { OP(TOKEN_DIV_ASSIGN); }
        "/" { OP(TOKEN_DIV); }
        "%=" { OP(TOKEN_MOD_ASSIGN); }
        "%" { OP(TOKEN_MOD); }
        "," { OP(TOKEN_COMMA); }
        "!=" { OP(TOKEN_NOT_EQUAL); }
        "!~" { OP(TOKEN_REGEXP_NOT_MATCH); }
        "!" { OP(TOKEN_NOT); }
        "==" { OP(TOKEN_EQUAL_EQUAL); }
        "=>" { OP(TOKEN_FAT_COMMA); }
        "=~" { OP(TOKEN_REGEXP_MATCH); }
        "=" { OP(TOKEN_ASSIGN); }
        "^=" { OP(TOKEN_XOR_ASSIGN); }
        "^" { OP(TOKEN_XOR); }
        "..." { OP(TOKEN_DOTDOTDOT); }
        ".." { OP(TOKEN_DOTDOT); }
        "." { OP(TOKEN_DOT); }
        "||=" { OP(TOKEN_OROR_ASSIGN); }
        "||" { OP(TOKEN_OROR); }
        "|=" { OP(TOKEN_OR_ASSIGN); }
        "|" { OP(TOKEN_OR); }
        "&&" { OP(TOKEN_ANDAND); }
        "&=" { OP(TOKEN_AND_ASSIGN); }
        "&" { OP(TOKEN_AND); }
        "<<=" { OP(TOKEN_LSHIFT_ASSIGN); }
        "<<'" { OP(TOKEN_HEREDOC_SQ_START); }
        "<<" { OP(TOKEN_LSHIFT); }
        "<=>" { OP(TOKEN_CMP); }
        "<=" { OP(TOKEN_GE); }
        "<" { OP(TOKEN_GT); }
        ">>=" { OP(TOKEN_RSHIFT_ASSIGN); }
        ">>" { OP(TOKEN_RSHIFT); }
        ">=" { OP(TOKEN_LE); }
        ">" { OP(TOKEN_LT); }
        "\\" { OP(TOKEN_REF); }
        "~" { OP(TOKEN_TILDE); }
        "${" { OP(TOKEN_DEREF); }
        "**=" { OP(TOKEN_POW_ASSIGN); }
        "**" { OP(TOKEN_POW); }
        "*=" { OP(TOKEN_MUL_ASSIGN); }
        "*" { OP(TOKEN_MUL); }
        "++" { OP(TOKEN_PLUSPLUS); }
        "+=" { OP(TOKEN_PLUS_ASSIGN); }
        "+" { OP(TOKEN_PLUS); }
        "{" { OP(TOKEN_LBRACE); }
        "(" { OP(TOKEN_LPAREN); }
        "b\'" { OP(TOKEN_BYTES_SQ); }
        "b\"" { OP(TOKEN_BYTES_DQ); }
        "qq" OPENCHAR { OP(TOKEN_STRING_QQ_START); }
        "qr" OPENCHAR { OP(TOKEN_REGEXP_QR_START); }
        "qw" OPENCHAR { OP(TOKEN_QW_START); }
        "q" OPENCHAR { OP(TOKEN_STRING_Q_START); }
        "\"" { OP(TOKEN_STRING_DQ); }
        "'" { OP(TOKEN_STRING_SQ); }
        "[" { OP(TOKEN_LBRACKET); }
        "-" [a-z] { OP(TOKEN_FILETEST); }
        "--" { OP(TOKEN_MINUSMINUS); }
        "->" { OP(TOKEN_LAMBDA); }
        "-=" { OP(TOKEN_MINUS_ASSIGN); }
        "-" { OP(TOKEN_MINUS); }
        ANY_CHAR { return TOKEN_EOF; }

      */
    abort(); /* should not reach here */
}

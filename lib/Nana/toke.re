/* vim: set filetype=cpp: */
#include<stdio.h>

/**
 * Take a token from string.
 *
 * @args src: source string.
 * @args len: length for 'src'.
 * @args output *used: used chars in src
 * @args output *found_end: make true if found __END__
 * @args output *lineno_inc: incremented line numbers.
 * @return int token id.
 */
int token_op(char *src, size_t len, int *used, int *found_end, int *lineno_inc) {
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
        ANY_CHAR = [^];

        */

    /*!re2c
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

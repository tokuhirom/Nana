#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "../../ppport.h"

enum {
    TOKEN_EOF=-1,
    TOKEN_UNEXPECTED=0,
    TOKEN_PLUSPLUS=1,
    TOKEN_MINUSMINUS=2,
    TOKEN_PLUS=3,
    TOKEN_MINUS=4,
    TOKEN_MULMUL=5,
    TOKEN_MUL=6,
};

int skip_ws(char *src, size_t len, int *found_end, int *lineno_inc) {
    int seen_nl = 0;
    char *end = src+len;
    char *p = src;

    *found_end = 0;

    while (p<end) {
        if (*p==' ' || *p=='\t' || *p == '\f') {
            seen_nl = 0;
            p++;
        } else if (*p=='#') {
            while (p<end) {
                if (*p=='\n') {
                    seen_nl = 1;
                    (*lineno_inc)++;
                    p++;
                    break;
                }
                p++;
            }
        } else if (seen_nl && strnEQ(p, "__END__\n", MIN(end-p, strlen("__END__\n")))) {
            *found_end = 1;
            break;
        } else if (*p == '\n') {
            seen_nl = 1;
            (*lineno_inc)++;
            p++;
        } else {
            break;
        }
    }
    return p-src;
}

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
#define CHAR2(c) (len-*used>=2 && *(src+1) == (c))
#define SIMPLEOP(type,_used) do { *used+=_used; return type; } while (0)
    *used = skip_ws(src, len, found_end, lineno_inc);
    if (*found_end) {
        return TOKEN_EOF;
    }
    if (*used == len) {
        return TOKEN_EOF;
    }

    switch (*src) {
    case '*':
        if (CHAR2('*')) {
            SIMPLEOP(TOKEN_MULMUL, 2);
        } else {
            SIMPLEOP(TOKEN_MUL, 1);
        }
        break;
    case '+':
        if (CHAR2('+')) {
            SIMPLEOP(TOKEN_PLUSPLUS, 2);
        } else {
            SIMPLEOP(TOKEN_PLUS, 1);
        }
        break;
    case '-':
        if (CHAR2('-')) {
            SIMPLEOP(TOKEN_MINUSMINUS, 2);
        } else {
            SIMPLEOP(TOKEN_MINUS, 1);
        }
        break;
    default:
        return TOKEN_UNEXPECTED;
    }
#undef CHAR2
#undef SIMPLEOP
}

MODULE = Nana::Parser       PACKAGE = Nana::Parser

void
skip_ws(SV * src_sv)
    PPCODE:
        /* skip white space, comments. */
        dTARG;
        STRLEN len;
        char *src = SvPV(src_sv, len);
        int found_end=0, lineno_inc=0;
        int used = skip_ws(src, len, &found_end, &lineno_inc);

        if (!SvPOK(src_sv)) {
            croak("[BUG]");
        }

        /* increment lineno */
        SV *lineno_sv = get_sv("Nana::Parser::LINENO", TRUE);
        IV i = SvIV(lineno_sv) + lineno_inc;
        sv_setiv(lineno_sv, i);

        if (found_end) {
            mXPUSHs(&PL_sv_undef);
            mXPUSHs(&PL_sv_yes);
        } else {
            mXPUSHs(newSVpv(src+used, len-used)); /* rest chars */
            mXPUSHs(&PL_sv_no);   /* found __END__? */
        }

void
_token_op(SV *src_sv)
    PPCODE:
        dTARG;
        STRLEN len;
        char *src = SvPV(src_sv, len);
        int used=0, found_end=0, lineno_inc=0;
        int token_id = token_op(src, len, &used, &found_end, &lineno_inc);
        mXPUSHi(used);
        mXPUSHi(token_id);


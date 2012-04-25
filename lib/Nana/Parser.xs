#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "../../ppport.h"

enum {
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
    *lineno_inc = 0;

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

MODULE = Nana::Parser       PACKAGE = Nana::Parser

void
_skip_ws(SV * src_sv)
    PPCODE:
        dTARG;
        STRLEN len;
        char *src = SvPV(src_sv, len);
        int found_end, lineno_inc;
        int used = skip_ws(src, len, &found_end, &lineno_inc);

        mXPUSHi(used); /* used chars */
        mXPUSHi(found_end); /* found __END__ */
        mXPUSHi(lineno_inc); /* lineno */

void
_token_op(SV *src_sv)
    PPCODE:
#define CHAR2(c) (len>=2 && *(src+1) == (c))
#define SIMPLEOP(s,m) do { mXPUSHi(m); mXPUSHi(s); } while (0)
        dTARG;
        STRLEN len;
        char *src = SvPV(src_sv, len);
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
            XPUSHs(&PL_sv_undef);
            XPUSHs(&PL_sv_undef);
        }


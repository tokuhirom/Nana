#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "../../ppport.h"

#include "token.h"

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
 * is opening char for q{ qr{ qq{ ?
 */
int is_opening(char c) {
    return (
           c == '!'
        || c == '\''
        || c == '{'
        || c == '['
        || c == '"'
        || c == '('
    ) ? 1 : 0;
}

#include "toke.c"

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
        SV *yylval = &PL_sv_undef;
        int token_id = token_op(src, len, &used, &found_end, &lineno_inc, &yylval);
        mXPUSHi(used);
        mXPUSHi(token_id);
        XPUSHs(yylval);


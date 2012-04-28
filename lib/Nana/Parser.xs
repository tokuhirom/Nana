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

MODULE = Nana::Parser      PACKAGE = Nana::Translator::Perl::Builtins

void
typeof(SV *v)
    PPCODE:
        dTARG;
#define RETURN_P(x) do { mXPUSHs(newSVpv(x, strlen(x))); return; } while(0)
        if (!SvOK(v)) {
            RETURN_P("Undef");
        } else if (sv_isobject(v)) {
            if (sv_isa(v, "Nana::Translator::Perl::Object")) {
                SV * body = SvRV(v);
                SV ** klass = hv_fetch((HV*)SvRV(v), "klass", strlen("klass"), 0);
                if (!klass || !SvROK(*klass)) { croak("[BUG] Cannot take a class body from Object."); }
                SV ** name = hv_fetch((HV*)SvRV(*klass), "name", strlen("name"), 0);
                if (!name) { croak("[BUG] Cannot take a name from Class."); }
                XPUSHs(*name);
                return;
            }
#define FOO(x, y) do { if (sv_isa(v, x)) { mXPUSHs(newSVpv(y, strlen(y))); return; } } while (0)
            FOO("Nana::Translator::Perl::Range", "Range");
            FOO("Nana::Translator::Perl::Object", "Object");
            FOO("Nana::Translator::Perl::Class", "Class");
            FOO("Nana::Translator::Perl::Regexp", "Regexp");
            FOO("Nana::Translator::Perl::RegexpMatched", "RegexpMatched");
            FOO("Nana::Translator::Perl::Exception", "Exception");
            FOO("Nana::Translator::Perl::FilePackage", "FilePackage");
            FOO("Nana::Translator::Perl::PerlPackage", "PerlPackage");
            FOO("Nana::Translator::Perl::PerlObject", "PerlObject");
            FOO("JSON::XS::Boolean", "Bool");
#undef FOO
        } else if (SvROK(v)) {
            SV *body = SvRV(v);
            switch (SvTYPE(body)) {
            case SVt_PVAV:
                mXPUSHs(newSVpv("Array", 0));
                return;
            case SVt_PVHV:
                mXPUSHs(newSVpv("Hash", 0));
                return;
            case SVt_PVCV:
                mXPUSHs(newSVpv("Code", 0));
                return;
            }
        } else {
            if (SvIOK(v) && !SvPOK(v)) {
                RETURN_P("Int");
            }
            if (SvNOK(v) && !SvPOK(v)) {
                RETURN_P("Double");
            }
            RETURN_P("Str");
        }
#undef RETURN_P
        sv_dump(v);
        croak("[BUG] Unknown type");


#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "../../ppport.h"

#include "token.h"

typedef enum {
    VALUE_TYPE_UNDEF,
    VALUE_TYPE_INT,
    VALUE_TYPE_DOUBLE,
    VALUE_TYPE_BOOL,
    VALUE_TYPE_STR,
    VALUE_TYPE_ARRAY,
    VALUE_TYPE_HASH,
    VALUE_TYPE_CODE,
    VALUE_TYPE_RANGE,
    VALUE_TYPE_REGEXP,
    VALUE_TYPE_REGEXP_MATCHED,
    VALUE_TYPE_EXCEPTION,
    VALUE_TYPE_FILE_PACKAGE,
    VALUE_TYPE_PERL_PACKAGE,
    VALUE_TYPE_PERL_OBJECT,
    VALUE_TYPE_CLASS,
    VALUE_TYPE_OBJECT
} value_type_t;

value_type_t tora_detect_value_type(SV *v) {
    if (!SvOK(v)) {
        return VALUE_TYPE_UNDEF;
    } else if (sv_isobject(v)) {
#define FOO(x, y) do { if (sv_isa(v, x)) { return y; } } while (0)
        FOO("Nana::Translator::Perl::Range", VALUE_TYPE_RANGE);
        FOO("Nana::Translator::Perl::Object", VALUE_TYPE_OBJECT);
        FOO("Nana::Translator::Perl::Class", VALUE_TYPE_CLASS);
        FOO("Nana::Translator::Perl::Regexp", VALUE_TYPE_REGEXP);
        FOO("Nana::Translator::Perl::RegexpMatched", VALUE_TYPE_REGEXP_MATCHED);
        FOO("Nana::Translator::Perl::Exception", VALUE_TYPE_EXCEPTION);
        FOO("Nana::Translator::Perl::FilePackage", VALUE_TYPE_FILE_PACKAGE);
        FOO("Nana::Translator::Perl::PerlPackage", VALUE_TYPE_PERL_PACKAGE);
        FOO("Nana::Translator::Perl::PerlObject", VALUE_TYPE_PERL_OBJECT);
        FOO("JSON::XS::Boolean", VALUE_TYPE_BOOL);
#undef FOO
    } else if (SvROK(v)) {
        SV *body = SvRV(v);
        switch (SvTYPE(body)) {
        case SVt_PVAV:
            return VALUE_TYPE_ARRAY;
        case SVt_PVHV:
            return VALUE_TYPE_HASH;
        case SVt_PVCV:
            return VALUE_TYPE_CODE;
        default:
            sv_dump(v);
            croak("[BUG] Unknown type");
        }
    } else {
        if (SvIOK(v) && !SvPOK(v)) {
            return VALUE_TYPE_INT;
        }
        if (SvNOK(v) && !SvPOK(v)) {
            return VALUE_TYPE_DOUBLE;
        }
        return VALUE_TYPE_STR;
    }
    sv_dump(v);
    croak("[BUG] Unknown type");
}

static int skip_ws(char *src, size_t len, int *found_end, int *lineno_inc) {
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

static SV *json_true, *json_false;

SV *get_bool(const char *name) {
    SV *sv = get_sv(name, 1);
    SvREADONLY_on(sv);
    SvREADONLY_on(SvRV(sv));
    return sv;
}

int tora_boolean(SV *v) {
    if (sv_isa(v, "JSON::XS::Boolean")) {
        return SvIV(SvRV(v)) ? 1 : 0;
    } else if (!SvOK(v)) {
        return 0;
    } else {
        return 1;
    }
}

const char *tora_stringify_type(value_type_t t) {
#define RETURN_P(x) return x
    switch (t) {
    case VALUE_TYPE_UNDEF: RETURN_P("Undef");
    case VALUE_TYPE_OBJECT: RETURN_P("Object");
    case VALUE_TYPE_ARRAY: RETURN_P("Array");
    case VALUE_TYPE_BOOL: RETURN_P("Bool");
    case VALUE_TYPE_CLASS: RETURN_P("Class");
    case VALUE_TYPE_CODE: RETURN_P("Code");
    case VALUE_TYPE_DOUBLE: RETURN_P("Double");
    case VALUE_TYPE_EXCEPTION: RETURN_P("Exception");
    case VALUE_TYPE_FILE_PACKAGE: RETURN_P("FilePackage");
    case VALUE_TYPE_HASH: RETURN_P("Hash");
    case VALUE_TYPE_INT: RETURN_P("Int");
    case VALUE_TYPE_PERL_OBJECT: RETURN_P("PerlObject");
    case VALUE_TYPE_PERL_PACKAGE: RETURN_P("PerlPackage");
    case VALUE_TYPE_RANGE: RETURN_P("Range");
    case VALUE_TYPE_REGEXP: RETURN_P("Regexp");
    case VALUE_TYPE_REGEXP_MATCHED: RETURN_P("RegexpMatched");
    case VALUE_TYPE_STR: RETURN_P("Str");
    }
#undef RETURN_P
    abort();
}

#include "../../xs/operator.c"

MODULE = Nana::Parser       PACKAGE = Nana::Parser

BOOT:
{
    json_true  = get_bool("JSON::XS::true");
    json_false = get_bool("JSON::XS::false");
}

void
skip_ws(SV * src_sv)
    PPCODE:
        /* skip white space, comments. */
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
#define RETURN_P(x) do { mXPUSHs(newSVpv(x, strlen(x))); return; } while(0)
        switch (tora_detect_value_type(v)) {
        case VALUE_TYPE_UNDEF:
            RETURN_P("Undef");
        case VALUE_TYPE_OBJECT: {
            SV ** klass = hv_fetch((HV*)SvRV(v), "klass", strlen("klass"), 0);
            if (!klass || !SvROK(*klass)) { croak("[BUG] Cannot take a class body from Object."); }
            SV ** name = hv_fetch((HV*)SvRV(*klass), "name", strlen("name"), 0);
            if (!name) { croak("[BUG] Cannot take a name from Class."); }
            XPUSHs(*name);
            return;
        }
        case VALUE_TYPE_ARRAY: RETURN_P("Array");
        case VALUE_TYPE_BOOL: RETURN_P("Bool");
        case VALUE_TYPE_CLASS: RETURN_P("Class");
        case VALUE_TYPE_CODE: RETURN_P("Code");
        case VALUE_TYPE_DOUBLE: RETURN_P("Double");
        case VALUE_TYPE_EXCEPTION: RETURN_P("Exception");
        case VALUE_TYPE_FILE_PACKAGE: RETURN_P("FilePackage");
        case VALUE_TYPE_HASH: RETURN_P("Hash");
        case VALUE_TYPE_INT: RETURN_P("Int");
        case VALUE_TYPE_PERL_OBJECT: RETURN_P("PerlObject");
        case VALUE_TYPE_PERL_PACKAGE: RETURN_P("PerlPackage");
        case VALUE_TYPE_RANGE: RETURN_P("Range");
        case VALUE_TYPE_REGEXP: RETURN_P("Regexp");
        case VALUE_TYPE_REGEXP_MATCHED: RETURN_P("RegexpMatched");
        case VALUE_TYPE_STR: RETURN_P("Str");
        }
#undef RETURN_P
        sv_dump(v);
        croak("[BUG] Unknown type");

MODULE = Nana::Parser      PACKAGE = Nana::Translator::Perl::Runtime

void
tora_boolean(SV *v)
    PPCODE:
        XPUSHs(tora_boolean(v) ? json_true : json_false);

void
tora_op_not(SV *v)
    PPCODE:
        XPUSHs(tora_boolean(v) ? json_false : json_true);

void
tora_op_gt(SV *lhs, SV*rhs)
    PPCODE:
        XPUSHs(tora_op_gt(lhs, rhs) ? json_true : json_false);

void
tora_op_lt(SV *lhs, SV*rhs)
    PPCODE:
        XPUSHs(tora_op_lt(lhs, rhs) ? json_true : json_false);

void
tora_op_le(SV *lhs, SV*rhs)
    PPCODE:
        XPUSHs(tora_op_le(lhs, rhs) ? json_true : json_false);

void
tora_op_ge(SV *lhs, SV*rhs)
    PPCODE:
        XPUSHs(tora_op_ge(lhs, rhs) ? json_true : json_false);


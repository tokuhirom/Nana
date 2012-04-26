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
#define HAVE2(c) (len-*used>=2)
#define HAVE3(c) (len-*used>=3)
#define ALPHA2(c) (HAVE2() && isALPHA(*(p+1)))
#define IDENT3(c) (HAVE3() && (isALNUM(*(p+2)) || *(p+2)=='_'))
#define CHAR2(c) (HAVE2() && *(p+1) == (c))
#define CHAR3(c) (HAVE3() && *(p+2) == (c))
#define SIMPLEOP(type,_used) do { *used+=_used; return type; } while (0)
    *used = skip_ws(src, len, found_end, lineno_inc);
    if (*found_end) {
        return TOKEN_EOF;
    }
    if (*used == len) {
        return TOKEN_EOF;
    }
    char *p = src+*used;

    switch (*p) {
    case '/':
        if (CHAR2('=')) {
            SIMPLEOP(TOKEN_DIV_ASSIGN, 2);
        } else {
            SIMPLEOP(TOKEN_DIV, 1);
        }
    case '%':
        if (CHAR2('=')) {
            SIMPLEOP(TOKEN_MOD_ASSIGN, 2);
        } else {
            SIMPLEOP(TOKEN_MOD, 1);
        }
    case ',':
        SIMPLEOP(TOKEN_COMMA, 1);
    case '!':
        if (CHAR2('=')) {
            SIMPLEOP(TOKEN_NOT_EQUAL, 2);
        } else if (CHAR2('~')) {
            SIMPLEOP(TOKEN_REGEXP_NOT_MATCH, 2);
        } else {
            SIMPLEOP(TOKEN_NOT, 1);
        }
    case '=':
        if (CHAR2('=')) {
            SIMPLEOP(TOKEN_EQUAL_EQUAL, 2);
        } else if (CHAR2('>')) { /* => */
            SIMPLEOP(TOKEN_FAT_COMMA, 2);
        } else if (CHAR2('~')) { /* =~ */
            SIMPLEOP(TOKEN_REGEXP_MATCH, 2);
        } else {
            SIMPLEOP(TOKEN_ASSIGN, 1);
        }
    case '^':
        if (CHAR2('=')) {
            SIMPLEOP(TOKEN_XOR_ASSIGN, 2);
        } else {
            SIMPLEOP(TOKEN_XOR, 1);
        }
    case '.':
        if (CHAR2('.')) {
            if (CHAR3('.')) {
                SIMPLEOP(TOKEN_DOTDOTDOT, 3);
            } else {
                SIMPLEOP(TOKEN_DOTDOT, 2);
            }
        } else {
            SIMPLEOP(TOKEN_DOT, 1);
        }
        break;
    case '|':
        if (CHAR2('|')) {
            if (CHAR3('=')) {
                SIMPLEOP(TOKEN_OROR_ASSIGN, 3);
            } else {
                SIMPLEOP(TOKEN_OROR, 2);
            }
        } else if (CHAR2('=')) {
            SIMPLEOP(TOKEN_OR_ASSIGN, 2);
        } else {
            SIMPLEOP(TOKEN_OR, 1);
        }
    case '&':
        if (CHAR2('&')) {
            SIMPLEOP(TOKEN_ANDAND, 2);
        } else if (CHAR2('=')) {
            SIMPLEOP(TOKEN_AND_ASSIGN, 2);
        } else {
            SIMPLEOP(TOKEN_AND, 1);
        }
        break;
    case '<':
        if (CHAR2('<')) {
            if (CHAR3('=')) {
                SIMPLEOP(TOKEN_LSHIFT_ASSIGN, 3);
            } else if (CHAR3('\'')) { /* <<' */
                SIMPLEOP(TOKEN_HEREDOC_SQ_START, 3);
            } else {
                SIMPLEOP(TOKEN_LSHIFT, 2);
            }
        } else if (CHAR2('=')) {
            if (CHAR3('>')) { /* <=> */
                SIMPLEOP(TOKEN_CMP, 3);
            } else {
                SIMPLEOP(TOKEN_GE, 2);
            }
        } else {
            SIMPLEOP(TOKEN_GT, 1);
        }
        break;
    case '>':
        if (CHAR2('>')) {
            if (CHAR3('=')) {
                SIMPLEOP(TOKEN_RSHIFT_ASSIGN, 3);
            } else {
                SIMPLEOP(TOKEN_RSHIFT, 2);
            }
        } else if (CHAR2('=')) {
            SIMPLEOP(TOKEN_LE, 2);
        } else {
            SIMPLEOP(TOKEN_LT, 1);
        }
        break;
    case '\\':
        SIMPLEOP(TOKEN_REF, 1);
        break;
    case '~':
        SIMPLEOP(TOKEN_TILDE, 1);
        break;
    case '$':
        if (CHAR2('{')) { /* ${ */
            SIMPLEOP(TOKEN_DEREF, 2);
        }
        break;
    case '*':
        if (CHAR2('*')) {
            if (CHAR3('=')) {
                SIMPLEOP(TOKEN_POW_ASSIGN, 3);
            } else {
                SIMPLEOP(TOKEN_POW, 2);
            }
        } else if (CHAR2('=')) { /* *= */
            SIMPLEOP(TOKEN_MUL_ASSIGN, 2);
        } else {
            SIMPLEOP(TOKEN_MUL, 1);
        }
        break;
    case '+':
        if (CHAR2('+')) {
            SIMPLEOP(TOKEN_PLUSPLUS, 2);
        } else if (CHAR2('=')) { /* += */
            SIMPLEOP(TOKEN_PLUS_ASSIGN, 2);
        } else {
            SIMPLEOP(TOKEN_PLUS, 1);
        }
        break;
    case 'b':
        if (CHAR2('\'')) {
            SIMPLEOP(TOKEN_BYTES_SQ, 2);
        } else if (CHAR2('"')) {
            SIMPLEOP(TOKEN_BYTES_DQ, 2);
        }
        break;
    case 'q':
        if (CHAR2('q') && HAVE3() && is_opening(*(p+2))) { /* qq{ */
            SIMPLEOP(TOKEN_STRING_QQ_START, 3);
        }
        if (CHAR2('r') && HAVE3() && is_opening(*(p+2))) { /* qr{ */
            SIMPLEOP(TOKEN_REGEXP_QR_START, 3);
        }
        if (HAVE2() && is_opening(*(p+1))) { /* q{ */
            SIMPLEOP(TOKEN_STRING_Q_START, 2);
        }
        break;
    case '"':
        SIMPLEOP(TOKEN_STRING_DQ, 1);
        break;
    case '\'':
        SIMPLEOP(TOKEN_STRING_SQ, 1);
        break;
    case '[':
        SIMPLEOP(TOKEN_LBRACKET, 1);
        break;
    case '-':
        /* [[qr{^-(?![=a-z>-])}, '-'], [qr{^\+(?![\+=])}, '+']]) */
        if (ALPHA2() && !IDENT3()) {
            SIMPLEOP(TOKEN_FILETEST, 2);
        }

        if (CHAR2('-')) { /* -- */
            SIMPLEOP(TOKEN_MINUSMINUS, 2);
        } else if (CHAR2('>')) { /* -> */
            SIMPLEOP(TOKEN_LAMBDA, 2);
        } else if (CHAR2('=')) { /* -= */
            SIMPLEOP(TOKEN_MINUS_ASSIGN, 2);
        } else {
            SIMPLEOP(TOKEN_MINUS, 1);
        }
        break;
    }
    return TOKEN_EOF;
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


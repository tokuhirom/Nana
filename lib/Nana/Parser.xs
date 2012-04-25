#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "../../ppport.h"

MODULE = Nana::Parser       PACKAGE = Nana::Parser

void
_skip_ws(SV * src_sv)
    PPCODE:
        dTARG;
        STRLEN len;
        char *src = SvPV(src_sv, len);
        char *end = src+len;
        char *p = src;
        int found_end = 0;
        int lineno_inc = 0;
        int seen_nl = 0;

        while (p<end) {
            if (*p==' ' || *p=='\t' || *p == '\f') {
                seen_nl = 0;
                p++;
            } else if (*p=='#') {
                while (p<end) {
                    if (*p=='\n') {
                        seen_nl = 1;
                        lineno_inc++;
                        p++;
                        break;
                    }
                    p++;
                }
            } else if (seen_nl && strnEQ(p, "__END__\n", MIN(end-p, strlen("__END__\n")))) {
                found_end = 1;
                break;
            } else if (*p == '\n') {
                seen_nl = 1;
                lineno_inc++;
                p++;
            } else {
                break;
            }
        }
        mXPUSHi(p-src); /* used chars */
        mXPUSHi(found_end); /* found __END__ */
        mXPUSHi(lineno_inc); /* lineno */


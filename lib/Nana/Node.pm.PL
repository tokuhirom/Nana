use strict;
use Text::MicroTemplate qw(render_mt);

my %seen;
my @nodes = grep { !$seen{$_}++ } qw(

    NODE_INT
    NODE_DOUBLE
    NODE_TRUE
    NODE_FALSE
    NODE_UNDEF
    NODE_IDENTIFIER
    NODE_TUPLE
    NODE_STRING
    NODE_BYTES

    NODE_INSTANCIATE_IDENTIFIER

    NODE_FUNCALL

    NODE_PLUS
    NODE_MINUS
    NODE_MUL
    NODE_MOD
    NODE_DIV
    NODE_POW
    NODE_STMTS
    NODE_STMTS_LIST
    NODE_NEWLINE
    NODE_IF
    NODE_ELSIF
    NODE_ELSE
    NODE_SUB

    NODE_DO

    NODE_EXTRACT_ARRAY

    NODE_DEREF
    NODE_SELF
    NODE_GET_PACKAGE_VARIABLE

    NODE_LOCAL

    NODE_LAMBDA

    NODE_LT
    NODE_GT
    NODE_LE
    NODE_GE
    NODE_EQ
    NODE_NE
    NODE_BITXOR
    NODE_BITOR
    NODE_BITAND
    NODE_BITLSHIFT
    NODE_BITRSHIFT
    NODE_GETVARIABLE
    NODE_SETVARIABLE
    NODE_SETVARIABLE_MULTI
    NODE_ASSIGN
    NODE_WHILE
    NODE_ROOT
    NODE_VOID
    NODE_FUNCDEF
    NODE_RETURN
    NODE_BLOCK
    NODE_MY
    NODE_MAKE_ARRAY
    NODE_MAKE_HASH
    NODE_GET_ITEM
    NODE_FOR
    NODE_FOREACH
    NODE_METHOD_CALL

    NODE_PRE_INC
    NODE_POST_INC
    NODE_PRE_DEC
    NODE_POST_DEC

    NODE_NOP

    NODE_FILE_TEST

    NODE_RANGE
    NODE_REGEXP
    NODE_DOTDOTDOT

    NODE_TRY
    NODE_DIE

    NODE_USE

    NODE_CLASS

    NODE_LOGICAL_AND
    NODE_LOGICAL_OR
    NODE_LOGICAL_XOR

    NODE_REDO
    NODE_LAST
    NODE_NEXT

    NODE_PLUS_ASSIGN
    NODE_MINUS_ASSIGN
    NODE_DIV_ASSIGN
    NODE_MUL_ASSIGN
    NODE_AND_ASSIGN
    NODE_OR_ASSIGN
    NODE_XOR_ASSIGN
    NODE_MOD_ASSIGN
    NODE_OROR_ASSIGN
    NODE_LSHIFT_ASSIGN
    NODE_RSHIFT_ASSIGN
    NODE_POW_ASSIGN

    NODE_COMMA
    NODE_THREE
    NODE_DOTDOT
    NODE_DOTDOTDOT

    NODE_CMP
    NODE_LSHIFT
    NODE_RSHIFT

    NODE_REGEXP_MATCH
    NODE_REGEXP_NOT_MATCH

    NODE_UNARY_NOT
    NODE_UNARY_MINUS
    NODE_UNARY_TILDE
    NODE_UNARY_REF
    NODE_UNARY_MUL
    NODE_UNARY_PLUS

    NODE_GET_METHOD

    NODE___FILE__
    NODE_GETITEM
    NODE_CALL
    NODE_PARAMS_DEFAULT
    NODE_IDENT
    NODE_VARIABLE
    NODE_HEREDOC
    NODE_PRIMARY_IDENT
    NODE_QW
    NODE_STR2
    NODE_STRCONCAT
    NODE_STR
);

&output_pm; exit 0;

# ---------------------------------------------------------------

sub output_pm {
open my $ofh, '>', 'lib/Nana/Node.pm';
print $ofh render_mt(<<'...', @nodes);
? my @nodes = @_;
package Nana::Node;
use strict;
use warnings;
use parent qw(Exporter);

? my $i=1;
use constant {
? for (@nodes) {
    <?= $_ ?>  => <?= $i++ ?>,
? }
};

sub node_name {
    +{
? for (@nodes) {
        <?= $_ ?>() => "<?= $_ ?>",
? }
    }->{$_[0]};
}

our @EXPORT=qw(node_name <?= join(" ", @nodes) ?>);

1;
...
}

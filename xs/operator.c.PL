use Text::MicroTemplate qw(render_mt build_mt);
open my $ofh, '>', 'xs/operator.c'
    or die $!;
my $data = [
    ['gt', 'greater than', '>', 'strGT'],
    ['lt', 'less than', '<', 'strLT'],
    ['le', 'less than or equals', '<=', 'strLE'],
    ['ge', 'greater than or equals', '>=', 'strGE'],
];
print $ofh build_mt(template => <<'...', escape_func => sub { $_[0] })->($data);
? for (@{$_[0]}) {
? my ($type, $long, $op, $strop) = @{$_};
bool tora_op_<?= $type ?>(SV* lhs, SV*rhs) {
    value_type_t lhs_t = tora_detect_value_type(lhs);
    value_type_t rhs_t = tora_detect_value_type(rhs);

    if (lhs_t == VALUE_TYPE_UNDEF) {
        croak("You cannot use undefined value as left side value in <?= $long ?> operator.");
    }
    if (rhs_t == VALUE_TYPE_UNDEF) {
        croak("You cannot use undefined value as right side value in <?= $long ?> operator.");
    }
    if (lhs_t == VALUE_TYPE_INT || lhs_t == VALUE_TYPE_DOUBLE) {
        return SvNV(lhs) <?= $op ?> SvNV(rhs) ? TRUE : FALSE;
    } else if (lhs_t == VALUE_TYPE_STR) {
        char * lhs_c = SvPV_nolen(lhs);
        char * rhs_c = SvPV_nolen(rhs);
        return <?= $strop ?>(lhs_c, rhs_c);
    } else {
        croak("<?= $long ?> operator does not support this type: %s", tora_stringify_type(lhs_t));
    }
    abort();
}
? }

...

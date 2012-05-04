package Perl::Str;
use strict;
use warnings;
use utf8;
use Encode;

sub b1 {
    my $b = shift;
    if ($b eq encode_utf8('ほげ') && !utf8::is_utf8($b)) {
        return 'ok';
    } else {
        return 'not ok';
    }
}

sub b2 {
    my $b = shift;
    if ($b ne 'ほげ') {
        return 'not ok(body)';
    } elsif (!utf8::is_utf8($b)) {
        return 'not ok(flag)';
    } else {
        return 'ok';
    }
}

sub b3 {
    return "いいよ";
}

sub b4 {
    return encode_utf8 "いいよ";
}

1;


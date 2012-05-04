package Perl::ReturnDeep;
use strict;
use warnings;
use utf8;

sub get {
    [
        +{},
        'hoge',
        'ほげ',
        (bless [], 'Perl::ReturnDeep'),
    ]
}

1;


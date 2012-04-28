use strict;
use warnings;
use utf8;
use Test::More;
use Nana::Parser;
use Nana::Translator::Perl::Range;
use Nana::Translator::Perl::Object;
use Nana::Translator::Perl::Builtins;
use Nana::Translator::Perl::Runtime;
use Nana::Translator::Perl::Exception;

*typeof = *Nana::Translator::Perl::Builtins::typeof;

is(typeof([]), 'Array');
is(typeof(+{}), 'Hash');
is(typeof(sub { }), 'Code');
is(typeof(undef), 'Undef');
is(typeof(Nana::Translator::Perl::Range->new(1,10)), 'Range');
is(typeof(Nana::Translator::Perl::Object->new(Nana::Translator::Perl::Class->new("YO"), {})), 'YO');
is(typeof(Nana::Translator::Perl::Exception->new(1)), 'Exception');
is(typeof(Nana::Translator::Perl::FilePackage->new(1)), 'FilePackage');
is(typeof(Nana::Translator::Perl::Class->new(1)), 'Class');
is(typeof(Nana::Translator::Perl::Regexp->new(1)), 'Regexp');
is(typeof(Nana::Translator::Perl::RegexpMatched->new(1)), 'RegexpMatched');
is(typeof(Nana::Translator::Perl::PerlPackage->new(1)), 'PerlPackage');
is(typeof(Nana::Translator::Perl::PerlObject->new(1)), 'PerlObject');
is(typeof(JSON::true()), 'Bool');
is(typeof(1), 'Int');
is(typeof("HOGE"), 'Str');
is(typeof(3.14), 'Double');

done_testing;


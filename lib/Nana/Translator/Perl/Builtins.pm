package Nana::Translator::Perl::Builtins;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);
use 5.10.0;
use B;
use JSON::XS;
use Data::Dumper;
use Devel::Peek;
use Nana::Translator::Perl::RegexpMatched;
use Nana::Translator::Perl::Class;
use Carp;
use Cwd;
use Fcntl ();
use Nana::Translator::Perl::PerlPackage;

our @EXPORT = qw(
    %TORA_BUILTIN_FUNCTIONS
    %TORA_BUILTIN_CLASSES
);

our %TORA_BUILTIN_CLASSES;

sub _argument_error {
    croak @_;
}

sub _runtime_error {
    croak @_;
}

# http://docs.python.org/library/re.html#module-contents
use constant {
    REGEXP_GLOBAL     => 1, # 'g'
    REGEXP_MULTILINE  => 2, # 'm'
    REGEXP_IGNORECASE => 4, # 'i'
    REGEXP_EXPANDED   => 8, # 'x'
    REGEXP_DOTALL     => 16 # 's'
};
my %REGEXP_FLAG_MAP = (
    g => REGEXP_GLOBAL,
    m => REGEXP_MULTILINE,
    i => REGEXP_IGNORECASE,
    x => REGEXP_EXPANDED,
    s => REGEXP_DOTALL,
);

sub __say {
    for my $x (@_) {
        if (defined $x) {
            if (ref $x eq 'ARRAY') {
                __say(@$x);
            } else {
                say($x);
            }
        } else {
            say('undef');
        }
    }
}

sub self() { $Nana::Translator::Perl::Runtime::TORA_SELF }

sub tora_open {
    my $fname = shift;
    my $mode = shift || 'r';
    my $opener;
    if ($mode =~ 'r') {
        $opener = '<';
    } elsif ($mode =~ /w/) {
        $opener = '>';
    } else {
        die "Unknown file opening mode: $mode";
    }
    open my $fh, $opener, $fname
        or die "Cannot open file $fname: $!";
    return $TORA_BUILTIN_CLASSES{File}->create_instance($fh);
}

our %TORA_BUILTIN_FUNCTIONS = (
    'say' => \&__say,
    'typeof' => \&typeof,
    getcwd => \&Cwd::getcwd,
    rand => sub {
        if (@_==0) {
            return rand()
        } elsif (@_==1) {
            my $type = typeof($_[0]);
            if ($type eq 'Int') {
                return int rand($_[0]);
            } elsif ($type eq 'Double') {
                return rand($_[0]);
            } else {
                _runtime_error("Bad argument for rand(): $_[0]");
            }
        } else {
            _runtime_error("Too much arguments for rand");
        }
    },
    sqrt => sub { sqrt(shift @_) },
    abs => sub { abs(shift @_) },
    cos => sub { cos(shift @_) },
    exp => sub { exp(shift @_) },
    hex => sub { hex(shift @_) },
    int => sub { int(shift @_) },
    log => sub { log(shift @_) },
    oct => sub { oct(shift @_) },
    sin => sub { sin(shift @_) },
    atan2 => sub { atan2(shift @_, shift @_) },
    getppid => sub {
        return getppid()
    },
    getpid => sub { return int $$ },
    'sprintf' => sub {
        my $format = shift;
        return CORE::sprintf($format, @_);
    },
    '__DUMP' => sub {
        Dump($_[0]);
    },
    'p' => sub {
        warn Dumper(@_);
    },
    'print' => sub {
        print(@_);
    },
    'printf' => sub {
        printf(@_);
    },
    'stat' => sub {
        return File::stat::stat(@_);
    },
    'eval' => sub {
        my $src = shift;
        require Nana::Translator::Perl;
        state $parser = Nana::Parser->new();
        state $compiler = Nana::Translator::Perl->new();
        my $ast = $parser->parse($src);
        my $perl = $compiler->compile($ast);
        my $ret = eval($perl);
        die $@ if $@;
        return $ret;
    },
    'open' => \&tora_open,
    opendir => sub {
        my $dirname = shift;
        opendir(my $dh, $dirname)
            or die "Cannot open directory $dirname: $!";
        return $TORA_BUILTIN_CLASSES{Dir}->create_instance($dh);
    },
    'callee' => sub {
        my @stack = @Nana::Translator::Perl::Runtime::CALLEE_STACK;
        if (@stack == 0) {
            return undef;
        }
        return $stack[@stack-1];
    },
    'caller' => sub {
        my @stack = @Nana::Translator::Perl::Runtime::CALLER_STACK;
        if (@_==1) {
            my $need = shift;
            my $n = 0;
            for my $caller (reverse @stack) {
                if ($n == $need) {
                    return $TORA_BUILTIN_CLASSES{Caller}->create_instance($caller);
                }
                $n++;
            }
            return undef;
        } else {
            my @ret;
            for my $caller (reverse @stack) {
                push @ret, $TORA_BUILTIN_CLASSES{Caller}->create_instance($caller);
            }
            return \@ret;
        }
    },
    import_perl => sub {
        my ($pkg, @args) = @_;
        state $pkgid = 0;
        $pkgid++;
        eval join('',
            "package Nana::Translator::Perl::Builtin::ImportPerl::Sandbox$pkgid;\n",
            "require $pkg;\n",
            $pkg . "->import(\@args);\n",
        );
        _runtime_error $@ if $@;
        no strict 'refs';
        # copy imported functions
        while (my ($key, $val) = each %{"Nana::Translator::Perl::Builtin::ImportPerl::Sandbox${pkgid}::"}) {
            next if $key ~~ [qw/BEGIN END CHECK/];
            self()->{$key} = sub {
                Nana::Translator::Perl::PerlPackage::__wrap($val->(@_));
            };
        }
        self()->{$pkg} = Nana::Translator::Perl::PerlPackage->new($pkg);
        return undef;
    },
);

my $DIR_ITER_CLASS = do {
    my $class = Nana::Translator::Perl::Class->new(
        'Dir::Iterator'
    );
    $class->add_method(
        '__next__' => sub {
            my $entry = readdir(self->data);
            return $entry;
        }
    );
    $class;
};

my %built_class_src = (
    'Code' => {
        package => sub {
            my $code = shift;
            my $obj = B::svref_2object($code);
            return $obj->GV->STASH->NAME;
        },
        name => sub {
            my $code = shift;
            my $obj = B::svref_2object($code);
            return $obj->GV->NAME;
        },
        filename => sub {
            my $code = shift;
            my $obj = B::svref_2object($code);
            return $obj->GV->FILE;
        },
        line => sub {
            my $code = shift;
            my $obj = B::svref_2object($code);
            return $obj->GV->LINE;
        },
    },
    'Array' => {
        push => sub { CORE::push(@{$_[0]}, $_[1]); return $_[0]; },
        pop => sub { return CORE::pop(@{$_[0]}); },
        shift => sub { return CORE::shift(@{$_[0]}); },
        unshift => sub { CORE::unshift(@{$_[0]}, $_[1]); return $_[0]; },
        map => sub {
            return [map { $_[1]->($_) } @{$_[0]}];
        },
        grep => sub {
            my $type = typeof($_[1]);
            if ($type eq 'Regexp') {
                return [grep { $_ =~ $_[1]->pattern } @{$_[0]}];
            } elsif ($type eq 'Code') {
                return [grep { $_[1]->($_) } @{$_[0]}];
            } else {
                die "Unkonown type for code.";
            }
        },
        join => sub {
            return join($_[1], @{$_[0]});
        },
        reverse => sub {
            return [reverse @{$_[0]}];
        },
        size => sub {
            return 0+@{$_[0]};
        },
        sort => sub {
            return [sort @{$_[0]}];
        },
    },
    'Hash' => {
        keys => sub {
            return [CORE::keys(%{$_[0]})];
        },
        delete => sub {
            return CORE::delete($_[0]->{$_[1]});
        },
        exists => sub {
            return CORE::exists($_[0]->{$_[1]})
                ? JSON::XS::true() : JSON::XS::false();
        },
        values => sub {
            return [CORE::values(%{$_[0]})];
        },
    },
    'Class' => {
        bless => sub { # self.bless($data)
            return Nana::Translator::Perl::Object->new($_[0], $_[1]);
        },
        name => sub {
            return $_[0]->name;
        },
        meta => sub {
            return $TORA_BUILTIN_CLASSES{MetaClass}->create_instance($_[0]);
        },
        isa => sub {
            my $o = self;
            while ($o) {
                if ($o == $_[1]) {
                    return JSON::XS::true();
                }
                $o = $o->superclass();
            }
            if ($_[1] == $TORA_BUILTIN_CLASSES{Object}) {
                return JSON::XS::true();
            }
            return JSON::XS::false();
        },
    },
    MetaClass => {
        get_method_list => sub {
            return self->data->get_method_list($_[0]);
        },
        get_method => sub {
            return self->data->get_method($_[0]);
        },
        has_method => sub {
            return self->data->get_method($_[0])
                ? JSON::XS::true() : JSON::XS::false();
        },
        superclass => sub {
            self->data->superclass();
        },
        name => sub {
            self->data->name();
        },
    },
    'Str' => {
        length => sub {
            return length $_[0];
        },
        match => sub {
            my $pattern;
            if (ref $_[1] eq 'Nana::Translator::Perl::Regexp') {
                $pattern = $_[1]->pattern;
            } else {
                $pattern = $_[1];
            }
            return $_[0] =~ $pattern ? Nana::Translator::Perl::RegexpMatched->new($_[0]) : undef;
        },
        substr => sub {
            if (@_==2) {
                return substr($_[0], $_[1]);
            } elsif (@_==3) {
                return substr($_[0], $_[1], $_[2]);
            } else {
                die "ARGUMENT MISSING";
            }
        },
        replace => sub {
            my ($self, $a, $b) = @_;
            if (!ref $a) {
                $self =~ s/$a/$b/g;
                $self;
            } elsif (ref $a eq 'Nana::Translator::Perl::Regexp') {
                if ($a->global) {
                    $self =~ s/$a->{pattern}/$b/g;
                } else {
                    $self =~ s/$a->{pattern}/$b/;
                }
                $self;
            } else {
                ...
            }
        },
        split => sub {
            if (@_==2) {
                [split($_[1]->pattern, $_[0])];
            } else {
                [split($_[1]->pattern, $_[0], $_[2])];
            }
        },
        index => sub {
            index($_[0], $_[1]);
        },
        upper => sub {
            uc($_[0]);
        },
        lower => sub {
            lc($_[0]);
        },
        encode => sub {
            require Encode;
            Nana::Translator::Perl::Runtime::tora_bytes(Encode::encode($_[1], $_[0], $_[2]))
        },
    },
    'Object' => {
        tora => sub {
            return to_tora($_[0]);
        },
        class => sub {
            my $type = typeof($_[0]);
            if (my $class = $TORA_BUILTIN_CLASSES{$type}) {
                $class;
            } elsif (ref $_[0] eq 'Nana::Translator::Perl::Object') {
                return $_[0]->class;
            } else {
                ...
            }
        }
    },
    'File' => {
        'slurp' => sub {
            my $fh = $Nana::Translator::Perl::Runtime::TORA_SELF->data;
            my $src = do { local $/; <$fh> };
            return $src;
        },
        close => sub {
            my $fh = self->data;
            return CORE::close($fh);
        },
        fileno => sub {
            my $fh = self->data;
            return CORE::fileno($fh);
        },
        seek => sub {
            my $fh = self->data;
            return CORE::seek($fh, shift @_, shift @_);
        },
        tell => sub {
            my $fh = self->data;
            return CORE::tell($fh);
        },
        getc => sub {
            my $fh = self->data;
            return CORE::getc($fh);
        },
        open => sub {
            tora_open(@_);
        },
        print => sub {
            self->data->print(@_);
        },
        printf => sub {
            my $fh = self->data;
            CORE::printf $fh @_;
        },
        'SEEK_END' => scalar(Fcntl::SEEK_END()),
        'SEEK_CUR' => scalar(Fcntl::SEEK_CUR()),
        'SEEK_SET' => scalar(Fcntl::SEEK_SET()),
    },
    'Dir' => {
        read => sub {
            my $entry = readdir(self->data);
            return $entry;
        },
        __iter__ => sub {
            $DIR_ITER_CLASS->create_instance(self->data);
        },
        new => sub {
            my ($dirname) = @_;
            opendir(my $dh, $dirname)
                or _runtime_error "Cannot open directory $dirname: $!";
            return $TORA_BUILTIN_CLASSES{Dir}->create_instance($dh);
        },
        rmdir => sub {
            my ($name) = @_;
            rmdir($name)
                or _runtime_error "Cannot remove directory $name: $!";
            undef;
        },
        mkdir => sub {
            my ($name) = @_;
            $name // _argument_error "required directory name for mkdir";
            mkdir($name)
                or _runtime_error "Cannot create directory $name: $!";
            undef;
        },
    },
    Caller => {
        file => sub {
            return self->data->[1];
        },
        line=> sub {
            return self->data->[2];
        },
        code => sub {
            return self->data->[11];
        },
    },
    Bytes => {
        length => sub {
            return length(self->data);
        },
        decode => sub {
            my ($self, $charset) = @_;
            require Encode;
            return Encode::decode($charset, $self->data);
        },
#       encode => sub {
#           my ($self, $charset) = @_;
#           require Encode;
#           return Encode::encode($charset, $self->data);
#       },
    },
    Regexp => {
        flags => sub {
            # re::regexp_pattern is 5.9.5+
            my ($pattern, $mode) = re::regexp_pattern($_[0]->pattern);
            my $flags = 0;
            $mode =~ s/([gmixs])/$flags |= $REGEXP_FLAG_MAP{$1}/e;
            if ($_[0]->global) {
                $flags |= REGEXP_GLOBAL;
            }
            return $flags;
        },
        quotemeta => sub {
            return quotemeta($_[0]);
        },
        GLOBAL     => REGEXP_GLOBAL,
        MULTILINE  => REGEXP_MULTILINE,
        IGNORECASE => REGEXP_IGNORECASE,
        EXPANDED   => REGEXP_EXPANDED,
        DOTALL     => REGEXP_DOTALL,
    },
    Time => do {
        my $hash = +{
            new => sub {
                require Time::Piece;
                $TORA_BUILTIN_CLASSES{Time}->create_instance(
                    Time::Piece->new(@_)
                );
            },
            strftime => sub {
                self->data->strftime(@_)
            },
        };
        for my $method (qw(year)) {
            $hash->{$method} = sub { self->data->$method };
        }
        $hash->{day_of_week} = sub { self->data->wday };
        $hash->{second} = sub { self->data->second };
        $hash->{min} = sub { self->data->minute };
        $hash->{minute} = sub { self->data->minute };
        $hash->{hour} = sub { self->data->hour };
        $hash->{month} = sub { self->data->mon };
        $hash->{day} = sub { self->data->mday };
        $hash->{now} = $hash->{new};
        $hash;
    },
    Int => +{
    },
);
while (my ($class_name, $methods) = each %built_class_src) {
    $TORA_BUILTIN_CLASSES{$class_name} = do {
        my $class = Nana::Translator::Perl::Class->new($class_name);
        while (my ($methname, $methbody) = each %$methods) {
            $class->add_method(
                $methname, $methbody
            );
        }
        $class;
    };
}

sub to_tora {
    my $stuff = shift;
    my $type = typeof $stuff;
    if ($type eq 'Array') {
        return '[' . join(',', map { to_tora($_) } @$stuff) . ']';
    } elsif ($type eq 'Hash') {
        my @x;
        for (keys %$stuff) {
            push @x, to_tora($_) . '=>' . to_tora($stuff->{$_});
        }
        return '{' . join(',', @x) . '}';
    } elsif ($type eq 'MetaClass') {
        return 'MetaClass.bless(' . $stuff->data->name . ')';
    } elsif ($type eq 'Undef') {
        return 'undef';
    } elsif ($type eq 'Str') {
        $stuff =~ s/'/\\'/g;
        return "'" . $stuff . "'";
    } elsif ($type eq 'Bytes') {
        $stuff =~ s/'/\\'/g;
        return "b'" . $stuff . "'";
    } elsif ($type eq 'Int') {
        return $stuff;
    } elsif ($type eq 'Double') {
        return $stuff;
    } else {
        die "$type.tora is not implemented yet.";
        ...
    }
}

1;


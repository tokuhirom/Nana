===
--- code
class Foo {
    sub new() {
        say(self.name());
        say(typeof(self));
        return self.bless(1);
    }
    sub foo() {
        say(self.class().name());
    }
}
my $foo = Foo.new();
$foo.foo();
--- stdout
Foo
Class
Foo

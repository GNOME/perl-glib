print "1..6\n";

use strict;
use warnings;

use Glib;

print "ok 1\n";

# this will set @ISA for Foo, and register the type.
# note that if you aren't going to add properties, signals, or
# virtual overrides, there's no reason to do this rather than
# just re-blessing the object, so this is a rather contrived
# example.

my ($ok1, $ok2);

sub Foo::INIT_INSTANCE {
   print "ok $ok1\n";
}

sub Foo::FINALIZE_INSTANCE {
   print "ok $ok2\n";
}

Glib::Type->register (Glib::Object::, Foo::);

{
	$ok1 = 2; my $bar = new Foo;
	$ok2 = 3; undef $bar;
	$ok1 = 4; $bar = new Foo;
        $ok2 = 5;
}

print "ok 6\n";

$ok1 = $ok2 = -1;


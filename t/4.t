print "1..6\n";

use Glib;

print "ok 1\n";

# this will set @ISA for Foo, and register the type.
# note that if you aren't going to add properties, signals, or
# virtual overrides, there's no reason to do this rather than
# just re-blessing the object, so this is a rather contrived
# example.

sub Foo::INIT_INSTANCE {
   print "ok 2\n";
}

sub Foo::FINALIZE_INSTANCE {
   print "ok 5\n";
}

register Glib::Type
   Glib::Object::, Foo::,
   properties => [
   ];

sub Bar::INIT_INSTANCE {
   print "ok 3\n";
}

sub Bar::FINALIZE_INSTANCE {
   print "ok 4\n";
}

Glib::Type->register (Foo::, Bar::);

{
	my $bar = new Bar;
}

print "ok 6\n";


print "1..9\n";

use Glib;

print "ok 1\n";

sub Foo::INIT_INSTANCE {
   print "ok 2\n";
}

sub Foo::FINALIZE_INSTANCE {
   print "ok 8\n";
}

sub Foo::SET_PROPERTY {
   print "ok $_[3]\n";
}

sub Foo::GET_PROPERTY {
   print "ok 5\n";
   6;
}

register Glib::Type
   Glib::Object::, Foo::,
   properties => [
           Glib::ParamSpec->string (
              'some_string',
              'Some String Property',
              'This property is a string that is used as an example',
              'default value',
              [qw/readable writable/]
           ),
   ];

sub Bar::INIT_INSTANCE {
   print "ok 3\n";
}

sub Bar::FINALIZE_INSTANCE {
   print "ok 7\n";
}

Glib::Type->register (Foo::, Bar::);

{
   my $bar = new Bar;
   $bar->set(some_string => 4);
   print "ok ", $bar->get("some_string"), "\n";
}

print "ok 9\n";


print "1..10\n";

use strict;
use warnings;

use Glib;

print "ok 1\n";

my $init_self;

sub Foo::INIT_INSTANCE {
   $init_self = $_[0]*1;
   print "ok 2\n";
}

sub Foo::FINALIZE_INSTANCE {
   print "ok 9\n";
}

my $setprop_self;

sub Foo::SET_PROPERTY {
   $setprop_self = $_[0]*1;
   print "ok $_[2]\n";
}

sub Foo::GET_PROPERTY {
   print "ok 6\n";
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
   print "ok 8\n";
}

Glib::Type->register (Foo::, Bar::);

{
   my $bar = new Bar;
   use POSIX;
   $bar->set(some_string => 4);
   print $init_self != $setprop_self ? "not " : "", "ok 5\n";
   print $bar->get("some_string") != 6 ? "not " : "", "ok 7\n";
}

print "ok 10\n";


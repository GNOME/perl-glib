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


__END__

Copyright (C) 2003 by the gtk2-perl team (see the file AUTHORS for the
full list)

This library is free software; you can redistribute it and/or modify it under
the terms of the GNU Library General Public License as published by the Free
Software Foundation; either version 2.1 of the License, or (at your option) any
later version.

This library is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU Library General Public License for more
details.

You should have received a copy of the GNU Library General Public License along
with this library; if not, write to the Free Software Foundation, Inc., 59
Temple Place - Suite 330, Boston, MA  02111-1307  USA.

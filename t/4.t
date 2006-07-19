#
# test Glib::Object derivation in Perl.
# derive from a C object in perl, and derive from a Perl object in perl.
# checks order of execution of initializers and finalizers, so the code
# gets a little hairy.
#
print "1..15\n";

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

Glib::Type->register (Foo::, Bar::,
                      properties => [
                         Glib::ParamSpec->int ('number', 'some number',
                                               'number in bar but not in foo',
                                               0, 10, 0, ['readable']),
                      ]);

{
   # instantiate a child.  we should get messages from both initializers.
   my $bar = new Bar;
   use POSIX;
   # make sure we can set parent properties on the child
   $bar->set(some_string => 4);
   print $init_self != $setprop_self ? "not " : "", "ok 5\n";
   print $bar->get("some_string") != 6 ? "not " : "", "ok 7\n";
   # should see messages from both finalizers here.
}

print "ok 10\n";

#
# ensure that any properties added to the subclass were only added to
# the subclass, and not the parent.
#
print "".( defined Foo->find_property('some_string') ? "ok 11" : "not ok")."\n";
print "".(!defined Foo->find_property('number')      ? "ok 12" : "not ok")."\n";
print "".( defined Bar->find_property('number')      ? "ok 13" : "not ok")."\n";

my @fooprops = Foo->list_properties;
my @barprops = Bar->list_properties;

print "".(@fooprops == 1 ? "ok 14" : "not ok")." # property count for parent\n";
print "".(@barprops == 2 ? "ok 15" : "not ok")." # property count for child\n";


__END__

Copyright (C) 2003-2006 by the gtk2-perl team (see the file AUTHORS for the
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

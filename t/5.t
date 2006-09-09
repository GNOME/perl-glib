#!/usr/bin/perl

#
# sanity-checking on the property interface.  some of this could have gone
# into 4.t, but it is here to keep these tests small and digestable since
# they have freaky, spaghetti-like testing code.
#

use strict;
use warnings;

print "1..9\n";

use Glib;

print "ok 1\n";

package MyClass;

use Glib::Object::Subclass
   Glib::Object::,
   signals    =>
      {
          something_changed => {
             flags       => [qw(run-first)],
             return_type => undef,
             param_types => [],
          },
      },
   properties => [
      Glib::ParamSpec->string (
         'some_string',
         'Some String Property',
         'This property is a string that is used as an example',
         'default value',
         [qw/readable writable/]
      ),
   ];

sub INIT_INSTANCE {
   print "ok 2\n";
}

sub FINALIZE_INSTANCE {
   print "ok 8\n";
}

sub GET_PROPERTY {
   77;
}

package main;

{
   my $my = new MyClass;
   $my->set(some_string => "xyz");
   print $my->{some_string} eq "xyz" ? "" : "not ", "ok 3\n";
   print $my->get("some_string") == 77 ? "" : "not ", "ok 4\n";


   # verify that invalid property names result in an exception.
   # there are two places to test this, new() and set().
   eval {
      $my = new MyClass some_string => "foo",
                        invalid_param => 1,
			some_string => "bar";
      print "not ok - should not get here\n";
   };
   #print "\$@ = '$@'\n";
   print ($@ !~ /does not support property/ ? "not " : "", "ok 5\n");
   eval {
      $my->set (some_string => "foo",
                invalid_param => 1,
                some_string => "bar");
      print "not ok - should not get here\n";
   };
   #print "\$@ = '$@'\n";
   print ($@ !~ /does not support property/ ? "not " : "", "ok 6\n");
   # set should have bailed out before setting some_string to bar.
   # cannot use get() here, because GET_PROPERTY always returns 77.
   print $my->{some_string} ne 'foo' ? "not " : "", "ok 7\n";
}

print "ok 9\n";




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

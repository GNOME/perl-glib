#!/usr/bin/perl

use strict;
use warnings;

print "1..6\n";

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
   print "ok 5\n";
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
}

print "ok 6\n";




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

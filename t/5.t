#!/usr/bin/perl

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




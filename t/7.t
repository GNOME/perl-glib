#!/usr/bin/perl

=comment

test some GSignal stuff...
based on the Glib::Object::Subclass, since it already worked, but not
in that test because it would confound too many issues.

we do not use Test::More or even Test::Simple because we need to test
order of execution...  the ok() funcs from those modules assume you
are doing all your tests in order, but our stuff will jump around.

=cut

print "1..15\n";

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
          test_marshaler => {
###### FIXME FIXME FIXME something is broken here...
             flags       => [qw(run-first run-last run-cleanup)],
             ##return_type => 'Glib::Double',
             return_type => undef,
             param_types => [qw/Glib::String Glib::Boolean Glib::Uint Glib::Object/],
          },
      },
   ;

sub do_something_changed {
	print "# do_something_changed\n";
}
sub do_test_marshaler {
	#print "@_\n";
	return 2.718;
}

sub something_changed { $_[0]->signal_emit ('something_changed'); }
sub test_marshaler    { shift->signal_emit ('test-marshaler', @_); }

package main;

$a = 0;
$b = 0;

sub func_a {
	print (0==$a++
	       ? "ok 4 # func_a\n"
	       : "not ok # func_a called after being removed\n");
}
sub func_b {
	if (0==$b++) {
		print "ok 5 # func_b\n";
		$_[0]->signal_handlers_disconnect_by_func (\&func_a);
	} else {
		print "ok 7 # func_b again\n";
	}
}

{
   my $my = new MyClass;
   print "ok 2 # instantiated MyClass\n";
   $my->signal_connect (something_changed => \&func_a);
   my $id_b = $my->signal_connect (something_changed => \&func_b);
   print "ok 3 # connected handlers\n";

   $my->something_changed;
   print "ok 6\n";
   $my->something_changed;
   print "ok 8\n";
   $my->signal_handler_disconnect ($id_b);
   $my->something_changed;
   print "ok 9\n";

   # attempting to marshal the wrong number of params should croak
   eval { $my->test_marshaler (); };
   print ($@ ? "ok 10\n" : "not ok 10 # expected to croak but didn't\n");
   $my->test_marshaler (qw/foo bar baz/, $my);
   print "ok 11\n";
   $id = $my->signal_connect (test_marshaler => sub {
	   print ($_[0] == $my   &&
	          $_[1] eq 'foo' &&
		  $_[2]          && # string bar is true
		  $_[3] == 0     && # string baz converts to int of 0
		  $_[4] == $my   && # object passes unmolested
		  $_[5][1] eq 'two' # user-data is an array ref
		  ? "ok 13 # marshaled as expected\n"
		  : "not ok 13 # bad params in callback\n");
	   return 77.1;
   	}, [qw/one two/, 3.1415]);
   print ($id ? "ok 12\n" : "not ok\n");
   $my->test_marshaler (qw/foo bar baz/, $my);
   print "ok 14\n";
}

print "ok 15\n";




#!/usr/bin/perl

use strict;
use warnings;

=comment

test some GSignal stuff - marshaling, exception trapping, order of operations.

based on the Glib::Object::Subclass, since it already worked, but not
in that test because it would confound too many issues.

we do not use Test::More or even Test::Simple because we need to test
order of execution...  the ok() funcs from those modules assume you
are doing all your tests in order, but our stuff will jump around.


my apologies for the extreme density and ugliness of this code.

=cut

print "1..34\n";

use Glib;

print "ok 1\n";

package MyClass;

use Glib::Object::Subclass
   Glib::Object::,
   signals    =>
      {
          # a simple void-void signal
          something_changed => {
             class_closure => undef, # disable the class closure
             flags         => [qw/run-last action/],
             return_type   => undef,
             param_types   => [],
          },
          # test the marshaling of parameters
          test_marshaler => {
             flags       => 'run-last',
             param_types => [qw/Glib::String Glib::Boolean Glib::Uint Glib::Object/],
          },
          # one that returns a value
          returner => {
             flags       => 'run-last',
             return_type => 'Glib::Double',
             # using the default accumulator, which just returns the last
             # value
          },
          # more complicated/sophisticated value returner
          list_returner => {
             class_closure => sub {
                       print "ok 32 # hello from the class closure\n";
                       -1
             },
             flags         => 'run-last',
             return_type   => 'Glib::Scalar',
             accumulator   => sub {
                 # the accumulator gets (ihint, return_accu, handler_return)
                 # let's turn the return_accu into a list of all the handlers'
                 # return values.  this is weird, but the sort of thing you
                 # might actually want to do.
                 print "# in accumulator, got $_[2], previously "
		      . (defined ($_[1]) ? $_[1] : 'undef')
		      . "\n";
                 if ('ARRAY' eq ref $_[1]) {
                        push @{$_[1]}, $_[2];
                 } else {
                        $_[1] = [$_[2]];
                 }
                 # we must return two values --- a boolean that says whether
                 # the signal keeps emitting, and the accumulated return value.
                 # we'll stop emitting if the handler returns the magic 
                 # value 42.
                 ($_[2] != 42, $_[1])
	     },
	  },
      },
   ;

sub do_test_marshaler {
	print "# \$@ $@\n";
	print "# do_test_marshaller: @_\n";
	return 2.718;
}

sub do_emit {
	my $name = shift;
	print "\n\n".("="x79)."\n";
	print "emitting: $name"
	   . (__PACKAGE__->can ("do_$name") ? " (closure exists)" : "")
	   . "\n";
	my $ret = shift->signal_emit ($name, @_);
	#use Data::Dumper;
	#print Dumper( $ret );
	print "\n".("-"x79)."\n";
	return $ret;
}

sub do_returner {
	print "ok 24\n";
	-1.5;
}

sub something_changed { do_emit 'something_changed', @_ }
sub test_marshaler    { do_emit 'test_marshaler', @_ }
sub list_returner     { do_emit 'list_returner', @_ }
sub returner          { do_emit 'returner', @_ }

#############
package main;

my $a = 0;
my $b = 0;

sub func_a {
	print 0==$a++
	       ? "ok 4 # func_a\n"
	       : "not ok # func_a called after being removed\n";
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

   # attempting to marshal the wrong number of params should croak.
   # this is part of the emission process going wrong, not a handler,
   # so it's a bug in the calling code, and thus we shouldn't eat it.
   eval { $my->test_marshaler (); };
   print $@ =~ m/Incorrect number/
          ? "ok 10 # signal_emit barfs on bad input\n"
	  : "not ok 10 # expected to croak but didn't\n";

   $my->test_marshaler (qw/foo bar 15/, $my);
   print "ok 11\n";
   my $id = $my->signal_connect (test_marshaler => sub {
	   print $_[0] == $my   &&
	          $_[1] eq 'foo' &&
		  $_[2]          && # string bar is true
		  $_[3] == 15    && # expect an int
		  $_[4] == $my   && # object passes unmolested
		  $_[5][1] eq 'two' # user-data is an array ref
		  ? "ok 13 # marshaled as expected\n"
		  : "not ok 13 # bad params in callback\n";
	   return 77.1;
   	}, [qw/one two/, 3.1415]);
   print ($id ? "ok 12\n" : "not ok\n");
   $my->test_marshaler (qw/foo bar/, 15, $my);
   print "ok 14\n";

   $my->signal_handler_disconnect ($id);

   # here's a signal handler that has an exception.
   # we should be able to emit the signal all we like without catching
   # exceptions here, because we don't care what other people may have
   # connected to the signal.  the signal's exception can be caught with
   # an installed exception handler.
   $id = $my->signal_connect (test_marshaler => sub {
                              # signal handlers are always eval'd, so
                              # $@ should be empty.
                              warn "internal problem: \$@ is not empty in "
                                 . "signal handler!!!" if $@;
                              die "ouch"
                              });

   my $tag;
   $tag = Glib->install_exception_handler (sub {
	   	if ($tag) {
		   	print "ok 16 # caught exception $_[0]\n";
		} else {
			print "not ok # handler didn't uninstall itself\n";
		}
	   	0  # returning FALSE uninstalls
	   }, [qw/foo bar/, 0]);
   print ""
       . ($tag
          ? "ok 15 # installed exception handler with tag $tag"
	  : "not ok 15 # got no tag back from install_exception_handler?!?")
       . "\n";

   # the exception in the signal handler should not affect the value of
   # $@ at this code layer.
   $@ = 'neener neener neener';
   print "# before invocation: \$@ $@\n";
   $my->test_marshaler (qw/foo bar/, 4154, $my);
   print "# after invocation: \$@ $@\n";
   print "ok 17 # still alive after an exception in a callback\n";
   print "".($@ eq 'neener neener neener'
	     ? 'ok 18 # $@ is preserved across signal invocations'
	     : 'not ok # $@ not preserved correctly across signal invocation'
	       ."\n   # expected 'neener neener neener'\n"
	       .  "   # got '$@'\n"
	    )."\n";
   $tag = 0;

   # that was a single-shot -- the exception handler shouldn't run again.
   {
   local $SIG{__WARN__} = sub {
	   if ($_[0] =~ m/unhandled/m) {
	   	print "ok 20 # unhandled exception just warns\n"
	   } elsif ($_[0] =~ m/isn't numeric/m) {
	   	print "ok 19 # string value isn't numeric\n"
	   } else {
		print "not ok # got something unexpected in __WARN__: $_[0]\n";
	   }
	};
   $my->test_marshaler (qw/foo bar baz/, $my);
   print "ok 21\n";
   }

   use Data::Dumper;
   $my->signal_connect (returner => sub { print "ok 23\n"; 0.5 });
   # the class closure should be called in between these two
   $my->signal_connect_after (returner => sub { print "ok 25\n"; 42.0 });
   print "ok 22\n";
   my $ret = $my->returner;
   # we should have the return value from the last handler
   print $ret == 42.0 ? "ok 26\n" : "not ok # expected 42.0, got $ret\n";

   # now with our special accumulator
   $my->signal_connect (list_returner => sub { print "ok 28\n"; 10 });
   $my->signal_connect (list_returner => sub { print "ok 29\n"; '15' });
   $my->signal_connect (list_returner => sub { print "ok 30\n"; [20] });
   $my->signal_connect (list_returner => sub { print "ok 31\n"; {thing => 25} });
   # class closure should before the "connect_after" ones,
   # and this one will stop everything by returning the magic value.
   $my->signal_connect_after (list_returner => sub { print "ok 33 # stopper\n"; 42 });
   # if this one is called, the accumulator isn't working right
   $my->signal_connect_after (list_returner => sub { print "not ok # shouldn't get here\n"; 0 });
   print "ok 27\n";
   print Dumper( $my->list_returner );
}

print "ok 34\n";




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

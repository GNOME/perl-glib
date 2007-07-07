#!env perl -w

#
# mainloop stuff.
#

use Config;

print "1..25\n";

use Glib;

print "ok 1\n";

=out

GPerlClosures are used for Timeouts, Idle and IO watch handlers in addition
to GSignal stuff.

=cut

my $timeout = undef;

print "ok 2\n";
Glib::Idle->add (sub {print "ok 4 - idle one-shot\n"; 0});
Glib::Idle->add (sub {
		 print "ok 5 - another idle, but this one dies\n";
		 die "killer";
		 print "not ok - after die, shouldn't get here!\n";
		 1 # return true from idle to be called again; we
		   # should never get here, though
	});
$timeout = Glib::Timeout->add (1000, sub {
		    warn "!!!! should never get called";
		    die "oops" });
# timeouts and idles only get executed when there's a mainloop.
{
my $loop = Glib::MainLoop->new;
# the die will simply jump to the eval, leaving side effects in place.
# we have to kill the mainloop ourselves.
local $SIG{__DIE__} = sub {
		print "ok 6 - in __DIE__ handler\n";
		$loop->quit;
	};
local $SIG{__WARN__} = sub {
		print ""
		    . ($_[0] =~ /unhandled exception in callback/
		       ? "ok 7"
		       : "not ok - got something unexpected in __WARN__"
		      )
		    . "\n";
	};
print "ok 3 - running in eval\n";
$loop->run;
# remove this timeout to avoid confusing the next test.
Glib::Source->remove ($timeout);
}

# again, without dying in an idle this time
print "ok 8\n";
Glib::Timeout->add (100, sub { 
		    print "ok 10 - dying with 'waugh'\n";
		    die "waugh"
		    });
my $loop = Glib::MainLoop->new;
print "ok 9 - running in eval\n";
Glib->install_exception_handler (sub {
		print "ok 11 - killing loop from exception handler\n";
		$loop->quit;
		0});
$loop->run;


# this time with IO watchers
use Data::Dumper;

# There's a bug in glib which prevents io channels from marshalling
# properly here.  we don't have versioning API in Glib (yet), so
# we can't do much but just skip this.

if ($Config{archname} =~ m/^(x86_64|mipsel|mips|alpha)/
    and not Glib->CHECK_VERSION (2,2,4)) {
	print "not ok 12 - skip bug in glib\n";
	print "not ok 13 - skip bug in glib\n";
	print "not ok 14 - skip bug in glib\n";

} else {
	print "ok 12\n";
	open IN, $0 or die "can't open file\n";
	Glib::IO->add_watch (fileno IN,
		     [qw/in err hup nval/], 
		     sub {
		     	local $/ = undef;
			#print Dumper(\@_);
			$_ = <IN>;
			#print "'$_'";
			#print "eof - ".eof ($_[0])."\n";
			if (eof $_[0]) {
				print "ok 14 - eof, dying with 'done\\n'\n";
				die "done\n";
			}
			1;
		     });
	$loop = Glib::MainLoop->new;
	print "ok 13 - running in eval\n";
	Glib->install_exception_handler (sub {$loop->quit; 0});
	$loop->run;
}


# 1.072 fixes the long-standing "bug" that perl's safe signal handling
# caused asynchronous signals not to be delivered while a main loop is
# running (because control stays in C).  let's make sure that we can
# get a 1 second alarm before a 2 second timeout has a chance to fire.
if ($^O eq 'Win32') {
	# XXX Win32 doesn't do SIGALRM the way unix does; either the alarm
	# doesn't interrupt the poll, or alarm just doesn't work.
	my $reason = "async signals don't work on win32 like they do on unix";
	print "ok 15 - skip $reason\n";
	print "ok 16 - skip $reason\n";
} else {
	$loop = Glib::MainLoop->new;
	$SIG{ALRM} = sub {
		print "ok 15 - ALRM handler\n";
		$loop->quit;
	};
	my $timeout_fired = 0;
	Glib::Timeout->add (2000, sub {
		$timeout_fired++;
		$loop->quit;
		0;
	});
	alarm 1;
	$loop->run;
	print ""
	    . ($timeout_fired ? "not ok" : "ok")
	    . " 16 - 1 sec alarm handler fires before 2 sec timeout\n";
}

if (Glib->CHECK_VERSION (2, 4, 0)) {
	print Glib::main_depth == 0 ?
	  "ok 17\n" : "not ok 17\n";
} else {
	print "ok 17 - skip main_depth\n";
}

print $loop->is_running ?
  "not ok 18\n" : "ok 18\n";

print Glib::MainContext->new ?
  "ok 19\n" : "not ok 19\n";

print Glib::MainContext->default ?
  "ok 20\n" : "not ok 20\n";

my $context = $loop->get_context;
print $context ?
  "ok 21\n" : "not ok 21\n";

print $context->pending ?
  "not ok 22\n" : "ok 22\n";

if (Glib->CHECK_VERSION (2, 12, 0)) {
  print $context->is_owner ?
    "not ok 23\n" : "ok 23\n";
  print Glib::MainContext::is_owner(undef) ?
    "not ok 24\n" : "ok 24\n";
} else {
  print "ok 23 - skip\n";
  print "ok 24 - skip\n";
}

if (Glib->CHECK_VERSION (2, 13, 0)) { # FIXME: 2.14
  my $loop = Glib::MainLoop->new;
  Glib::Timeout->add_seconds (1, sub {
    print "ok 25 - in timeout handler\n";
    $loop->quit;
    return FALSE;
  });
  $loop->run;
} else {
  print "ok 25 - skip\n";
}

__END__

Copyright (C) 2003-2005 by the gtk2-perl team (see the file AUTHORS for the
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

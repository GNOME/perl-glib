#!env perl -w

print "1..14\n";

use Glib;

print "ok 1\n";

=out

GPerlClosures are used for Timeouts, Idle and IO watch handlers in addition
to GSignal stuff.

=cut

my $timeout = undef;

print "ok 2\n";
Glib::Idle->add (sub {print "ok 4 # idle one-shot\n"; 0});
Glib::Idle->add (sub {
		 print "ok 5 # another idle, but this one dies\n";
		 die "killer";
		 print "not ok # after die, shouldn't get here!\n";
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
		print "ok 6 # in __DIE__ handler\n";
		$loop->quit;
	};
local $SIG{__WARN__} = sub {
		print ""
		    . ($_[0] =~ /unhandled exception in callback/
		       ? "ok 7 # "
		       : "not ok # got something unexpected in __WARN__"
		      )
		    . "\n";
	};
print "ok 3 # running in eval\n";
$loop->run;
# remove this timeout to avoid confusing the next test.
Glib::Source->remove ($timeout);
}

# again, without dying in an idle this time
print "ok 8\n";
Glib::Timeout->add (100, sub { 
		    print "ok 10 # dying with 'waugh'\n";
		    die "waugh"
		    });
my $loop = Glib::MainLoop->new;
print "ok 9 # running in eval\n";
Glib->install_exception_handler (sub {
		print "ok 11 # killing loop from exception handler\n";
		$loop->quit;
		0});
$loop->run;


# this time with IO watchers
use Data::Dumper;
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
				print "ok 14 # eof, dying with 'done\\n'\n";
				die "done\n";
			}
			1;
		     });
$loop = Glib::MainLoop->new;
print "ok 13 # running in eval\n";
Glib->install_exception_handler (sub {$loop->quit; 0});
$loop->run;

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

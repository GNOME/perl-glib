#!env perl -w

print "1..15\n";

use Glib;

print "ok 1\n";

=out

GPerlClosures are used for Timeouts, Idle and IO watch handlers in addition
to GSignal stuff.

=cut

#sub Glib::MainLoop::DESTROY {
#	warn "Glib::MainLoop::DESTROY called";
#	$_[0]->quit if $_[0]->is_running;
#}

my $timeout = undef;

eval {
	print "ok 2\n";
	Glib::Idle->add (sub {print "ok 4 # idle one-shot\n"; 0});
	Glib::Idle->add (sub {
			 print "ok 5 # another idle, but this one dies\n";
			 die "killer\n";
			 print "not ok # after die, shouldn't get here!\n";
			 1 # return true from idle to be called again; we
			   # should never get here, though
		});
	$timeout = Glib::Timeout->add (1000, sub {
			    warn "!!!! should never get called";
			    die "oops" });
	# timeouts and idles only get executed when there's a mainloop.
	my $loop = Glib::MainLoop->new;
	# the die will simply jump to the eval, leaving side effects in place.
	# we have to kill the mainloop ourselves.
	local $SIG{__DIE__} = sub {
			print "ok 6 # in __DIE__ handler\n";
			$loop->quit;
		};
	print "ok 3 # running in eval\n";
	$loop->run;
	print "not ok # !!!!! after run, shouldn't get here\n";
};
check_errsv (7, "killer\n");
# remove this timeout to avoid confusing the next test.
Glib::Source->remove ($timeout);

# again, without dying in an idle this time
eval {
	print "ok 8\n";
	Glib::Timeout->add (100, sub { 
			    print "ok 10 # dying with 'waugh'\n";
			    die "waugh\n"
			    });
	my $loop = Glib::MainLoop->new;
#	local $SIG{__DIE__} = sub {
#			print "ok # in __DIE__ handler\n";
#			$loop->quit;
#		};
	print "ok 9 # running in eval\n";
	$loop->run;
	print "not ok # after run, which dies, so we should NOT get here\n";
};
check_errsv (11, "waugh\n");


# this time with IO watchers
use Data::Dumper;
eval {
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
	my $loop = Glib::MainLoop->new;
	print "ok 13 # running in eval\n";
	$loop->run;
	print "not ok # after run, which dies, so we should NOT get here\n";
};
check_errsv (15, "done\n");


sub check_errsv {
	my ($seq, $expected) = @_;

	if (defined ($@) && $@ eq $expected) {
		print "ok $seq # \$@ is $@\n"; 
	} else {
		# make the newlines nicely printable...
		(my $got = $@) =~ s/\n/\\n/g;
		$expected =~ s/\n/\\n/g;
		print "not ok $seq # \$@ is "
		    . (defined ($got) ? "'$got'" : "undef")
		    . ", expected '$expected'\n"; 
	}
}

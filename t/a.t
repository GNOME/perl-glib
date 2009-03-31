#!env perl -w

#
# message logging.
#

use strict;
use warnings;
use Data::Dumper;
use Test::More;
use Glib;
use Config;

if ($Config{archname} =~ m/^(x86_64|mipsel|mips|alpha)/
    and not Glib->CHECK_VERSION (2,2,4)) {
	# there is a bug in glib which makes g_log print messages twice
	# on 64-bit x86 platforms.  yosh has fixed this on the 2.2.x branch
	# and in 2.4.0 (actually 2.3.2). 
	# we don't have versioning API in Glib (yet), so we'll just
	# have to bail out.
	plan skip_all => "g_log doubles messages by accident on 64-bit platforms";
} else {
	plan tests => 12;
}

package Foo;

use Glib::Object::Subclass
    'Glib::Object';

package main;

$SIG{__WARN__} = sub { chomp (my $msg = $_[0]); ok(1, "in __WARN__: $msg"); };
#$SIG{__DIE__} = sub { ok(1, 'in __DIE__'); };

Glib->message (undef, 'whee message');
eval {
Glib->critical (undef, 'whee critical');
Glib->warning (undef, 'whee warning');
};

my $id = 
Glib::Log->set_handler (__PACKAGE__,
                        [qw/ error critical warning message info debug /],
			sub {
				ok(1, "in custom handler $_[1][0]");
			});

Glib->message (__PACKAGE__, 'whee message');
eval {
Glib->critical (__PACKAGE__, 'whee critical');
Glib->warning (__PACKAGE__, 'whee warning');

Glib->log (__PACKAGE__, qw/ warning /, 'whee log warning');

Glib::Log->remove_handler (__PACKAGE__, $id);
};

SKIP: {
	# See <http://bugzilla.gnome.org/show_bug.cgi?id=577137>.
	skip 'using multiple log levels breaks g_log on some platforms', 2
		if (!Glib->CHECK_VERSION(2, 20, 1) &&
		    $Config{archname} =~ /powerpc|amd64|s390/);
	my $id = Glib::Log->set_handler (undef,
		[qw/ error critical warning message info debug /],
		sub {
			ok(1, "in custom handler $_[1][0]");
		});
	Glib->log (undef, [qw/ info debug /], 'whee log warning');
	Glib::Log->remove_handler (undef, $id);
}

# i would expect this to call croak, but it actually just aborts.  :-(
#eval { Glib->error (__PACKAGE__, 'error'); };



# when you try to connect to a non-existant signal, you get a CRITICAL
# log message...
my $object = Foo->new;
{
ok(1, 'attempting to connect a non-existant signal');
local $SIG{__WARN__} = sub { ok( $_[0] =~ /nonexistant/, 'should warn' ); };
$object->signal_connect (nonexistant => sub { ok(0, "shouldn't get here") });
delete $SIG{__WARN__};
}

## try that again with a fatal mask
#Glib::Log->set_always_fatal (['critical', 'fatal-mask']);
#{
#local $SIG{__DIE__} = sub { ok(1, 'should die'); };
#eval {
#$object->signal_connect (nonexistant => sub { ok(0, "shouldn't get here") });
#};
#print "$@\n";
#}

# Check that messages with % chars make it through unaltered and don't cause
# crashes
{
	my $id = Glib::Log->set_handler (
		__PACKAGE__,
		qw/debug/,
		sub { is($_[2], '%s %d %s', 'a message with % chars'); });

	Glib->log (__PACKAGE__, qw/debug/, '%s %d %s');

	Glib::Log->remove_handler (__PACKAGE__, $id);
}

Glib::Log->set_fatal_mask (__PACKAGE__, [qw/ warning message /]);
Glib::Log->set_always_fatal ([qw/ info debug /]);

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

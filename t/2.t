#
# $Header$
#

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 1;
BEGIN { use_ok('Glib') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $obj = new Glib::Object "Glib::Object";

# FIXME need to define an instantiatable subclass of GObject and test out
# ref counting, signals, properties, object data, and all that fun stuff.

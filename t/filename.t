#!/usr/bin/perl
# vim: set filetype=perl :

#
# Test the filename conversion facilities in Glib
#

use strict;
use warnings;
use Glib qw(:functions);
use Test::More tests => 21;

my $filename = "test";

is(Glib->filename_to_unicode($filename), $filename);
is(Glib::filename_to_unicode($filename), $filename);
is(filename_to_unicode($filename), $filename);

is(Glib->filename_from_unicode($filename), $filename);
is(Glib::filename_from_unicode($filename), $filename);
is(filename_from_unicode($filename), $filename);

use Cwd qw(cwd);

my $path = cwd() . "/" . $filename;
my $host = "localhost";
my $expected = "file://$host$path";

is(Glib->filename_to_uri($path, $host), $expected);
is(Glib::filename_to_uri($path, $host), $expected);
is(filename_to_uri($path, $host), $expected);

is(Glib->filename_from_uri($expected), $path);
is(Glib::filename_from_uri($expected), $path);
is(filename_from_uri($expected), $path);

is_deeply([Glib->filename_from_uri($expected)], [$path, $host]);
is_deeply([Glib::filename_from_uri($expected)], [$path, $host]);
is_deeply([filename_from_uri($expected)], [$path, $host]);


SKIP: {
	skip "g_filename_display_name was added glib 2.6.0", 6
		unless Glib->CHECK_VERSION (2, 6, 0);

	ok (Glib::filename_display_name ("test"));
	ok (Glib::filename_display_basename ("test"));

	ok (Glib::filename_display_name ("/tmp/test"));
	ok (Glib::filename_display_basename ("/tmp/test"));

	# should not fail even on invalid stuff
	my $something = "/tmp/test\x{fe}\x{03}invalid";
	print "name: ".Glib::filename_display_name ($something)."\n";
	print "basename: ".Glib::filename_display_basename ($something)."\n";
	ok (Glib::filename_display_name ($something));
	ok (Glib::filename_display_basename ($something));
}

#!/usr/bin/perl
#
# $Id$
#
# Tests for GLib shell utilities taken from upstream testsuite
#

use strict;
use warnings;

use Test::More tests => 2;
use Glib;

subtest "shell_quote" => sub {
	my @quote_tests = (
		[ "", "''" ],
		[ "a", "'a'" ],
		[ "(", "'('" ],
		[ "'", "''\\'''" ],
		[ "'a", "''\\''a'" ],
		[ "a'", "'a'\\'''" ],
		[ "a'a", "'a'\\''a'" ]
	);

	foreach my $test (@quote_tests) {
		my ($inp,$exp) = @$test;
		is Glib::shell_quote ($inp), $exp, "shell_quote \"$inp\"";
	}
};

subtest "shell_unquote" => sub {
	my @unquote_tests = (
		[ "", "" ],
		[ "a", "a" ],
		[ "'a'", "a" ],
		[ "'('", "(" ],
		[ "''\\'''", "'" ],
		[ "''\\''a'", "'a" ],
		[ "'a'\\'''", "a'" ],
		[ "'a'\\''a'", "a'a" ],
		[ "\\\\", "\\" ],
		[ "\\\n", "" ],
		[ "'\\''", undef, ('Glib::Shell::Error', 'bad-quoting') ],
		[ "\"\\\"\"", "\"" ],
		[ "\"", undef, ('Glib::Shell::Error', 'bad-quoting') ],
		[ "'", undef, ('Glib::Shell::Error', 'bad-quoting') ],
		[ "\x22\\\\\"", "\\" ],
		[ "\x22\\`\"", "`" ],
		[ "\x22\\\$\"", "\$" ],
		[ "\x22\\\n\"", "\n" ],
		[ "\"\\'\"", "\\'" ],
		[ "\x22\\\r\"", "\\\r" ],
		[ "\x22\\n\"", "\\n" ]
	);

	foreach my $test (@unquote_tests) {
		my ($inp,$exp,@err) = @$test;
		if (@err) {
			my ($domain,$code) = @err;
			eval { Glib::shell_unquote $inp; };
			ok Glib::Error::matches ($@, $domain, $code), "shell_unquote \"$inp\"";
		} else {
			is Glib::shell_unquote ($inp), $exp, "shell_unquote \"$inp\"";
		}
	}
};

#!/usr/bin/perl

#
# Test the filename conversion facilities in Glib
#

use strict;
use warnings;
use Glib qw(:functions);
use Test::More tests => 15;

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

##
# $Header$
#

use strict;
use warnings;

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

use Test::More tests => 15;
BEGIN { use_ok('Glib') };

#########################

ok (defined (Glib::major_version), 'major_version');
ok (defined (Glib::minor_version), 'minor_version');
ok (defined (Glib::micro_version), 'micro_version');
ok (Glib->CHECK_VERSION(0,0,0), 'CHECK_VERSION pass');
ok (!Glib->CHECK_VERSION(50,0,0), 'CHECK_VERSION fail');
ok (defined (Glib::MAJOR_VERSION), 'MAJOR_VERSION');
ok (defined (Glib::MINOR_VERSION), 'MINOR_VERSION');
ok (defined (Glib::MICRO_VERSION), 'MICRO_VERSION');

print "user name: ".Glib::get_user_name."\n";
print "real name: ".Glib::get_real_name."\n";
print "home dir: ".Glib::get_home_dir."\n";
print "tmp dir: ".Glib::get_tmp_dir."\n";
ok (defined (Glib::get_user_name), "Glib::get_user_name");
ok (defined (Glib::get_real_name), "Glib::get_real_name");
ok (defined (Glib::get_home_dir), "Glib::get_home_dir");
ok (defined (Glib::get_tmp_dir), "Glib::get_tmp_dir");

SKIP: {
  skip "set_application_name is new in glib 2.2.0", 2
    unless Glib->CHECK_VERSION (2,2,0);
  # this will not hold after Gtk2::init, since gtk_init() calls
  # gdk_parse_args() which calls g_set_prgname(argv[0]).
  is (Glib::get_application_name (), undef, 'before any calls to anything');
  my $appname = 'Flurble Foo 2, Electric Boogaloo';
  Glib::set_application_name ($appname);
  is (Glib::get_application_name (), $appname);
}

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

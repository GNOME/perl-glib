#
# KeyFile stuff.
#
use strict;
use Glib ':constants';
use Test::More tests => 20;

my $str = <<__EOK__
#top of the file

[mysection]
intkey=42
stringkey=hello
boolkey=1

[listsection]
intlist=1;1;2;3;5;8;13;
stringlist=Some;Values;In;A;List;
boollist=false;true;false

[locales]
#some string
mystring=Good morning
mystring[it]=Buongiorno
mystring[es]=Buenas dias
mystring[fr]=Bonjour
mystring[de]=Guten Tag
__EOK__
;

SKIP: {
	skip "Glib::KeyFile is new in glib 2.6.0", 20
		unless Glib->CHECK_VERSION (2, 6, 0);
	
	ok (defined Glib::KeyFile->new ());

	my $key_file = Glib::KeyFile->new;
	isa_ok ($key_file, 'Glib::KeyFile');

	my @groups;
	@groups = $key_file->get_groups;
	is (@groups, 0, 'we have no groups');

	ok ($key_file->load_from_data(
			$str,
			[ 'keep-comments', 'keep-translations' ]
		));

	@groups = $key_file->get_groups;
	is (@groups, 3, 'now we have two groups');

	is ($key_file->get_comment, "top of the file\n", 'we reached the top');
	
	my $start_group = 'mysection';
	ok ($key_file->has_group($start_group));
	is ($key_file->get_start_group, $start_group, 'start group');

	ok ($key_file->has_key($key_file->get_start_group, 'stringkey'));
	
	my $intval = 42;
	my $stringval = 'hello';
	my $boolval = TRUE;
	is ($key_file->get_string($start_group, 'stringkey'), $stringval, 'howdy?');
	is ($key_file->get_value($start_group, 'intkey'), $intval, 'the answer');
	is ($key_file->get_integer($start_group, 'intkey'), $intval, 'the answer, reloaded');
	is ($key_file->get_boolean($start_group, 'boolkey'), $boolval, 'we stay true to ourselves');
	
	ok ($key_file->has_group('listsection'));
	
	my @integers = $key_file->get_integer_list('listsection', 'intlist');
	is (@integers, 7, 'fibonacci would be proud');

	my @strings = $key_file->get_string_list('listsection', 'stringlist');
	eq_array (\@strings, ['Some', 'Values', 'In', 'A', 'List'], 'we are proud too');

	my @bools = $key_file->get_boolean_list('listsection', 'boollist');
	is (@bools, 3);
	eq_array (\@bools, [FALSE, TRUE, FALSE]);

	ok ($key_file->has_group('locales'));
	is ($key_file->get_comment('locales', 'mystring'), "some string\n");
	is ($key_file->get_string('locales', 'mystring'), 'Good morning');
	is ($key_file->get_locale_string('locales', 'mystring', 'it'), 'Buongiorno');
}

__END__

Copyright (C) 2005 by the gtk2-perl team (see the file AUTHORS for the
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

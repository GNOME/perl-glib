#!/usr/bin/perl -w
#
# $Header$
#

use strict;
use Test::More tests => 9;
use Glib;


# this is obviously invalid and should result in an exception.
eval { Glib::filename_from_uri 'foo://bar'; };

ok ($@, "\$@ is defined");
isa_ok ($@, "Glib::Error", "it's a Glib exception object");
isa_ok ($@, "Glib::Convert::Error", "specifically, it's a conversion error");
is ($@->code, 4, "numeric code");
is ($@->value, 'bad-uri', "code's nickname");
is ($@->domain, 'g_convert_error', 'error domain (implies class)');
ok ($@->message, "should have an error message, may be translated");
ok ($@->location, "should have an error location, may be translated");
is ($@, $@->message.$@->location, "stringification operator is overloaded");


__END__

Copyright (C) 2003 by the gtk2-perl team (see the file AUTHORS for the
full list).  See LICENSE for more information.

#
# Copyright (c) 2003 by the gtk2-perl team (see the file AUTHORS)
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the 
# Free Software Foundation, Inc., 59 Temple Place - Suite 330, 
# Boston, MA  02111-1307  USA.
#
# $Header$
#

package Glib;

use 5.008;
use strict;
use warnings;

require DynaLoader;
our @ISA = qw(DynaLoader);

our $VERSION = '0.97';

sub dl_load_flags { $^O eq 'darwin' ? 0x00 : 0x01 }

bootstrap Glib $VERSION;

1;

=head1 NAME

Glib - Perl wrappers for the GLib utility and Object libraries

=head1 SYNOPSIS

  use Glib;

=head1 ABSTRACT

This module provides perl access to GLib and GLib's GObject libraries.
GLib is a portability and utility library; GObject provides a generic
type system with inheritance and a powerful signal system.  Together
these libraries are used as the foundation for many of the libraries
that make up the Gnome environment, and are used in many unrelated
projects.

=head1 DESCRIPTION

This wrapper attempts to provide a perlish interface while remaining 
as true as possible to the underlying C API, so that any reference
materials you can find on using GLib may still apply to using the
libraries from perl.  This module also provides facilities for creating
wrappers for other GObject-based libraries.  The L<SEE ALSO> section
contains pointers to all sorts of good information.

=head1 PERL VERSUS C

GLib provides to C programs many of the same facilities Perl offers
natively.  Where GLib's functionality overlaps Perl's, Perl's is favored.
Some concepts have been eliminated entirely, as Perl is a higher-level
language than C.  In other instances we've had to add or change APIs to
make sense in Perl.  Here's a quick run-down:

=head2 Perl Already Does That

The GLib types GList (a doubly-linked list), GSList (singly-linked list),
GHashTable, GArray, etc have all been replaced by native Perl datatypes.  In
fact, many functions which take GLists or arrays simply accept lists on the
Perl stack.  For the most part, GIOChannels are no more functional than Perl
file handles, so you won't see any GIOChannels.  GClosures are not visible at
the Perl level, because Perl code references do the same thing.  Just about any
function taking either a C function pointer or a GClosure will accept a code
reference in Perl.  (In fact, you can probably get away with just a subroutine
name in many spots, provided you aren't using strict subs.)

=head2 Don't Worry About That

Some concepts have been eliminated; you need never worry about
reference-counting on GObjects or having to free GBoxed structures.  Perl is a
garbage-collected language, and we've put a lot of work into making the
bindings take care of memory for you in a way that feels natural to a Perl
developer.  You won't see GValues in Perl (that's just a C structure with Perl
scalar envy, anyway).

=head2 This Is Now That

Other GLib concepts have been converted to an analogous Perl concept.

The GType id will never be seen in Perl, as the package name serves that
purpose.  Several packages corresponding to the GTypes of the fundamental types
have been registered for you:

 G_TYPE_STRING     Glib::String
 G_TYPE_INT        Glib::Int
 G_TYPE_UINT       Glib::Uint
 G_TYPE_DOUBLE     Glib::Double
 G_TYPE_BOOLEAN    Glib::Boolean

The remaining fundamentals (char/uchar, short, float, etc) are left off, since
perl really only has ints, uints, and doubles anyway.  Oh, and we created a
GBoxed type for Perl scalars so you can use scalars where any boxed type would
be allowed (e.g. GtkTreeModel columns):

 Glib::Scalar

Functions that can return false and set a GError in C raise an exception in
Perl (using the string from the GError for $@).  Exceptions are a sticky issue,
so they get their own section.

Enumerations and flags are treated as strings and arrays of strings,
respectively.  GLib provides a way to register nicknames for enumeration
values, and the Perl bindings use these nicknames for the real values, so that
we never have to deal with numbers in Perl.  This can get a little cumbersome
for bitfields, but it's very nice when you forget a flag value, as the bindings
will tell you what values are accepted when you pass something invalid. Also,
the bindings consider the - and _ characters to be equivalent, so that signal
and property names can be properly stringified by the => operator.  For
example, the following are equivalent:

  # property foo-matic of type FooType, using the
  # value FOO_SOMETHING_COOL.  its nickname would be
  # 'something-cool'.  you may use either the full
  # name or the nickname when supplying values to perl.
  $object->set ('foo-matic', 'FOO_SOMETHING_COOL');
  $object->set ('foo_matic', 'something_cool');
  $object->set (foo_matic => 'something-cool');

Beware that Perl will always return to you the nickname form, with the dash.

=head2 It's All the Same

For the most part, the remaining bits of GLib are unchanged.  GMainLoop is now
Glib::MainLoop, GObject is now Glib::Object, GBoxed is now Glib::Boxed, etc.

=head1 EXCEPTIONS

The C language doesn't support exceptions; GLib is a C library, and of course
doesn't support exceptions either.  In Perl, we use die and eval to raise
and trap exceptions as a rather common practice.  So, the bindings have to
work a little black magic behind the scenes to keep GLib from exploding when
the Perl program uses exceptions.  Unfortunately, a little of this magic
has to leak out to where you can see it at the Perl level.

Signal and event handlers are run in an eval context; if an exception occurs
in such a handler and you don't catch it, Perl will report that an error
occurred, and then go on about its business like nothing happened.

You may register subroutines as exception handlers, to be called when such
an exception is trapped.  Another function removes them for you.

  $tag = Glib->install_exception_handler (\&my_handler);
  Glib->remove_exception_handler ($tag);

The exception handler will get a fresh copy of the $@ of the offending
exception on the argument stack, and is expected to return non-zero if the
handler is to remain installed.  If it returns false, the handler will be
removed.

  sub my_handler {
      if ($_[0] =~ m/ftang quisinart/) {
           clean_up_after_ftang ();
      }
      1; # live to fight another day
  }

You can register as many handlers as you like; they will all run
independently.

An important thing to remember is that exceptions do not cross main loops.
In fact, exceptions are completely distinct from main loops.  If you need
to quit a main loop when an exception occurs, install a handler that quits
the main loop, but also ask yourself if you are using exceptions for flow
control or exception handling.

=head1 LOG MESSAGES

GLib's g_log function provides a flexible mechanism for reporting messages,
and most GLib-based C libraries use this mechanism for warnings, assertions,
critical messages, etc.  The Perl bindings offer a mechanism for routing
these messages through Perl's native system, warn() and die().  Extensions
should register the log domains they wrap for this to happen fluidly.
[FIXME say more here]

=head1 SEE ALSO

How to create your own gobject subclasses:

  Glib::Objects::Subclass

This module is the basis for the Gtk2 module, so most of the references
you'll be able to find about this one are tied to that one.  The perl
interface aims to be very simply related to the C API, so see the C API
reference documentation:

  GLib - http://developer.gnome.org/doc/API/2.0/glib/
  GObject - http://developer.gnome.org/doc/API/2.0/gobject/

This module serves as the foundation for any module which needs to bind
GLib-based C libraries to perl.

  Glib::PkgConfig - simple interface to pkg-config for developers
  Glib::devel - Binding developer's overview of Glib's internals
  Glib::xsapi - internal API reference for GPerl
  Yet another document, available separately, ties it all together:
    http://gtk2-perl.sourceforge.net/doc/binding_howto.pod.html

For gtk2-perl itself, see its website at

  gtk2-perl - http://gtk2-perl.sourceforge.net/

A mailing list exists for discussion of using gtk2-perl and related
modules.  Archives and subscription information are available at
http://lists.gnome.org/.


=head1 AUTHORS

muppet, E<lt>scott at asofyet dot orgE<gt>, who borrowed heavily from the work
of Göran Thyni, E<lt>gthyni at kirra dot netE<gt> and Guillaume Cottenceau
E<lt>gc at mandrakesoft dot comE<gt> on the first gtk2-perl module, and from
the sourcecode of the original gtk-perl and pygtk projects.  Marc Lehmann
E<lt>pcg at goof dot comE<gt> did lots of great work on the magic of making
Glib::Object wrapper and subclassing work like they should.

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by muppet and the gtk2-perl team

This library is free software; you can redistribute it and/or modify
it under the terms of the Lesser General Public License (LGPL).  For 
more information, see http://www.fsf.org/licenses/lgpl.txt

=cut

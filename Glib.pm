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
use Carp;

require Exporter;
require DynaLoader;
use AutoLoader;

our @ISA = qw(Exporter DynaLoader);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Glib ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

our $VERSION = '0.25';

sub dl_load_flags { 0x01 }

bootstrap Glib $VERSION;

=head1 NAME

Glib - Perl wrappers for the GLib utility and Object libraries

=head1 SYNOPSIS

  use Glib;
  blah blah blah

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
libraries from perl.  Where GLib's functionality overlaps perl's,
perl's is favored; for example, you will find perl lists and arrays in
place of GSList or GList objects.  Some concepts have been eliminated;
you need never worry about reference-counting on GObjects or GBoxed
structures.  Other concepts have been converted to a perlish analogy;
the GType id will never be seen in perl, as the package name serves
that purpose.  [FIXME link to a document describing this stuff in detail.]

This module also provides facilities for creating wrappers for other
GObject-based libraries.  [FIXME link to a developer's doc]

=head2 THE Glib::Object::Base CLASS

This class is automatically added as a base class to perl classes derived
from GTypes.

It provides some default implementations for the methods required for all
GObjects.

=over 4

=cut

package Glib::Object::Base;

=item $class->new (attr => value, ...)

The default constructor just calls C<Glib::Object::new>, which allows you
to set properties on the newly created object. This is done because many
C<new> methods inherited by Gtk2 or other libraries don't have C<new>
methods suitable for subclassing.

=cut

*new = \&Glib::Object::new; # be efficient

=item INIT_INSTANCE $object    [not a method]

C<INIT_INSTANCE> is called on each class in the hierarchy as the object is
being created (i.e., from C<Glib::Object::new> or our default C<new>). Use
this function to initialize any member data. The default implementation
will leave the object untouched.

Remember that this is a I<function>, not a method, so calling the
superclass is actually wrong.

=cut

sub INIT_INSTANCE {}

=item $object->GET_PROPERTY ($prop_id, $pspec)

Get a property value, see C<SET_PROPERTY>.

The default implementation looks like this:

   my ($self, $prop_id, $pspec) = @_;
   return $self->{$pspec->get_name};

=item $object->SET_PROPERTY ($prop_id, $pspec, $newval)

C<GET_PROPERTY> and C<SET_PROPERTY> are called whenever somebody does
C<< $object->get ($propname) >> or C<< $object->set ($propname => $newval) >>
(from other languages, too). This is your hook that allows you to
store/fetch properties in any way you need to (maybe you have to calculate
something or read a file).

C<GET_PROPERTY> is different from a C get_property method in that the
perl method returns the retrieved value. For symmetry, the C<$newval>
and C<$pspec> args on C<SET_PROPERTY> are swapped from the C usage. The
default get and set methods store property data in the object as hash
values named for the parameter name.

Remember to call the SUPER method for unhandled properties.

The default C<SET_PROPERTY> looks like this:

   my ($self, $prop_id, $pspec, $newval) = @_;
   $self->{$pspec->get_name} = $newval;

=cut

sub GET_PROPERTY {
	my ($self, $prop_id, $pspec) = @_;
	return $self->{$pspec->get_name};
}

sub SET_PROPERTY {
	my ($self, $prop_id, $pspec, $newval) = @_;
	#warn "Glib::Object::Base::SET_PROPERTY : @_";
	$self->{$pspec->get_name} = $newval;
}

=item $object->FINALIZE_INSTANCE [method]

C<FINALIZE_INSTANCE> is called as the GObject is being finalized, that is, as
it's being really destroyed. This is independent of DESTROY on the perl
object; in fact, you must I<NOT> override C<DESTROY> (it's not useful to
you, in any case, as it is being called multiple times!).

Use this hook to release anything you have to clean up manually.
FINALIZE_INSTANCE is an overridden method, so keep in mind that you will
have to chain manually to $self->SUPER::FINALIZE_INSTANCE.

Default finalizer has nothing to do, and does not chain, so as to avoid an
infinite loop (it chains at a lower level).

=cut

sub FINALIZE_INSTANCE {
	# nop
}

=item $object->DESTROY

Don't I<ever> overwrite, use C<FINALIZE_INSTANCE> instead.

The DESTROY method of all perl classes derived from GTypes is
implemented in the Glib module and (ab-)used for it's own internal
purposes. Overwriting it is not useful as it will be called
E<multiple> times, and often long before the object actually gets
destroyed. Overwriting might be very harmful to your program, so I<never>
do that. Especially watch out for other classes in your ISA tree.

=back

=cut

1;


=head1 SEE ALSO

Other PMs installed with this module:

  Glib::PkgConfig - simple interface to pkg-config for developers

This module is the basis for the Gtk2 module, so most of the references
you'll be able to find about this one are tied to that one.  The perl
interface aims to be very simply related to the C API, so see the C API
reference documentation:

  GLib - http://developer.gnome.org/doc/API/2.0/glib/
  GObject - http://developer.gnome.org/doc/API/2.0/gobject/

For gtk2-perl itself, see its website at

  gtk2-perl - http://gtk2-perl.sourceforge.net/

A mailing list exists for discussion of using gtk2-perl and related
modules.  Archives and subscription information is available at
http://lists.gnome.org/.


=head1 AUTHORS

muppet, E<lt>scott at asofyet dot orgE<gt>, who borrowed heavily from the work
of Göran Thyni, E<lt>gthyni at kirra dot netE<gt> and Guillaume Cottenceau
E<lt>gc at mandrakesoft dot comE<gt> on the first gtk2-perl module, and from
the sourcecode of the original gtk-perl and pygtk projects.

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by muppet and the gtk2-perl team

This library is free software; you can redistribute it and/or modify
it under the terms of the Lesser General Public License (LGPL).  For 
more information, see http://www.fsf.org/licenses/lgpl.txt

=cut

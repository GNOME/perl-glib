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

package Glib::Object::Subclass;

use Glib;

=head1 NAME

Glib::Object::Subclass - create gobject classes in perl

=head1 SYNOPSIS

  use Glib::Object::Subclass
     Glib::Object,        # parent class
     signals    =>
        {
            something_changed => {
               flags       => [qw(run-first)],
               return_type => undef,
               param_types => [],
            },

        },
     properties => [
        Glib::ParamSpec->string (
           'some_string',
           'Some String Property',
           'This property is a string that is used as an example',
           'default value',
           [qw/readable writable/]
        ),
     ];

=head1 DESCRIPTION

This module allows you to create your own gobject classes, which is useful
to e.g. implement your own Gtk2 widgets.

It doesn't "export" anything into your namespace, but acts more like
a pragmatic module that modifies your class to make it work as a
GObjectClass.

There are three different issues that this module tries to solve:

=over 4

=item * The gobject type and class system and the perl class system work
slightly different.

=item * Classes must be registered before they can be used.

=item * Some convinience methods to make GObjectClasses look more like
normal perl objects.

=back

=head2 USAGE

This module works similar to the C<use base> pragma in that it registers
the current package as a subclass of some other class (which must be a
GObjectClass implemented either in C or some other language).

TODO: document it.

=head2 OBJECT METHODS AND FUNCTIONS

The following methods are either added to your class on request (not
yet implemented), or by default unless your own class implements them
itself. This means that all these methods and functions will get sensible
default implementations unless explicitly overwritten by you (by defining
your own version).

Except for C<new>, all of the following are I<functions> and no
I<methods>. That means that you should I<not> call the superclass
method. Instead, the GObject system will call these functions per class as
required, emulating normal inheritance.

=over 4

=item $class->new (attr => value, ...)

The default constructor just calls C<Glib::Object::new>, which allows you
to set properties on the newly created object. This is done because many
C<new> methods inherited by Gtk2 or other libraries don't have C<new>
methods suitable for subclassing.

=item INIT_INSTANCE $self                                 [not a method]

C<INIT_INSTANCE> is called on each class in the hierarchy as the object is
being created (i.e., from C<Glib::Object::new> or our default C<new>). Use
this function to initialize any member data. The default implementation
will leave the object untouched.

=cut

=item GET_PROPERTY $self, $pspec                          [not a method]

Get a property value, see C<SET_PROPERTY>.

The default implementation looks like this:

   my ($self, $pspec) = @_;
   return $self->{$pspec->get_name};

=item SET_PROPERTY $self, $newval                         [not a method]

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

The default C<SET_PROPERTY> looks like this:

   my ($self, $pspec, $newval) = @_;
   $self->{$pspec->get_name} = $newval;

=item FINALIZE_INSTANCE $self                             [not a method]

C<FINALIZE_INSTANCE> is called as the GObject is being finalized, that is,
as it's being really destroyed. This is independent of the more common
DESTROY on the perl object; in fact, you must I<NOT> override C<DESTROY>
(it's not useful to you, in any case, as it is being called multiple
times!).

Use this hook to release anything you have to clean up manually.
FINALIZE_INSTANCE will be called for each perl instance, in reverse order
of construction.

The default finalizer does nothing.

=item $object->DESTROY           [DO NOT OVERWRITE]

Don't I<ever> overwrite C<DESTROY>, use C<FINALIZE_INSTANCE> instead.

The DESTROY method of all perl classes derived from GTypes is
implemented in the Glib module and (ab-)used for it's own internal
purposes. Overwriting it is not useful as it will be called
I<multiple> times, and often long before the object actually gets
destroyed. Overwriting might be very harmful to your program, so I<never>
do that. Especially watch out for other classes in your ISA tree.

=back

=cut

*new = \&Glib::Object::new;

sub GET_PROPERTY {
   my ($self, $pspec) = @_;
   $self->{$pspec->get_name};
}

sub SET_PROPERTY {
   my ($self, $pspec, $newval) = @_;
   $self->{$pspec->get_name} = $newval;
}

sub import {
   my ($self, $superclass, %arg) = @_;
   my $class = caller;

   my $signals    = $arg{signals}    || {};
   my $properties = $arg{properties} || [];

   # the CHECK callback will be executed after the module is compiled
   my $check = sub {
      # "optionally" supply defaults
      for (qw(new GET_PROPERTY SET_PROPERTY)) {
         defined &{"$class\::$_"}
            or *{"$class\::$_"} = \&$_;
      }
   };
   eval "package $class; CHECK { &\$check }";

   Glib::Type->register(
      $superclass, $class,
      signals    => $signals,
      properties => $properties,
   );
}

1;

=head1 SEE ALSO

  GObject - http://developer.gnome.org/doc/API/2.0/gobject/

=head1 AUTHORS

Marc Lehmann E<lt>pcg@goof.comE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by muppet and the gtk2-perl team

This library is free software; you can redistribute it and/or modify
it under the terms of the Lesser General Public License (LGPL).  For 
more information, see http://www.fsf.org/licenses/lgpl.txt

=cut


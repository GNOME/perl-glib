# Copyright (C) 2003 by the gtk2-perl team (see the file AUTHORS for the full
# list)
# 
# This library is free software; you can redistribute it and/or modify it under
# the terms of the GNU Library General Public License as published by the Free
# Software Foundation; either version 2.1 of the License, or (at your option)
# any later version.
# 
# This library is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU Library General Public License for
# more details.
# 
# You should have received a copy of the GNU Library General Public License
# along with this library; if not, write to the Free Software Foundation, Inc.,
# 59 Temple Place - Suite 330, Boston, MA  02111-1307  USA.
#
# $Header$
#

package Glib::Object::Subclass;

use Glib;

=head1 NAME

Glib::Object::Subclass - register a perl class as a gobjectclass

=head1 SYNOPSIS

  use Glib::Object::Subclass
     Some::Base::Class::,   # parent class, derived from Glib::Object
     signals => {
            something_changed => {
               class_closure => sub { do_something_fun () },
               flags         => [qw(run-first)],
               return_type   => undef,
               param_types   => [],
            },
            some_existing_signal => \&class_closure_override,
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
slightly differently.

=item * Classes must be registered before they can be used.

=item * Some convenience methods to make GObjectClasses look more like
normal perl objects.

=back

You may be wondering why you can't just bless a Glib::Object into a
different package and add some subs.  Well, if you aren't interested 
in object parameters, signals, or having your new class interoperate
transparently with other GObject-based modules (e.g., Gtk2 and friends),
then you can just re-bless.

However, a GObject's signals, properties, and virtual functions are
specific to its GObjectClass.  If you want to create a new GObject
which was a derivative of GtkDrawingArea, but added a new signal,
you must create a new GObjectClass to which to add the new signal.
If you don't, then I<all> of the GtkDrawingAreas in your application
will get that new signal!

Thus, the only way to create a new signal or object property in the
perl bindings for Glib is to register a new subclass with Glib::Type.
This module is a perl-developer-friendly interface to this bit of
paradigm mismatch.

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

=item SET_PROPERTY $self, $pspec, $newval                 [not a method]

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

=head1 PROPERTIES

To create gobject properties, supply a list of Glib::ParamSpec objects as the
value for the key 'properties'.  There are lots of different paramspec
constructors, documented in the C API reference's Parameters and Values page.

TODO:  put a list here with the proper perl syntax for each

=head1 SIGNALS

Creating new signals for your new object is easy.  Just provide a hash
of signal names and signal descriptions under the key 'signals'.  Each
signal description is also a hash, with a few expected keys.  All the 
keys are allowed to default.

=over

=item flags => GSignalFlags

If not present, assumed to be run-first

=item param_types => reference to a list of package names

If not present, assumed to be empty (no parameters)

=item class_closure => reference to a subroutine to call as the class closure.

may also be a string interpreted as the name of a subroutine to call, but you
should be very very very careful about that.

If not present, the library will attempt to call the method named
"do_signal_name" for the signal "signal_name" (uses underscores).

You'll want to be careful not to let this handler method be a publically
callable method, or one that has the name name as something that emits the
signal.  Due to the funky ways in which Glib is different from Perl, the
class closures I<should not> inherit through normal perl inheritance.

=item return_type => package name for return value.

If undefined or not present, the signal expects no return value.  if defined,
the signal is expected to return a value; flags must be set such that the
signal does not run only first (at least use 'run-last').

=item accumulator => signal return value accumulator

quoting the Glib manual: "The signal accumulator is a special callback function
that can be used to collect return values of the various callbacks that are
called during a signal emission."

If not specified, the default accumulator is used, and you just get the 
return value of the last handler to run.

Accumulators are not really documented very much in the C reference, and
the perl interface here is slightly different, so here's an inordinate amount
of detail for this arcane feature:

The accumulator function is called for every handler.  It is given three
arguments: the signal invocation hint as an anonymous hash (containing the
signal name, notably); the current accumulated return value; and the value
returned by the most recent handler.  The accumulator must return two values:
a boolean value determining whether signal emission should continue (false
stops the emission), and the new value for the accumulated return value.
(This is different from the C version, which writes through the return_accu.)

=back

=head1 OVERRIDING BASE METHODS

Glib pulls some fancy tricks with function pointers to implement methods
in C.  This is not very language-binding-friendly, as you might guess.

However, as described above, every signal allows a "class closure"; you
may override thie class closure with your own function, and you can chain
from the overridden method to the original.  This serves to implement
virtual overrides for language bindings.

So, to override a method, you supply a subroutine reference instead of a
signal description hash as the value for the name of the existing signal
in the "signals" hash described in the SIGNALs section.

  # override some important widget methods:
  use Glib::Object::Subclass
        Gtk2::Widget::,
	signals => {
		expose_event => \&expose_event,
		configure_event => \&configure_event,
		button_press_event => \&button_press_event,
		button_release_event => \&button_release_event,
		motion_notify_event => \&motion_notify_event,
		# note the choice of names here... see the discussion.
		size_request => \&do_size_request,
	}

It's important to note that the handlers you supply for these are
class-specific, and that normal perl method inheritance rules are not
followed to invoke them from within the library.  However, perl code can
still find them!  Therefore it's rather important that you choose your
handlers' names carefully, avoiding any public interfaces that you might
call from perl.  Case in point, since size_request is a widget method, i
chose do_size_request as the override handler.

=head1 SEE ALSO

  GObject - http://developer.gnome.org/doc/API/2.0/gobject/

=head1 AUTHORS

Marc Lehmann E<lt>pcg@goof.comE<gt>, muppet E<lt>scott at asofyet dot orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by muppet and the gtk2-perl team

This library is free software; you can redistribute it and/or modify
it under the terms of the Lesser General Public License (LGPL).  For 
more information, see http://www.fsf.org/licenses/lgpl.txt

=cut


/*
 * Copyright (c) 2003 by the gtk2-perl team (see the file AUTHORS)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the 
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330, 
 * Boston, MA  02111-1307  USA.
 *
 * $Header$
 */

=head2 GClosure / GPerlClosure

GPerlClosure is a wrapper around the gobject library's GClosure with
special handling for marshalling perl subroutines as callbacks.
This is specially tuned for use with GSignal and stuff like io watch,
timeout, and idle handlers.

For generic callback functions, which need parameters but do not get
registered with the type system, this is sometimes overkill.  See
GPerlCallback, below.

=over

=cut

#include "gperl.h"
#include <gobject/gvaluecollector.h>


static void
gperl_closure_invalidate (gpointer data,
			  GClosure * closure)
{
	GPerlClosure * pc = (GPerlClosure *)closure;
#ifdef NOISY
	warn ("Invalidating closure for %s\n", pc->name);
#endif
	if (pc->callback) {
		SvREFCNT_dec (pc->callback);     
		pc->callback = NULL;
	}
	if (pc->data) {
		SvREFCNT_dec (pc->data);
		pc->data = NULL;
	}
}

static void
gperl_closure_marshal (GClosure * closure,
		       GValue * return_value,
		       guint n_param_values,
		       const GValue * param_values,
		       gpointer invocation_hint,
		       gpointer marshal_data)
{
	int flags;
	guint i;
	GPerlClosure *pc = (GPerlClosure *)closure;
	SV * data;
	SV * instance;
#ifndef PERL_IMPLICIT_CONTEXT
	dSP;
#else
	SV **SP;

	/* make sure we're executed by the same interpreter that created
	 * the closure object. */
	PERL_SET_CONTEXT (marshal_data);

	SPAGAIN;
#endif

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);

	if (n_param_values == 0) {
		data = pc->data;
	} else {
		/*
		 * complicateder and complicateder...
		 * if the closure is set for swap data, we need to swap
		 * out param_values[0] (the "instance") with pc->data.
		 */
		if (GPERL_CLOSURE_SWAP_DATA (pc)) {
			/* swap instance and data */
			data     = gperl_sv_from_value (param_values);
			instance = pc->data;
		} else {
			/* normal */
			instance = gperl_sv_from_value (param_values);
			data     = pc->data;
		}

		/* of course, this can leave us with no instance.  :-/ */
		if (!instance)
			instance = &PL_sv_undef;

		/* the instance is always the first item in @_ */
		XPUSHs (instance);

		/* the rest of the params should be quite straightforward. */
		for (i = 1; i < n_param_values; i++) {
			SV * arg;
#ifdef NOISY
			warn ("examining name: %s type: %s fundtype: %s\n",
			      pc->name,
			      g_type_name (G_VALUE_TYPE (param_values + i)),
			      g_type_name (G_TYPE_FUNDAMENTAL (G_VALUE_TYPE (param_values + i))));
#endif
		       arg = gperl_sv_from_value ((GValue*) param_values + i);
		       if (!arg) {
			       warn ("[gperl_closure_marshal] Warning, failed to convert object from value for closure invocation: number: %d type: %s fundtype: %s\n",
				     i,
				     g_type_name (G_VALUE_TYPE (param_values + i)),
				     g_type_name (G_TYPE_FUNDAMENTAL (G_VALUE_TYPE (param_values + i))));
				arg = &PL_sv_undef;
			}
			/* make these mortal as they go onto the stack */
			XPUSHs (sv_2mortal (arg));
		}
	}
	if (data)
		XPUSHs (data);
	PUTBACK;

	flags = return_value ? G_SCALAR : G_DISCARD;

	call_sv (pc->callback, flags | G_EVAL);

	if (SvTRUE (ERRSV))
		gperl_run_exception_handlers ();

	if (return_value && G_VALUE_TYPE (return_value)) {
		SPAGAIN;
		gperl_value_from_sv (return_value, POPs);
	}

	/*
	 * clean up 
	 */

	FREETMPS;
	LEAVE;
}


=item GClosure * gperl_closure_new (SV * callback, SV * data, gboolean swap)

Create and return a new GPerlClosure.  I<callback> and I<data> will be copied
for storage; I<callback> must not be NULL.  If I<swap> is TRUE, I<data> will be
swapped with the instance during invocation (this is used to implement
g_signal_connect_swapped()).

If compiled under a thread-enabled perl, the closure will be created and
marshaled in such a way as to ensure that the same interpreter which created
the closure will be used to invoke it.

=cut
GClosure *
gperl_closure_new (SV * callback,
		   SV * data,
		   gboolean swap)
{
	GPerlClosure *closure;
	g_return_val_if_fail (callback != NULL, NULL);

	closure = (GPerlClosure*) g_closure_new_simple (sizeof (GPerlClosure), 
							NULL);
	g_closure_add_invalidate_notifier ((GClosure*) closure, 
					   NULL, gperl_closure_invalidate);
#ifndef PERL_IMPLICIT_CONTEXT
	g_closure_set_marshal ((GClosure*) closure, gperl_closure_marshal);
#else
	/* make sure the closure gets executed by the same interpreter that's
	 * creating it now; gperl_closure_marshal will interpret the 
	 * marshal_data as the proper aTHX. */
	g_closure_set_meta_marshal ((GClosure*) closure, aTHX,
	                            gperl_closure_marshal);
#endif

	/* 
	 * we have to take full copies of these SVs, rather than just
	 * SvREFCNT_inc'ing them, to avoid some bizarre things that can
	 * happen in special cases.   see the notes in perlcall section
	 * 'Using call_sv' for more info
	 */
	closure->callback = (callback && callback != &PL_sv_undef)
	                  ? newSVsv (callback)
	                  : NULL;

	closure->data = (data && data != &PL_sv_undef)
	              ? newSVsv (data)
	              : NULL;

	closure->swap = swap;

	return (GClosure*)closure;
}


=back

=head2 GPerlCallback

generic callback functions usually get invoked directly, and are not passed
parameter lists as GValues.  we could very easily wrap up such generic
callbacks with something that converts the parameters to GValues and then
channels everything through GClosure, but this has two problems:  1) the above
implementation of GClosure is tuned to marshalling signal handlers, which
always have an instance object, and 2) it's more work than is strictly
necessary.

additionally, generic callbacks aren't always kind to the GClosure paradigm.

so, here's GPerlCallback, which is designed specifically to run generic
callback functions.  it reads parameters off the C stack and converts them into
parameters on the perl stack.  (it uses the GValue to/from SV mechanism to do
so, but doesn't allocate any temps on the heap.)  the callback object itself
stores the parameter type list.

unfortunately, since the data element is always last, but the number of
arguments is not known until we have the callback object, we can't pass
gperl_callback_invoke directly to functions requiring a callback; you'll have
to write a proxy callback which calls gperl_callback_invoke.

=over

=item GPerlCallback * gperl_callback_new (SV * func, SV * data, gint n_params, GType param_types[], GType return_type)

Create and return a new GPerlCallback; use gperl_callback_destroy when you are
finished with it.

I<func>: perl subroutine to call.  this SV will be copied, so don't worry about
reference counts.  must B<not> be #NULL.

I<data>: scalar to pass to I<func> in addition to all other arguments.  the SV
will be copied, so don't worry about reference counts.  may be #NULL.

I<n_params>: the number of elements in I<param_types>.

I<param_types>: the #GType of each argument that should be passed from the
invocation to I<func>.  may be #NULL if I<n_params> is zero, otherwise it must
be I<n_params> elements long or nasty things will happen.  this array will be
copied; see gperl_callback_invoke() for how it is used.

I<return_type>: the #GType of the return value, or 0 if the function has void
return.

=cut
GPerlCallback *
gperl_callback_new (SV    * func,
                    SV    * data,
                    gint    n_params,
                    GType   param_types[],
		    GType   return_type)
{
	GPerlCallback * callback;

	callback = g_new0 (GPerlCallback, 1);

	/* copy the scalars, so we still have them when the time comes to
	 * be invoked.  see the perlcall manpage for more information. */
	callback->func = newSVsv (func);
	if (data)
		callback->data = newSVsv (data);

	callback->n_params = n_params;

	if (callback->n_params) {
		if (!param_types)
			croak ("n_params is %d but param_types is NULL in gperl_callback_new", n_params);
		callback->param_types = g_new (GType, n_params);
		memcpy (callback->param_types, param_types,
		        n_params * sizeof (GType));
	}

	callback->return_type = return_type;

#ifdef PERL_IMPLICIT_CONTEXT
	callback->priv = aTHX;
#endif

	return callback;
}


=item void gperl_callback_destroy (GPerlCallback * callback)

Dispose of I<callback>.

=cut
void
gperl_callback_destroy (GPerlCallback * callback)
{
#ifdef NOISY
	warn ("gperl_callback_destroy 0x%p", callback);
#endif
	if (callback) {
		if (callback->func) {
			SvREFCNT_dec (callback->func);
			callback->func = NULL;
		}
		if (callback->data) {
			SvREFCNT_dec (callback->data);
			callback->data = NULL;
		}
		if (callback->param_types) {
			g_free (callback->param_types);
			callback->n_params = 0;
			callback->param_types = NULL;
		}
		g_free (callback);
	}
}


=item void gperl_callback_invoke (GPerlCallback * callback, GValue * return_value, ...)

Marshall the variadic parameters according to I<callback>'s param_types, and
then invoke I<callback>'s subroutine in scalar context, or void context if the
return type is G_TYPE_VOID.  If I<return_value> is not NULL, then value
returned (if any) will be copied into I<return_value>.

A typical callback handler would look like this:

  static gint
  real_c_callback (Foo * f, Bar * b, int a, gpointer data)
  {
          GPerlCallback * callback = (GPerlCallback*)data;
          GValue return_value = {0,};
          gint retval;
          g_value_init (&return_value, callback->return_type);
          gperl_callback_invoke (callback, &return_value,
                                 f, b, a);
          retval = g_value_get_int (&return_value);
          g_value_unset (&return_value);
          return retval;
  }



=cut
void
gperl_callback_invoke (GPerlCallback * callback,
                       GValue * return_value,
                       ...)
{
	va_list var_args;
#ifndef PERL_IMPLICIT_CONTEXT
	dSP;
#else
	SV ** SP;

	PERL_SET_CONTEXT (callback->priv);

	SPAGAIN;
#endif

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);

	va_start (var_args, return_value);

	/* put args on the stack */
#ifdef NOISY
	warn ("/* put args on the stack */\n");
#endif
	if (callback->n_params > 0) {
		int i;

		for (i = 0 ; i < callback->n_params ; i++) {
			gchar * error = NULL;
			GValue v = {0, };
			SV * sv;
			g_value_init (&v, callback->param_types[i]);
			G_VALUE_COLLECT (&v, var_args, G_VALUE_NOCOPY_CONTENTS,
			                 &error);
			if (error) {
				SV * errstr;
				/* this should only happen if you've
				 * created the callback incorrectly */
				/* we modified the stack -- we need to make 
				 * sure perl sees that! */
				PUTBACK;
				errstr = newSVpvn (error, 0);
				g_free (error);
				/* this won't return */
				croak (SvPV_nolen (errstr));
			}
			sv = gperl_sv_from_value (&v);
			if (!sv) {
				/* this should be very rare, too. */
				PUTBACK;
				croak ("failed to convert GValue to SV");
			}
			XPUSHs (sv_2mortal (sv));
		}
	}
	if (callback->data)
		/* my thinking on why i can just push this SV here...
		 * if nobody keeps a reference to it (in the called function),
		 * its refcount will be unaffected.  if they do take a ref,
		 * that ref will be released at the end of that function.
		 * so it just works out.  if any of this is untrue, change
		 * this to XPUSHs (sv_2mortal (newSVsv (callback->data))); */
		XPUSHs (callback->data);

	va_end (var_args);

	PUTBACK;

	/* invoke the callback */
#ifdef NOISY
	warn ("/* invoke the callback */\n");
#endif
	if (return_value && G_VALUE_TYPE (return_value)) {
		if (1 != call_sv (callback->func, G_SCALAR))
			croak ("callback returned more than one value in "
			       "scalar context --- something really bad "
			       "is happening");
		SPAGAIN;
		gperl_value_from_sv (return_value, POPs);
	} else {
#ifdef NOISY
		warn ("calling call_sv\n");
#endif
		call_sv (callback->func, G_DISCARD);
	}

	/* clean up */
#ifdef NOISY
	warn ("/* clean up */\n");
#endif

	FREETMPS;
	LEAVE;
}


#if 0
static const char *
dump_callback (GPerlCallback * c)
{
	SV * sv = newSVpvf ("{%d, [", c->n_params);
	int i;
	for (i = 0 ; i < c->n_params ; i++)
		sv_catpvf (sv, "%s%s", g_type_name (c->param_types[i]),
		           (i+1) == c->n_params ? "" : ", ");
	sv_catpvf (sv, "], %s, %s[%d], %s[%d], 0x%p}",
	           g_type_name (c->return_type),
		   SvPV_nolen (c->func), SvREFCNT (c->func), 
		   SvPV_nolen (c->data), SvREFCNT (c->data),
		   c->priv);
	sv_2mortal (sv);
	return SvPV_nolen (sv);
}

#endif






=back

=head2 Exception Handling

Like Event, Tk, and most other callback-using, event-based perl modules,
Glib traps exceptions that happen in callbacks.  To enable your code to
do something about these exceptions, Glib stores a list of exception
handlers which will be called on the trapped exceptions.  This is
completely distinct from the $SIG{__DIE__} mechanism provided by Perl
itself, for various reasons (not the least of which is that the Perl
docs and source code say that $SIG{__DIE__} is intended for running as
the program is about to exit, and other behaviors may be removed in the
future (apparently a source of much debate on p5p)).

=over

=cut


typedef struct {
	gulong     tag;
	GClosure * closure;
} ExceptionHandler;

static GSList * exception_handlers = NULL;
G_LOCK_DEFINE_STATIC (exception_handlers);

/* this is modified only behind the exception_handlers lock. */
static gboolean in_exception_handler = FALSE;




=item int gperl_install_exception_handler (GClosure * closure)

Install a GClosure to be executed when gperl_closure_invoke() traps an
exception.  The closure should return boolean (TRUE if the handler should
remain installed) and expect to receive a perl scalar.  This scalar will be
a private copy of ERRSV ($@) which the handler can mangle to its heart's
content.

The return value is an integer id tag that may be passed to
gperl_removed_exception_handler().

=cut
int
gperl_install_exception_handler (GClosure * closure)
{
	static int tag = 0;
	ExceptionHandler * h;

	h = g_new0 (ExceptionHandler, 1);

	G_LOCK (exception_handlers);

	h->tag = ++tag;
	h->closure = g_closure_ref (closure);
	g_closure_sink (closure);

	exception_handlers = g_slist_append (exception_handlers, h);

	G_UNLOCK (exception_handlers);

	return h->tag;
}

void
exception_handler_free (ExceptionHandler * h)
{
	g_closure_unref (h->closure);
	g_free (h);
}

static void
remove_exception_handler_unlocked (int tag)
{
	GSList * i;

	for (i = exception_handlers ; i != NULL ; i = i->next) {
		ExceptionHandler * h = (ExceptionHandler*) i->data;
		if (h->tag == tag) {
			exception_handler_free (h);
			exception_handlers =
				g_slist_delete_link (exception_handlers, i);
			break;
		}
	}
}


=item void gperl_remove_exception_handler (int tag)

Remove the exception handler identified by I<tag>, as returned by
gperl_install_exception_handler().  If I<tag> cannot be found, this
does nothing.

WARNING:  this function locks a global data structure, so do NOT call
it recursively.  also, calling this from within an exception handler will
result in a deadlock situation.  if you want to remove your handler just
have it return FALSE.

=cut
void
gperl_remove_exception_handler (int tag)
{
	G_LOCK (exception_handlers);
	remove_exception_handler_unlocked (tag);
	G_UNLOCK (exception_handlers);
}


static void
warn_of_ignored_exception (const char * message)
{
	/* there's a bit of extra nastiness here to strip the trailing
	 * newline from the contents of ERRSV for printing.
	 * TODO verify that this is not clobbering $_.
	 */
	ENTER;
	SAVETMPS;
	sv_setsv (DEFSV, ERRSV);
	eval_pv ("s/^/***   /mg", FALSE);
	eval_pv ("s/\n$//s", FALSE);
	warn ("*** %s:\n"
	      "%s\n"
	      "***  ignoring",
	      message,
	      SvPV_nolen (DEFSV));

	FREETMPS;
	LEAVE;
}

=item void gperl_run_exception_handlers (void)

Invoke whatever exception handlers are installed.  You will need this if
you have written a custom marshaler.  Uses the value of the global ERRSV.

=cut
void
gperl_run_exception_handlers (void)
{
	GSList * i, * this;
	int n_run = 0;
	/* to avoid problems with handlers that fiddle with the value of
	 * the global $@, we'll pass a copy of $@ to all the handlers
	 * on the stack.  this way we know they all get the same one, and
	 * they can do whatever they want to it without actually affecting
	 * anyone else. */
	SV * errsv = newSVsv (ERRSV);

	if (in_exception_handler) {
		warn_of_ignored_exception ("died in an exception handler");
		return;
	}

	G_LOCK (exception_handlers);

	++in_exception_handler;

	/* call any registered handlers */
	for (i = exception_handlers ; i != NULL ; /* in loop */) {
		ExceptionHandler * h = (ExceptionHandler *) i->data;
		GValue param_values = {0, };
		GValue return_value = {0, };
		g_value_init (&param_values, GPERL_TYPE_SV);
		g_value_init (&return_value, G_TYPE_BOOLEAN);
		/* this will duplicate errsv each time, so that all
		 * callbacks get the same value. */
		g_value_set_boxed (&param_values, errsv);
		g_closure_invoke (h->closure, &return_value,
		                  1, &param_values, NULL);
		this = i;
		i = i->next;
		g_assert (i != this);
		if (!g_value_get_boolean (&return_value)) {
#ifdef NOISY
			warn ("handler %d returned FALSE, removing\n", h->tag);
#endif
			exception_handler_free (h);
			exception_handlers =
			      g_slist_delete_link (exception_handlers, this);
		}
		g_value_unset (&param_values);
		g_value_unset (&return_value);
		++n_run;
	}

	--in_exception_handler;

	G_UNLOCK (exception_handlers);

	if (n_run == 0) 
		warn_of_ignored_exception ("unhandled exception in callback");

	/* and clear the error */
	sv_setsv (ERRSV, &PL_sv_undef);
	SvREFCNT_dec (errsv);
}

=back

=cut

MODULE = Glib::Closure	PACKAGE = Glib	PREFIX = gperl_

int
gperl_install_exception_handler (SV * class, SV * func, SV * data=NULL)
    C_ARGS:
	gperl_closure_new (func, data, 0)
    CLEANUP:
	UNUSED(class);

void
gperl_remove_exception_handler (SV * class, int tag)
    C_ARGS:
	tag
    CLEANUP:
	UNUSED(class);


 ##
 ## end on the native package
 ##
MODULE = Glib::Closure	PACKAGE = Glib::Closure	PREFIX = g_closure_

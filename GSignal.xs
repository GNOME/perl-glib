/*
 * Copyright (C) 2003-2004 by the gtk2-perl team (see the file AUTHORS for
 * the full list)
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Library General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at your
 * option) any later version.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Library General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307  USA.
 *
 * $Header$
 */

=head2 GSignal

=over

=cut

/* #define NOISY */

#include "gperl.h"

/*
 * here's a nice G_LOCK-like front-end to GStaticRecMutex.  we need this 
 * to keep other threads from fiddling with the closures list while we're
 * modifying it.
 */
#ifdef G_THREADS_ENABLED
# define GPERL_REC_LOCK_DEFINE_STATIC(name)	\
	GStaticRecMutex G_LOCK_NAME (name) = G_STATIC_REC_MUTEX_INIT
# define GPERL_REC_LOCK(name)	\
	g_static_rec_mutex_lock (&G_LOCK_NAME (name))
# define GPERL_REC_UNLOCK(name)	\
	g_static_rec_mutex_unlock (&G_LOCK_NAME (name))
#else
# define GPERL_REC_LOCK_DEFINE_STATIC(name) extern void glib_dummy_decl (void)
# define GPERL_REC_LOCK(name)
# define GPERL_REC_UNLOCK(name)
#endif


/*
GLib doesn't include a GFlags type for GSignalFlags, so we have to do
this by hand.  watch for fallen cruft.
*/

static GType
g_signal_flags_get_type (void)
{
  static GType etype = 0;
  if ( etype == 0 ) {
    static const GFlagsValue values[] = {
      { G_SIGNAL_RUN_FIRST,    "G_SIGNAL_RUN_FIRST",   "run-first" },
      { G_SIGNAL_RUN_LAST,     "G_SIGNAL_RUN_LAST",    "run-last" },
      { G_SIGNAL_RUN_CLEANUP,  "G_SIGNAL_RUN_CLEANUP", "run-cleanup" },
      { G_SIGNAL_NO_RECURSE,   "G_SIGNAL_NO_RECURSE",  "no-recurse" },
      { G_SIGNAL_DETAILED,     "G_SIGNAL_DETAILED",    "detailed" },
      { G_SIGNAL_ACTION,       "G_SIGNAL_ACTION",      "action" },
      { G_SIGNAL_NO_HOOKS,     "G_SIGNAL_NO_HOOKS",    "no-hooks" },
      { 0, NULL, NULL }
    };
    etype = g_flags_register_static ("GSignalFlags", values);
  }
  return etype;
}

SV *
newSVGSignalFlags (GSignalFlags flags)
{
	return gperl_convert_back_flags (g_signal_flags_get_type (), flags);
}

GSignalFlags
SvGSignalFlags (SV * sv)
{
	return gperl_convert_flags (g_signal_flags_get_type (), sv);
}

SV *
newSVGSignalInvocationHint (GSignalInvocationHint * ihint)
{
	HV * hv = newHV ();
	hv_store (hv, "signal_name", 11,
	          newSVGChar (g_signal_name (ihint->signal_id)), 0);
	hv_store (hv, "detail", 6,
	          newSVGChar (g_quark_to_string (ihint->detail)), 0);
	hv_store (hv, "run_type", 8,
	          newSVGSignalFlags (ihint->run_type), 0);
	return newRV_noinc ((SV*)hv);
}


/*
now back to our regularly-scheduled bindings.
*/

static GSList * closures = NULL;
GPERL_REC_LOCK_DEFINE_STATIC (closures);

static void
forget_closure (SV * callback,
                GPerlClosure * closure)
{
#ifdef NOISY
	warn ("forget_closure %p / %p", callback, closure);
#else
	PERL_UNUSED_VAR (callback);
#endif
	
	GPERL_REC_LOCK (closures);
	closures = g_slist_remove (closures, closure);
	GPERL_REC_UNLOCK (closures);
}

static void
remember_closure (GPerlClosure * closure)
{
#ifdef NOISY
	warn ("remember_closure %p / %p", closure->callback, closure);
	warn ("   callback %s\n", SvPV_nolen (closure->callback));
#endif
	GPERL_REC_LOCK (closures);
	closures = g_slist_prepend (closures, closure);
	GPERL_REC_UNLOCK (closures);
	g_closure_add_invalidate_notifier ((GClosure *) closure,
	                                   closure->callback,
	                                   (GClosureNotify) forget_closure);
}

=item void gperl_signal_set_marshaller_for (GType instance_type, char * detailed_signal, GClosureMarshal marshaller)

You need this function only in rare cases, usually as workarounds for bad
signal parameter types or to implement writable arguments.  Use the given
I<marshaller> to marshal all handlers for I<detailed_signal> on
I<instance_type>.  C<gperl_signal_connect> will look for marshallers
registered here, and apply them to the GPerlClosure it creates for the given
callback being connected.

Use the helper macros in gperl_marshal.h to help write your marshaller
function.  That header, which is installed with the Glib module but not
#included through gperl.h, includes commentary and examples which you
should follow closely to avoid nasty bugs.  Use the Source, Luke.

WARNING: Bend over backwards and turn your head around 720 degrees before
attempting to write a GPerlClosure marshaller without using the macros in
gperl_marshal.h.  If you absolutely cannot use those macros, be certain to
understand what those macros do so you can get the semantics correct, and
keep your code synchronized with them, or you may miss very important
bugfixes.

=cut
static GHashTable * marshallers = NULL;
G_LOCK_DEFINE_STATIC (marshallers);

typedef struct {
	GType           instance_type;
	GClosureMarshal marshaller;
} MarshallerData;

static MarshallerData *
marshaller_data_new (GType itype, GClosureMarshal func)
{
	MarshallerData * data = g_new0 (MarshallerData, 1);
	data->instance_type = itype;
	data->marshaller = func;
	return data;
}

void
gperl_signal_set_marshaller_for (GType instance_type,
                                 char * detailed_signal,
                                 GClosureMarshal marshaller)
{
	g_return_if_fail (instance_type != 0);
	g_return_if_fail (detailed_signal != NULL);
	G_LOCK (marshallers);
	if (!marshaller && !marshallers) {
		/* nothing to do */
	} else {
		if (!marshallers)
			marshallers =
				g_hash_table_new_full (gperl_str_hash,
				                       (GEqualFunc)gperl_str_eq,
				                       g_free,
				                       g_free);
		if (marshaller)
			g_hash_table_insert
					(marshallers,
					 g_strdup (detailed_signal),
					 marshaller_data_new (instance_type,
					                      marshaller));
		else
			g_hash_table_remove (marshallers, detailed_signal);
	}
	G_UNLOCK (marshallers);
}

=item gulong gperl_signal_connect (SV * instance, char * detailed_signal, SV * callback, SV * data, GConnectFlags flags)

The actual workhorse behind GObject::signal_connect, the binding for
g_signal_connect, for use from within XS.  This creates a C<GPerlClosure>
wrapper for the given I<callback> and I<data>, and connects that closure to the
signal named I<detailed_signal> on the given GObject I<instance>.  This is only
good for named signals.  I<flags> is the same as for g_signal_connect().
I<data> may be NULL, but I<callback> must not be.

Returns the id of the installed callback.

=cut
gulong
gperl_signal_connect (SV * instance,
                      char * detailed_signal,
                      SV * callback, SV * data,
                      GConnectFlags flags)
{
	GObject * object;
	GPerlClosure * closure;
	GClosureMarshal marshaller = NULL;

	object = gperl_get_object (instance);

	G_LOCK (marshallers);
	if (marshallers) {
		MarshallerData * data = (MarshallerData*)
			g_hash_table_lookup (marshallers, detailed_signal);
		if (data) {
			if (g_type_is_a (G_OBJECT_TYPE (object),
			                 data->instance_type))
				marshaller = data->marshaller;
		}
	}
	G_UNLOCK (marshallers);

	closure = (GPerlClosure *)
			gperl_closure_new_with_marshaller
			                     (callback, data,
			                      flags & G_CONNECT_SWAPPED,
			                      marshaller);

	/* after is true only if we're called as signal_connect_after */
	closure->id =
		g_signal_connect_closure (object,
		                          detailed_signal,
		                          (GClosure*) closure, 
		                          flags & G_CONNECT_AFTER);

	if (closure->id > 0)
		remember_closure (closure);
	
	return ((GPerlClosure*)closure)->id;
}

/*
G_SIGNAL_MATCH_ID        The signal id must be equal.
G_SIGNAL_MATCH_DETAIL    The signal detail be equal.
G_SIGNAL_MATCH_CLOSURE   The closure must be the same.
G_SIGNAL_MATCH_FUNC      The C closure callback must be the same.
G_SIGNAL_MATCH_DATA      The closure data must be the same.
G_SIGNAL_MATCH_UNBLOCKED Only unblocked signals may matched.

at the perl level, the CV replaces both the FUNC and CLOSURE.  it's rare
people will specify any of the others than FUNC and DATA, but i can see
how they would be useful so let's support them.
*/
typedef guint (*sig_match_callback) (gpointer           instance,
                                     GSignalMatchType   mask,
                                     guint              signal_id,
                                     GQuark             detail,
                                     GClosure         * closure,
                                     gpointer           func,
                                     gpointer           data);

static int
foreach_closure_matched (gpointer instance,
                         GSignalMatchType mask,
                         guint signal_id,
                         GQuark detail,
                         SV * func,
                         SV * data,
                         sig_match_callback callback)
{
	int n = 0;
	GSList * i;

	if (mask & G_SIGNAL_MATCH_CLOSURE || /* this isn't too likely */
	    mask & G_SIGNAL_MATCH_FUNC ||
	    mask & G_SIGNAL_MATCH_DATA) {
		/*
		 * to match against a function or data, we need to find the
		 * scalars for those in the GPerlClosures; we'll have to
		 * proxy this stuff.  we'll replace the func and data bits
		 * with closure in the mask.
		 *    however, we can't do the match for any of the other
		 * flags at this level, so even though our design means one
		 * closure per handler id, we still have to pass that closure
		 * on to the real C functions to do any other filtering for
		 * us.
		 */
		/* we'll compare SVs by their stringified values.  cache the
		 * stringified needles, but there's no way to cache the
		 * haystack. */
		const char * str_func = func ? SvPV_nolen (func) : NULL;
		const char * str_data = data ? SvPV_nolen (data) : NULL;

		mask &= ~(G_SIGNAL_MATCH_FUNC | G_SIGNAL_MATCH_DATA);
		mask |= G_SIGNAL_MATCH_CLOSURE;

		/* this is a little hairy because the callback may disconnect
		 * a closure, which would modify the list while we're iterating
		 * over it. */
		GPERL_REC_LOCK (closures);
		i = closures;
		while (i != NULL) {
			GPerlClosure * c = (GPerlClosure*) i->data;
			i = i->next;
			if ((!func || strEQ (str_func, SvPV_nolen (c->callback))) &&
			    (!data || strEQ (str_data, SvPV_nolen (c->data)))) {
				n += callback (instance, mask, signal_id,
				               detail, (GClosure*)c,
				               NULL, NULL);
			}
		}
		GPERL_REC_UNLOCK (closures);
	} else {
		/* we're not matching against a closure, so we can just
		 * pass this on through. */
		n = callback (instance, mask, signal_id, detail,
		              NULL, NULL, NULL);
	}
	return n;
}


=back

=cut


MODULE = Glib::Signal	PACKAGE = Glib::Object	PREFIX = g_

BOOT:
	gperl_register_fundamental (g_signal_flags_get_type (),
	                            "Glib::SignalFlags");

=for flags Glib::SignalFlags

=cut

##
##/* --- typedefs --- */
##typedef struct _GSignalQuery		 GSignalQuery;
##typedef struct _GSignalInvocationHint	 GSignalInvocationHint;
##typedef GClosureMarshal			 GSignalCMarshaller;
##typedef gboolean (*GSignalEmissionHook) (GSignalInvocationHint *ihint,
##					 guint			n_param_values,
##					 const GValue	       *param_values,
##					 gpointer		data);
##typedef gboolean (*GSignalAccumulator)	(GSignalInvocationHint *ihint,
##					 GValue		       *return_accu,
##					 const GValue	       *handler_return,
##					 gpointer               data);


###
### ## creating signals ##
### new signals are currently created as a byproduct of Glib::Type::register
###
##        g_signal_newv
##        g_signal_new_valist
##        g_signal_new

###
### ## emitting signals ##
### all versions of g_signal_emit go through Glib::Object::signal_emit,
### which is mostly equivalent to g_signal_emit_by_name.
###
##        g_signal_emitv
##        g_signal_emit_valist
##        g_signal_emit
##        g_signal_emit_by_name

## heavily borrowed from gtk-perl and goran's code in gtk2-perl, which
## was inspired by pygtk's pyobject.c::pygobject_emit

=for apidoc

=for signature retval = $object->signal_emit ($name, ...)

=for arg name (string) the name of the signal

=for arg ... (list) any arguments to pass to handlers.

Emit the signal I<name> on I<$object>.  The number and types of additional
arguments in I<...> are determined by the signal; similarly, the presence
and type of return value depends on the signal being emitted.

=cut
void
g_signal_emit (instance, name, ...)
	GObject * instance
	char * name
    PREINIT:
	guint signal_id, i;
	GQuark detail;
	GSignalQuery query;
	GValue * params;
    PPCODE:
#define ARGOFFSET 2
	if (!g_signal_parse_name (name, G_OBJECT_TYPE (instance), &signal_id,
				  &detail, TRUE))
		croak ("Unknown signal %s for object of type %s", 
			name, G_OBJECT_TYPE_NAME (instance));

	g_signal_query (signal_id, &query);

	if (((guint)(items-ARGOFFSET)) != query.n_params) 
		croak ("Incorrect number of arguments for emission of signal %s in class %s; need %d but got %d",
		       name, G_OBJECT_TYPE_NAME (instance),
		       query.n_params, items-ARGOFFSET);

	/* set up the parameters to g_signal_emitv.   this is an array
	 * of GValues, where [0] is the emission instance, and the rest 
	 * are the query.n_params arguments. */
	params = g_new0 (GValue, query.n_params + 1);

	g_value_init (&params[0], G_OBJECT_TYPE (instance));
	g_value_set_object (&params[0], instance);

	for (i = 0 ; i < query.n_params ; i++) {
		g_value_init (&params[i+1], 
			      query.param_types[i] & ~G_SIGNAL_TYPE_STATIC_SCOPE);
		if (!gperl_value_from_sv (&params[i+1], ST (ARGOFFSET+i)))
			croak ("Couldn't convert value %s to type %s for parameter %d of signal %s on a %s",
			       SvPV_nolen (ST (ARGOFFSET+i)),
			       g_type_name (G_VALUE_TYPE (&params[i+1])),
			       i, name, G_OBJECT_TYPE_NAME (instance));
	}

	/* now actually call it.  what we do depends on the return type of
	 * the signal; if the signal returns anything we need to capture it
	 * and push it onto the return stack. */
	if (query.return_type != G_TYPE_NONE) {
		/* signal returns a value, woohoo! */
		GValue ret = {0,};
		g_value_init (&ret, query.return_type);
		g_signal_emitv (params, signal_id, detail, &ret);
		EXTEND (SP, 1);
		PUSHs (sv_2mortal (gperl_sv_from_value (&ret)));
		g_value_unset (&ret);
	} else {
		g_signal_emitv (params, signal_id, detail, NULL);
	}

	/* clean up */
	for (i = 0 ; i < query.n_params + 1 ; i++)
		g_value_unset (&params[i]);
	g_free (params);
#undef ARGOFFSET


##guint                 g_signal_lookup       (const gchar        *name,
##					     GType               itype);
##G_CONST_RETURN gchar* g_signal_name         (guint               signal_id);
##void                  g_signal_query        (guint               signal_id,
##					     GSignalQuery       *query);
##guint*                g_signal_list_ids     (GType               itype,
##					     guint              *n_ids);
##gboolean	      g_signal_parse_name   (const gchar	*detailed_signal,
##					     GType		 itype,
##					     guint		*signal_id_p,
##					     GQuark		*detail_p,
##					     gboolean		 force_detail_quark);
##GSignalInvocationHint* g_signal_get_invocation_hint (gpointer    instance);
##
##
##/* --- signal emissions --- */
##void	g_signal_stop_emission		    (gpointer		  instance,
##					     guint		  signal_id,
##					     GQuark		  detail);
##void	g_signal_stop_emission_by_name	    (gpointer		  instance,
##					     const gchar	 *detailed_signal);
void g_signal_stop_emission_by_name (GObject * instance, const gchar * detailed_signal);

##gulong	g_signal_add_emission_hook	    (guint		  signal_id,
##					     GQuark		  quark,
##					     GSignalEmissionHook  hook_func,
##					     gpointer	       	  hook_data,
##					     GDestroyNotify	  data_destroy);
##void	g_signal_remove_emission_hook	    (guint		  signal_id,
##					     gulong		  hook_id);
##
##
##/* --- signal handlers --- */
##gboolean g_signal_has_handler_pending	      (gpointer		  instance,
##					       guint		  signal_id,
##					       GQuark		  detail,
##					       gboolean		  may_be_blocked);

###
### ## connecting signals ##
### currently all versions of signal_connect go through
### Glib::Object::signal_connect, which acts like the g_signal_connect
### convenience function.
###
##gulong g_signal_connect_closure_by_id	      (gpointer		  instance,
##					       guint		  signal_id,
##					       GQuark		  detail,
##					       GClosure		 *closure,
##					       gboolean		  after);
##gulong g_signal_connect_closure	      (gpointer		  instance,
##					       const gchar       *detailed_signal,
##					       GClosure		 *closure,
##					       gboolean		  after);
##gulong g_signal_connect_data		      (gpointer		  instance,
##					       const gchar	 *detailed_signal,
##					       GCallback	  c_handler,
##					       gpointer		  data,
##					       GClosureNotify	  destroy_data,
##					       GConnectFlags	  connect_flags);

=for apidoc Glib::Object::signal_connect

=for arg callback (subroutine) 

=for arg data (scalar) arbitrary data to be passed to each invocation of I<callback>

Register I<callback> to be called on each emission of I<$detailed_signal>.
Returns an identifier that may be used to remove this handler with
C<< $object->signal_handler_disconnect >>.

=cut

=for apidoc Glib::Object::signal_connect_after

Like C<signal_connect>, except that I<$callback> will be run after the default
handler.

=cut

=for apidoc Glib::Object::signal_connect_swapped

Like C<signal_connect>, except that I<$data> and I<$object> will be swapped
on invocation of I<$callback>.

=cut

gulong
g_signal_connect (instance, detailed_signal, callback, data=NULL)
	SV * instance
	char * detailed_signal
	SV * callback
	SV * data
    ALIAS:
	Glib::Object::signal_connect = 0
	Glib::Object::signal_connect_after = 1
	Glib::Object::signal_connect_swapped = 2
    PREINIT:
	GConnectFlags flags = 0;
    CODE:
	if (ix == 1) flags |= G_CONNECT_AFTER;
	if (ix == 2) flags |= G_CONNECT_SWAPPED;
	RETVAL = gperl_signal_connect (instance, detailed_signal,
	                               callback, data, flags);
    OUTPUT:
	RETVAL


void
g_signal_handler_block (object, handler_id)
	GObject * object
	gulong handler_id

void
g_signal_handler_unblock (object, handler_id)
	GObject * object
	gulong handler_id

void
g_signal_handler_disconnect (object, handler_id)
	GObject * object
	gulong handler_id

gboolean
g_signal_handler_is_connected (object, handler_id)
	GObject * object
	gulong handler_id

 ##
 ## this would require a fair bit of the magic used in the *_by_func
 ## wrapper below...
 ##
##gulong   g_signal_handler_find              (gpointer          instance,
##                                             GSignalMatchType  mask,
##                                             guint             signal_id,
##                                             GQuark            detail,
##                                             GClosure         *closure,
##                                             gpointer          func,
##                                             gpointer          data);

 ###
 ### the *_matched functions all have the same signature and thus all 
 ### are handled by matched().
 ###

 ##  g_signal_handlers_block_matched
 ##  g_signal_handlers_unblock_matched
 ##  g_signal_handlers_disconnect_matched

 ##### FIXME oops, no typemap for GSignalMatchType...
##guint
##matched (instance, mask, signal_id, detail, func, data)
##	SV * instance
##	GSignalMatchType mask
##	guint signal_id
##	SV * detail
##	SV * func
##	SV * data
##    ALIAS:
##	Glib::Object::signal_handlers_block_matched = 0
##	Glib::Object::signal_handlers_unblock_matched = 1
##	Glib::Object::signal_handlers_disconnect_matched = 2
##    PREINIT:
##	sig_match_callback callback = NULL;
##	GQuark real_detail = 0;
##    CODE:
##	switch (ix) {
##	    case 0: callback = g_signal_handlers_block_matched; break;
##	    case 1: callback = g_signal_handlers_unblock_matched; break;
##	    case 2: callback = g_signal_handlers_disconnect_matched; break;
##	}
##	if (!callback)
##		croak ("internal problem -- xsub aliased to invalid ix");
##	if (detail && SvPOK (detail)) {
##		real_detail = g_quark_try_string (SvPV_nolen (detail));
##		if (!real_detail)
##			croak ("no such detail %s", SvPV_nolen (detail));
##	}
##	RETVAL = foreach_closure_matched (gperl_get_object (instance),
##	                                  mask, signal_id, real_detail,
##	                                  func, data);
##    OUTPUT:
##	RETVAL

 ### the *_by_func functions all have the same signature, and thus are
 ### handled by do_stuff_by_func.

 ## g_signal_handlers_disconnect_by_func(instance, func, data)
 ## g_signal_handlers_block_by_func(instance, func, data)
 ## g_signal_handlers_unblock_by_func(instance, func, data)

=for apidoc Glib::Object::signal_handlers_block_by_func
=for arg func (subroutine) function to block
=for arg data (scalar) data to match, ignored if undef
=cut

=for apidoc Glib::Object::signal_handlers_unblock_by_func
=for arg func (subroutine) function to block
=for arg data (scalar) data to match, ignored if undef
=cut

=for apidoc Glib::Object::signal_handlers_disconnect_by_func
=for arg func (subroutine) function to block
=for arg data (scalar) data to match, ignored if undef
=cut

int
do_stuff_by_func (instance, func, data=NULL)
	GObject * instance
	SV * func
	SV * data
    ALIAS:
	Glib::Object::signal_handlers_block_by_func = 0
	Glib::Object::signal_handlers_unblock_by_func = 1
	Glib::Object::signal_handlers_disconnect_by_func = 2
    PREINIT:
	sig_match_callback callback = NULL;
    CODE:
	switch (ix) {
	    case 0: callback = g_signal_handlers_block_matched; break;
	    case 1: callback = g_signal_handlers_unblock_matched; break;
	    case 2: callback = g_signal_handlers_disconnect_matched; break;
	}
	if (!callback)
		croak ("internal problem -- xsub aliased to invalid ix");
	RETVAL = foreach_closure_matched (instance, G_SIGNAL_MATCH_CLOSURE,
	                                  0, 0, func, data, callback);
    OUTPUT:
	RETVAL




##/* --- chaining for language bindings --- */
##void	g_signal_override_class_closure	      (guint		  signal_id,
##					       GType		  instance_type,
##					       GClosure		 *class_closure);
##void	g_signal_chain_from_overridden	      (const GValue      *instance_and_params,
##					       GValue            *return_value);
=for apidoc

Chain up to an overridden class closure; it is only valid to call this from
a class closure override.

Translation: because of various details in how GObjects are implemented,
the way to override a virtual method on a GObject is to provide a new "class
closure", or default handler for a signal.  This happens when a class is
registered with the type system (see Glib::Type::register and
L<Glib::Object::Subclass>).  When called from inside such an override, this
method runs the overridden class closure.  This is equivalent to calling
$self->SUPER::$method (@_) in normal Perl objects.

=cut
void
g_signal_chain_from_overridden (GObject * instance, ...)
    PREINIT:
	GSignalInvocationHint * ihint;
	GSignalQuery query;
	GValue * instance_and_params = NULL,
	         return_value = {0,};
	guint i;
    PPCODE:

	ihint = g_signal_get_invocation_hint (instance);
	if (!ihint)
		croak ("could not find signal invocation hint for %s(0x%p)",
		       G_OBJECT_TYPE_NAME (instance), instance);

	g_signal_query (ihint->signal_id, &query);

	if ((guint)items != 1 + query.n_params)
		croak ("incorrect number of parameters for signal %s, "
		       "expected %d, got %d",
		       g_signal_name (ihint->signal_id),
		       1 + query.n_params,
		       items);

	instance_and_params = g_new0 (GValue, 1 + query.n_params);

	g_value_init (&instance_and_params[0], G_OBJECT_TYPE (instance));
	g_value_set_object (&instance_and_params[0], instance);

	for (i = 0 ; i < query.n_params ; i++) {
		g_value_init (&instance_and_params[i+1],
		              query.param_types[i]
			         & ~G_SIGNAL_TYPE_STATIC_SCOPE);
		gperl_value_from_sv (&instance_and_params[i+1], ST (i+1));
	}

	if (query.return_type != G_TYPE_NONE)
		g_value_init (&return_value,
		              query.return_type
			         & ~G_SIGNAL_TYPE_STATIC_SCOPE);
	
	g_signal_chain_from_overridden (instance_and_params, &return_value);

	for (i = 0 ; i < 1 + query.n_params ; i++)
		g_value_unset (instance_and_params+i);
	g_free (instance_and_params);

	if (G_TYPE_NONE != (query.return_type & ~G_SIGNAL_TYPE_STATIC_SCOPE)) {
		XPUSHs (sv_2mortal (gperl_sv_from_value (&return_value)));
		g_value_unset (&return_value);
	}

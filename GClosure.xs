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
	if (pc->target) {
		SvREFCNT_dec (pc->target);
		pc->target = NULL;
	}
	if (pc->callback) {
		SvREFCNT_dec (pc->callback);     
		pc->callback = NULL;
	}
	if (pc->data) {
		SvREFCNT_dec (pc->data);
		pc->data = NULL;
	}
	if (pc->name) {
		g_free (pc->name);
		pc->name = NULL;
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
	guint i;
	GPerlClosure *pc = (GPerlClosure *)closure;
	SV * target, * data;
#ifndef PERL_IMPLICIT_CONTEXT
	dSP;
#else
	SV **SP;

	/* make sure we're executed by the same interpreter that created
	 * the closure object. */
	PERL_SET_CONTEXT (marshal_data);

	SPAGAIN;
#endif

	/*
	warn ("Marshalling: params: %d\n", n_param_values);
	warn ("Marshalling: func: %lx (refcnt: %d) target: %lx (refcnt: %d) data: %lx (refcnt: %d)\n", 
	      pc->callback, pc->callback->sv_refcnt,
	      pc->target, pc->target->sv_refcnt,
	      pc->extra_args, pc->extra_args ? pc->extra_args->sv_refcnt : 0);
	 */

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);

	/* FIXME pc->target's object and param[0]'s object should be the same.
	 *       should i verify this? */

	if (GPERL_CLOSURE_SWAP_DATA (pc)) {
		/* swap target and data */
		target = pc->data;
		data   = pc->target;
	} else {
		/* normal */
		target = pc->target;
		data   = pc->data;
	}

	if (!target)
		target = &PL_sv_undef;

	/* always the first item in @_ */
	XPUSHs (target);

	/* any extra params for this call will be included in param_values
	 * as GValues, and this should be straightforward.  */
	if (n_param_values > 1) {
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
			       warn ("[gperl_closure_marshal] Warning, failed to convert object from value for name: %s number: %d type: %s fundtype: %s\n",
				     pc->name, i,
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

	if (return_value && G_VALUE_TYPE (return_value)) {
		i = call_sv (pc->callback, G_SCALAR);

		SPAGAIN;
		if (i != 1)
			croak ("Big trouble -- call_sv (..., G_SCALAR) returned %i != 1", i);
		else
			gperl_value_from_sv (return_value, POPs);

	} else
		call_sv (pc->callback, G_DISCARD);

	/*
	 * clean up 
	 */

	FREETMPS;
	LEAVE;
}

GClosure *
gperl_closure_new (gchar * name,
		   SV * target,
		   SV * callback,
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
	closure->target = (target && target != &PL_sv_undef)
	                ? newSVsv (target)
	                : NULL;

	closure->callback = (callback && callback != &PL_sv_undef)
	                  ? newSVsv (callback)
	                  : NULL;

	closure->data = (data && data != &PL_sv_undef)
	              ? newSVsv (data)
	              : NULL;

	closure->swap = swap;
	closure->name = name ? g_strdup (name) : NULL;
	return (GClosure*)closure;
}

/*
void
gperl_gclosure_destroy (SV * closure)
{
	GPerlClosure* pc = SvGClosure (closure);
	if (pc) {
		g_closure_unref ((GClosure*) pc);
		sv_setiv (SvRV (closure), (IV) 0);
	} else
		warn ("WARNING: double free attempted on GClosure %s\n",
		      SvPV_nolen (closure));
}
*/




/*
 * GPerlCallback
 *
 * generic callback functions usually get invoked directly, and are not
 * passed parameter lists as GValues.  we could very easily wrap up such
 * generic callbacks with something that converts the parameters to
 * GValues and then channels everything through GClosure, but this has
 * two problems:  1) the above implementation of GClosure is tuned to 
 * marshalling signal handlers, which always have an instance object, and
 * 2) it's more work than is strictly necessary.
 *
 * additionally, generic callbacks aren't always kind to the GClosure
 * paradigm.
 *
 * so, here's GPerlCallback, which is designed specifically to run
 * generic callback functions.  it reads parameters off the C stack and
 * converts them into parameters on the perl stack.  (it uses the GValue
 * to/from SV mechanism to do so, but doesn't allocate any temps on the
 * heap.)  the callback object itself stores the parameter type list.
 *
 * unfortunately, since the data element is always last, but the number
 * of arguments is not known until we have the callback object, we can't
 * pass gperl_callback_invoke directly to functions requiring a callback;
 * you'll have to write a proxy callback which calls gperl_callback_invoke.
 */


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


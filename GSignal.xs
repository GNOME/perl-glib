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


gulong
gperl_signal_connect (SV * instance,
                      char * detailed_signal,
                      SV * callback, SV * data,
                      GConnectFlags flags)
{
	GClosure * closure;

	closure = gperl_closure_new (detailed_signal, instance,
				     callback, data,
				     flags & G_CONNECT_SWAPPED);

	/* after is true only if we're called as signal_connect_after */
	((GPerlClosure*)closure)->id =
		g_signal_connect_closure (gperl_get_object (instance),
		                          detailed_signal, closure, 
		                          flags & G_CONNECT_AFTER);
	
	return ((GPerlClosure*)closure)->id;
}


MODULE = Glib::Signal	PACKAGE = Glib::Object	PREFIX = g_

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
##
##
##/* --- signals --- */
##guint                 g_signal_newv         (const gchar        *signal_name,
##					     GType               itype,
##					     GSignalFlags        signal_flags,
##					     GClosure           *class_closure,
##					     GSignalAccumulator	 accumulator,
##					     gpointer		 accu_data,
##					     GSignalCMarshaller  c_marshaller,
##					     GType               return_type,
##					     guint               n_params,
##					     GType              *param_types);
##guint                 g_signal_new_valist   (const gchar        *signal_name,
##					     GType               itype,
##					     GSignalFlags        signal_flags,
##					     GClosure           *class_closure,
##					     GSignalAccumulator	 accumulator,
##					     gpointer		 accu_data,
##					     GSignalCMarshaller  c_marshaller,
##					     GType               return_type,
##					     guint               n_params,
##					     va_list             args);
##guint                 g_signal_new          (const gchar        *signal_name,
##					     GType               itype,
##					     GSignalFlags        signal_flags,
##					     guint               class_offset,
##					     GSignalAccumulator	 accumulator,
##					     gpointer		 accu_data,
##					     GSignalCMarshaller  c_marshaller,
##					     GType               return_type,
##					     guint               n_params,
##					     ...);
##void                  g_signal_emitv        (const GValue       *instance_and_params,
##					     guint               signal_id,
##					     GQuark              detail,
##					     GValue             *return_value);
##void                  g_signal_emit_valist  (gpointer            instance,
##					     guint               signal_id,
##					     GQuark              detail,
##					     va_list             var_args);


##void                  g_signal_emit         (gpointer            instance,
##					     guint               signal_id,
##					     GQuark              detail,
##					     ...);
##void                  g_signal_emit_by_name (gpointer            instance,
##					     const gchar        *detailed_signal,
##					     ...);

## heavily borrowed from gtk-perl and goran's code in gtk2-perl, which
## was inspired by pygtk's pyobject.c::pygobject_emit

void
g_signal_emit (instance, name, ...)
	GObject * instance
	char * name
    PREINIT:
	guint signal_id, i;
	GQuark detail;
	GSignalQuery query;
	GValue * params;
    CODE:
#define ARGOFFSET 2
	if (!g_signal_parse_name (name, G_OBJECT_TYPE (instance), &signal_id,
				  &detail, TRUE))
		croak ("Unknown signal %s for object of type %s", 
			name, G_OBJECT_TYPE_NAME (instance));

	g_signal_query (signal_id, &query);


	if ((items-ARGOFFSET) != query.n_params) 
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
		GValue ret;
		memset (&ret, 0, sizeof (GValue));
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
##gulong	 g_signal_connect_closure_by_id	      (gpointer		  instance,
##					       guint		  signal_id,
##					       GQuark		  detail,
##					       GClosure		 *closure,
##					       gboolean		  after);
##gulong	 g_signal_connect_closure	      (gpointer		  instance,
##					       const gchar       *detailed_signal,
##					       GClosure		 *closure,
##					       gboolean		  after);
##gulong	 g_signal_connect_data		      (gpointer		  instance,
##					       const gchar	 *detailed_signal,
##					       GCallback	  c_handler,
##					       gpointer		  data,
##					       GClosureNotify	  destroy_data,
##					       GConnectFlags	  connect_flags);

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

##gboolean g_signal_handler_is_connected	      (gpointer		  instance,
##					       gulong		  handler_id);
##gulong	 g_signal_handler_find		      (gpointer		  instance,
##					       GSignalMatchType	  mask,
##					       guint		  signal_id,
##					       GQuark		  detail,
##					       GClosure		 *closure,
##					       gpointer		  func,
##					       gpointer		  data);
##guint	 g_signal_handlers_block_matched      (gpointer		  instance,
##					       GSignalMatchType	  mask,
##					       guint		  signal_id,
##					       GQuark		  detail,
##					       GClosure		 *closure,
##					       gpointer		  func,
##					       gpointer		  data);
##guint	 g_signal_handlers_unblock_matched    (gpointer		  instance,
##					       GSignalMatchType	  mask,
##					       guint		  signal_id,
##					       GQuark		  detail,
##					       GClosure		 *closure,
##					       gpointer		  func,
##					       gpointer		  data);
##guint	 g_signal_handlers_disconnect_matched (gpointer		  instance,
##					       GSignalMatchType	  mask,
##					       guint		  signal_id,
##					       GQuark		  detail,
##					       GClosure		 *closure,
##					       gpointer		  func,
##					       gpointer		  data);
##
##
##/* --- chaining for language bindings --- */
##void	g_signal_override_class_closure	      (guint		  signal_id,
##					       GType		  instance_type,
##					       GClosure		 *class_closure);
##void	g_signal_chain_from_overridden	      (const GValue      *instance_and_params,
##					       GValue            *return_value);
##

 ## /* --- convenience --- */

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


###define	g_signal_handlers_disconnect_by_func(instance, func, data)						\
##    g_signal_handlers_disconnect_matched ((instance),								\
##					  (GSignalMatchType) (G_SIGNAL_MATCH_FUNC | G_SIGNAL_MATCH_DATA),	\
##					  0, 0, NULL, (func), (data))
###define	g_signal_handlers_block_by_func(instance, func, data)							\
##    g_signal_handlers_block_matched      ((instance),								\
##				          (GSignalMatchType) (G_SIGNAL_MATCH_FUNC | G_SIGNAL_MATCH_DATA),	\
##				          0, 0, NULL, (func), (data))
###define	g_signal_handlers_unblock_by_func(instance, func, data)							\
##    g_signal_handlers_unblock_matched    ((instance),								\
##				          (GSignalMatchType) (G_SIGNAL_MATCH_FUNC | G_SIGNAL_MATCH_DATA),	\
##				          0, 0, NULL, (func), (data))
##
#

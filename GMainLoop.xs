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

/* stuff from gmain.h, the main loop and friends */
/*

GMainLoop is in libglib; GClosure is in libgobject.  the mainloop can't refer
to GClosure for dependency reasons, but the code is designed to be used with
GClosure anyway.  that's what we'll do here.

specifically, GSourceDummyMarshal is just a placeholder for GClosureMarshal.

since we have GClosure implemented in GClosure.xs, we'll use it to handle
the callbacks here.


in the more general sense, this file offers the GLib-level interface to the
main loop stuff wrapped by the Gtk2 module.  at the current point, i can't
think of any reason to expose the lower-level main loop stuff here, because
how many apps are going to be using the event loop without Gtk?  then again,
it's quite conceivable that you'd want to do that, so it's not precluded
(just not done).

if you want to implement the main loop stuff here, you'll need to create
typemaps for these types:

	GMainContext	<- Opaque
	GMainLoop	<- Opaque

and you'll need to typemap these if you want to create custom sources
from perl:

	GSource
	GSourceCallbackFuncs
	GSourceFuncs

as far as i can tell, each of these is a ref-counted object, but none
are GObject or GBoxed descendents (as they are part of glib, not gobject!).


for anyone who needs to implement this stuff, i've left the majority
of gmain.h in here, commented out.

*/

#if 0

###MODULE = Glib::MainLoop	PACKAGE = Glib	PREFIX = g_

## FIXME we could probably create a GEnum for these if anybody really cared
##/* Standard priorities */
##
###define G_PRIORITY_HIGH            -100
###define G_PRIORITY_DEFAULT          0
###define G_PRIORITY_HIGH_IDLE        100
###define G_PRIORITY_DEFAULT_IDLE     200
###define G_PRIORITY_LOW	            300

##MODULE = Glib::MainLoop	PACKAGE = Glib::MainContext	PREFIX = g_main_context_
 
 #####################
 ### GMainContext: ###
 #####################

##GMainContext *g_main_context_new       (void);
##void          g_main_context_ref       (GMainContext *context);
##void          g_main_context_unref     (GMainContext *context);
##GMainContext *g_main_context_default   (void);
##
##gboolean      g_main_context_iteration (GMainContext *context,
##					gboolean      may_block);
##gboolean      g_main_context_pending   (GMainContext *context);
##
##/* For implementation of legacy interfaces */
##GSource *g_main_context_find_source_by_id (GMainContext *context,
##	   				     guint source_id);
##GSource *g_main_context_find_source_by_user_data (GMainContext *context,
##	   					    gpointer user_data);
##GSource *g_main_context_find_source_by_funcs_user_data (GMainContext *context,
## 							  GSourceFuncs *funcs,
##							  gpointer user_data);


##/* Low level functions for implementing custom main loops. */
##void     g_main_context_wakeup  (GMainContext *context);
##gboolean g_main_context_acquire (GMainContext *context);
##void     g_main_context_release (GMainContext *context);
##gboolean g_main_context_wait    (GMainContext *context,
##				 GCond        *cond,
##				 GMutex       *mutex);
##
##gboolean g_main_context_prepare  (GMainContext *context,
##				  gint         *priority);
##gint     g_main_context_query    (GMainContext *context,
##				  gint          max_priority,
##				  gint         *timeout_,
##				  GPollFD      *fds,
##				  gint          n_fds);
##gint     g_main_context_check    (GMainContext *context,
##				  gint          max_priority,
##				  GPollFD      *fds,
##				  gint          n_fds);
##void     g_main_context_dispatch (GMainContext *context);
##
##void      g_main_context_set_poll_func (GMainContext *context,
##					GPollFunc     func);
##GPollFunc g_main_context_get_poll_func (GMainContext *context);
##
##/* Low level functions for use by source implementations */
##void g_main_context_add_poll      (GMainContext *context,
##				   GPollFD      *fd,
##				   gint          priority);
##void g_main_context_remove_poll   (GMainContext *context,
##				   GPollFD      *fd);


##MODULE = Glib::MainLoop	PACKAGE = Glib::MainLoop	PREFIX = g_main_loop_

 ##################
 ### GMainLoop: ###
 ##################

##GMainLoop *g_main_loop_new        (GMainContext *context,
##			    	   gboolean      is_running);
##void       g_main_loop_run        (GMainLoop    *loop);
##void       g_main_loop_quit       (GMainLoop    *loop);
##GMainLoop *g_main_loop_ref        (GMainLoop    *loop);
##void       g_main_loop_unref      (GMainLoop    *loop);
##gboolean   g_main_loop_is_running (GMainLoop    *loop);
##GMainContext *g_main_loop_get_context (GMainLoop    *loop);

 ##/* ============== Compat main loop stuff ================== */
 ##
 ###ifndef G_DISABLE_DEPRECATED
 ##
 ##/* Legacy names for GMainLoop functions
 ## */
 ###define 	g_main_new(is_running)	g_main_loop_new (NULL, is_running);
 ###define         g_main_run(loop)        g_main_loop_run(loop)
 ###define         g_main_quit(loop)       g_main_loop_quit(loop)
 ###define         g_main_destroy(loop)    g_main_loop_unref(loop)
 ###define         g_main_is_running(loop) g_main_loop_is_running(loop)
 ##
 ##/* Functions to manipulate the default main loop
 ## */
 ##
 ###define	g_main_iteration(may_block) g_main_context_iteration      (NULL, may_block)
 ###define g_main_pending()            g_main_context_pending        (NULL)
 ##
 ###define g_main_set_poll_func(func)   g_main_context_set_poll_func (NULL, func)
 ##
 ###endif /* G_DISABLE_DEPRECATED */

#endif

MODULE = Glib::MainLoop	PACKAGE = Glib::Source	PREFIX = g_source_

 ################
 ### GSource: ###
 ################

 ##GSource *g_source_new             (GSourceFuncs   *source_funcs,
 ##				      guint           struct_size);
 ##GSource *g_source_ref             (GSource        *source);
 ##void     g_source_unref           (GSource        *source);
 ##guint    g_source_attach          (GSource        *source,
 ##				      GMainContext   *context);
 ##void     g_source_destroy         (GSource        *source);
 ##void     g_source_set_priority    (GSource        *source,
 ##				      gint            priority);
 ##gint     g_source_get_priority    (GSource        *source);
 ##void     g_source_set_can_recurse (GSource        *source,
 ##				      gboolean        can_recurse);
 ##gboolean g_source_get_can_recurse (GSource        *source);
 ##guint    g_source_get_id          (GSource        *source);
 ##
 ##GMainContext *g_source_get_context (GSource       *source);
 ##
 ##void g_source_set_callback (GSource              *source,
 ##			       GSourceFunc           func,
 ##			       gpointer              data,
 ##			       GDestroyNotify        notify);

 ##void g_source_add_poll         (GSource        *source,
 ##				   GPollFD        *fd);
 ##void g_source_remove_poll      (GSource        *source,
 ##				   GPollFD        *fd);
 ##
 ##void g_source_get_current_time (GSource        *source,
 ##				   GTimeVal       *timeval);
 ##
 ##/* Specific source types */
 ##GSource *g_idle_source_new    (void);
 ##GSource *g_timeout_source_new (guint         interval);

 ##/* Miscellaneous functions
 ## */
 ##void g_get_current_time		        (GTimeVal	*result);



gboolean
g_source_remove (class, tag)
	SV * class
	guint tag
    C_ARGS:
	tag

 ##gboolean g_source_remove_by_user_data        (gpointer       user_data);
 ##gboolean g_source_remove_by_funcs_user_data  (GSourceFuncs  *funcs,
 ##					      gpointer       user_data);


MODULE = Glib::MainLoop	PACKAGE = Glib::Timeout	PREFIX = g_timeout_

 ##########################
 ### Idles and timeouts ###
 ##########################

guint
g_timeout_add (class, interval, callback, data=NULL, priority=G_PRIORITY_DEFAULT)
	SV * class
	guint interval
	SV * callback
	SV * data
	gint priority
    PREINIT:
	GClosure * closure;
	GSource * source;
    CODE:
	closure = gperl_closure_new ("Glib::Timeout", data, callback, NULL, FALSE);
	source = g_timeout_source_new (interval);
	if (priority != G_PRIORITY_DEFAULT)
		g_source_set_priority (source, priority);
	g_source_set_closure (source, closure);
	RETVAL = g_source_attach (source, NULL);
	g_source_unref (source);
    OUTPUT:
	RETVAL



MODULE = Glib::MainLoop	PACKAGE = Glib::Idle	PREFIX = g_idle_

guint
g_idle_add (class, callback, data=NULL, priority=G_PRIORITY_DEFAULT_IDLE)
	SV * class
	SV * callback
	SV * data
	gint priority
    PREINIT:
	GClosure * closure;
	GSource * source;
    CODE:
	closure = gperl_closure_new ("Glib::Idle", data, callback, NULL, FALSE);
	source = g_idle_source_new ();
	g_source_set_priority (source, priority);
	g_source_set_closure (source, closure);
	RETVAL = g_source_attach (source, NULL);
	g_source_unref (source);
    OUTPUT:
	RETVAL

### FIXME i'm not sure about how to search for the data if we set SVs there.
##gboolean	g_idle_remove_by_data	(gpointer	data);


MODULE = Glib::MainLoop	PACKAGE = Glib::IO	PREFIX = g_io_

guint
g_io_add_watch (class, fd, condition, callback, data=NULL, priority=G_PRIORITY_DEFAULT)
	SV * class
	int fd
	GIOCondition condition
	SV * callback
	SV * data
	gint priority
    PREINIT:
	GClosure * closure;
	GSource * source;
	GIOChannel * channel;
    CODE:
	channel = g_io_channel_unix_new (fd);
	source = g_io_create_watch (channel, condition);
	if (priority != G_PRIORITY_DEFAULT)
		g_source_set_priority (source, priority);
	closure = gperl_closure_new ("Glib::IO", ST(1), callback, data, FALSE);
	g_source_set_closure (source, closure);
	RETVAL = g_source_attach (source, NULL);
	g_source_unref (source);
	g_io_channel_unref (channel);
    OUTPUT:
	RETVAL


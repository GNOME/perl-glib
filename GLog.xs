/*
 * Copyright (C) 2003 by the gtk2-perl team (see the file AUTHORS for the full
 * list)
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

#include "gperl.h"

=head2 GLog

GLib has a message logging mechanism which it uses for the g_return_if_fail()
assertion macros, etc.; it's really versatile and allows you to set various
levels to be fatal and whatnot.  Libraries use these for various types of
message reporting.

These functions let you reroute those messages from Perl.  By default, 
the warning, critical, and message levels go through perl's warn(), and
fatal ones go through croak().  [i'm not sure that these get to croak()
before GLib abort()s on them...]

=over

=cut

#if 0
/* Log level shift offset for user defined
 * log levels (0-7 are used by GLib).
 */
#define G_LOG_LEVEL_USER_SHIFT  (8)

/* GLib log levels that are considered fatal by default */
#define G_LOG_FATAL_MASK        (G_LOG_FLAG_RECURSION | G_LOG_LEVEL_ERROR)
#endif

GType
g_log_level_flags_get_type (void)
{
  static GType etype = 0;
  if ( etype == 0 ) {
    static const GFlagsValue values[] = {
      { G_LOG_FLAG_RECURSION,  "G_LOG_FLAG_RECURSION", "recursion" },
      { G_LOG_FLAG_FATAL,      "G_LOG_FLAG_FATAL",     "fatal" },
     
      { G_LOG_LEVEL_ERROR,     "G_LOG_LEVEL_ERROR",    "error" },
      { G_LOG_LEVEL_CRITICAL,  "G_LOG_LEVEL_CRITICAL", "critical" },
      { G_LOG_LEVEL_WARNING,   "G_LOG_LEVEL_WARNING",  "warning" },
      { G_LOG_LEVEL_MESSAGE,   "G_LOG_LEVEL_MESSAGE",  "message" },
      { G_LOG_LEVEL_INFO,      "G_LOG_LEVEL_INFO",     "info" },
      { G_LOG_LEVEL_DEBUG,     "G_LOG_LEVEL_DEBUG",    "debug" },
     
      { G_LOG_FATAL_MASK,      "G_LOG_FATAL_MASK",     "fatal-mask" },

      { 0, NULL, NULL }
    };
    etype = g_flags_register_static ("GLogLevelFlags", values);
  }
  return etype;
}

SV *
newSVGLogLevelFlags (GLogLevelFlags flags)
{
	return gperl_convert_back_flags (g_log_level_flags_get_type (), flags);
}

GLogLevelFlags
SvGLogLevelFlags (SV * sv)
{
	return gperl_convert_flags (g_log_level_flags_get_type (), sv);
}

static void
gperl_log_func (const gchar   *log_domain,
                GLogLevelFlags log_level,
                const gchar   *message,
                gpointer       user_data)
{
	gperl_callback_invoke ((GPerlCallback *) user_data, NULL,
	                       log_domain, log_level, message);
}

void
gperl_log_handler (const gchar   *log_domain,
                   GLogLevelFlags log_level,
                   const gchar   *message,
                   gpointer user_data)
{
	char * full_string;
	char * desc;

	gboolean in_recursion = (log_level & G_LOG_FLAG_RECURSION) != 0;
	gboolean is_fatal = (log_level & G_LOG_FLAG_FATAL) != 0;
	user_data = user_data; /* unused */

	log_level &= G_LOG_LEVEL_MASK;

	if (!message)
		message = "(NULL) message";
	
	switch (log_level) {
		case G_LOG_LEVEL_CRITICAL: desc = "CRITICAL"; break;
		case G_LOG_LEVEL_ERROR:    desc = "ERROR";    break;
		case G_LOG_LEVEL_WARNING:  desc = "WARNING";  break;
		case G_LOG_LEVEL_MESSAGE:  desc = "Message";  break;
		default: desc = "LOG";
	}

	full_string = form ("%s%s%s %s**: %s",
	                    (log_domain ? log_domain : ""),
	                    (log_domain ? "-" : ""),
	                    desc,
	                    (in_recursion ? "(recursed) " : ""),
	                    message);

	if (is_fatal)
		croak (full_string);
	else
		warn (full_string);
}

#define ALL_LOGS (G_LOG_LEVEL_MASK | G_LOG_FLAG_FATAL | G_LOG_FLAG_RECURSION)

=item gint gperl_handle_logs_for (const gchar * log_domain)

Route all g_logs for I<log_domain> through gperl's log handling.  You'll
have to register domains in each binding submodule, because there's no way
we can know about them down here.

And, technically, this traps all the predefined log levels, not any of
the ones you (or your library) may define for yourself.

=cut
gint
gperl_handle_logs_for (const gchar * log_domain)
{
	return g_log_set_handler (log_domain, ALL_LOGS,
	                          gperl_log_handler, NULL);
}

=back

=cut

MODULE = Glib::Log	PACKAGE = Glib::Log	PREFIX = g_log_

=for object Glib::Log A flexible logging mechanism
=cut

BOOT:
	gperl_handle_logs_for (NULL);
	/* gperl_handle_logs_for ("main"); */
	gperl_handle_logs_for ("GLib");
	gperl_handle_logs_for ("GLib-GObject");
	gperl_register_fundamental (g_log_level_flags_get_type (),
	                            "Glib::LogLevelFlags");

=for flags Glib::LogLevelFlags
=cut

##
## Logging mechanism
##
##guint g_log_set_handler (const gchar *log_domain, GLogLevelFlags log_levels, GLogFunc log_func, gpointer user_data);
=for apidoc

=for arg log_domain name of the domain to handle with this callback.

=arg log_levels (GLogLevelFlags) log levels to handle with this callback

=arg log_func (subroutine) handler function

=cut
guint
g_log_set_handler (class, gchar_ornull * log_domain, SV * log_levels, SV * log_func, SV * user_data=NULL)
    PREINIT:
	GPerlCallback * callback;
	GType param_types[] = {
		G_TYPE_STRING,
		g_log_level_flags_get_type (),
		G_TYPE_STRING
	};
    CODE:
	callback = gperl_callback_new (log_func, user_data,
	                               3, param_types, G_TYPE_NONE);
	RETVAL = g_log_set_handler (log_domain,
				    SvGLogLevelFlags (log_levels),
				    gperl_log_func, callback);
	/* we have no choice but to leak the callback. */
	/* FIXME what about keeping a hash by the ID, and freeing it on
	 *       Glib::Log->remove_handler ($id)? */
        /*pcg: would probably take more memory in typical programs... */
    OUTPUT:
	RETVAL

##void g_log_remove_handler (const gchar *log_domain, guint handler_id);
=for apidoc
=for arg handler_id as returned by C<set_handler>
=cut
void
g_log_remove_handler (class, gchar_ornull *log_domain, guint handler_id);
    C_ARGS:
	log_domain, handler_id

##void g_log_default_handler (const gchar *log_domain, GLogLevelFlags log_level, const gchar *message, gpointer unused_data);

# this is a little ugly, because i didn't want to export a typemap for
# GLogLevelFlags.

MODULE = Glib::Log	PACKAGE = Glib	PREFIX = g_

=for object Glib::Log
=cut

void g_log (class, gchar_ornull * log_domain, SV * log_level, const gchar *message)
    CODE:
	g_log (log_domain, SvGLogLevelFlags (log_level), message);

MODULE = Glib::Log	PACKAGE = Glib::Log	PREFIX = g_log_

SV * g_log_set_fatal_mask (class, const gchar *log_domain, SV * fatal_mask);
    CODE:
	RETVAL = newSVGLogLevelFlags 
		(g_log_set_fatal_mask (log_domain,
		                       SvGLogLevelFlags (fatal_mask)));
    OUTPUT:
	RETVAL

SV * g_log_set_always_fatal (class, SV * fatal_mask);
    CODE:
	RETVAL = newSVGLogLevelFlags 
		(g_log_set_always_fatal (SvGLogLevelFlags (fatal_mask)));
    OUTPUT:
	RETVAL


##
## there are, indeed, some incidences in which it would be handy to have
## perl hooks into the g_log mechanism
##

##ifndef G_LOG_DOMAIN
##define G_LOG_DOMAIN    ((gchar*) 0)
##endif  /* G_LOG_DOMAIN */

MODULE = Glib::Log	PACKAGE = Glib

=for object Glib::Log
=cut

###
### these are of dubious value, but i imagine that they could be useful...
###
##define g_error(...)    g_log (G_LOG_DOMAIN, G_LOG_LEVEL_ERROR, __VA_ARGS__)
##define g_message(...)  g_log (G_LOG_DOMAIN, G_LOG_LEVEL_MESSAGE, __VA_ARGS__)
##define g_critical(...) g_log (G_LOG_DOMAIN, G_LOG_LEVEL_CRITICAL, __VA_ARGS__)
##define g_warning(...)  g_log (G_LOG_DOMAIN, G_LOG_LEVEL_WARNING, __VA_ARGS__)
void
error (class, gchar_ornull * domain, const gchar * message)
    ALIAS:
	error = 0
	message = 1
	critical = 2
	warning = 3
    PREINIT:
	GLogLevelFlags flags = G_LOG_LEVEL_MESSAGE;
    CODE:
	switch (ix) {
		case 0: flags = G_LOG_LEVEL_ERROR; break;
		case 1: flags = G_LOG_LEVEL_MESSAGE; break;
		case 2: flags = G_LOG_LEVEL_CRITICAL; break;
		case 3: flags = G_LOG_LEVEL_WARNING; break;
	}
	g_log (domain, flags, message);

##
## these are not needed -- perl's print() and warn() do the job.
##
## typedef void (*GPrintFunc) (const gchar *string);
## void g_print (const gchar *format, ...) G_GNUC_PRINTF (1, 2);
## GPrintFunc g_set_print_handler (GPrintFunc func);
## void g_printerr (const gchar *format, ...) G_GNUC_PRINTF (1, 2);
## GPrintFunc g_set_printerr_handler (GPrintFunc func);
##

##
## the assertion and return macros aren't really useful at all in perl;
## there are native perl replacements for them on CPAN.
##
##define g_assert(expr)
##define g_assert_not_reached()
##define g_return_if_fail(expr)
##define g_return_val_if_fail(expr,val)
##define g_return_if_reached()
##define g_return_val_if_reached(val)


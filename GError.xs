/*
 * Copyright (C) 2004 by the gtk2-perl team (see the file AUTHORS for the full
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
#include "gperl-gtypes.h"

=head2 GError Exception Objects

GError is a facility for propagating run-time error / exception information
around in C, which is a language without native support for exceptions.
GError uses a simple error code, usually defined as an enum.  Since the
enums will overlap, GError includes the GQuark corresponding to a particular
error "domain" to tell you which error codes will be used.  There's also a
string containing a specific error message.  The strings are arbitrary, and
may be translated, but the domains and codes are definite.

Perl has native support for exceptions, using C<eval> as "try", C<croak> or
C<die> as "throw", and C<< if ($@) >> as "catch".  C<$@> may, in fact, be
any scalar, including blessed objects.

So, GPerl maps GLib's GError to Perl exceptions.

Since, as we described above, error messages are not guaranteed to be unique
everywhere, we need to support the use of the error domains and codes.
The obvious choice here is to use exception objects; however, to support
blessed exception objects, we must perform a little bit of black magic in
the bindings.   There is no built-in association between an error domain
quark and the GType of the corresponding error code enumeration, so the
bindings supply both of these when specifying the name of the package into
which to bless exceptions of this domain.  All GError-based exceptions 
derive from Glib::Error, of course, and this base class provides all of the
functionality, including stringification.

All you'll really ever need to do is register error domains with
C<gperl_register_error_domain>, and throw errors with C<gperl_croak_gerror>.

=over

=cut

typedef struct {
	GQuark  domain;
	GType   error_enum;
	char  * package;
} ErrorInfo;

static ErrorInfo *
error_info_new (GQuark domain, GType error_enum, const char * package)
{
	ErrorInfo * info = g_new (ErrorInfo, 1);
	info->domain = domain;
	info->error_enum = error_enum;
	info->package = package ? g_strdup (package) : NULL;
	return info;
}

static void
error_info_free (ErrorInfo * info)
{
	if (info) {
		info->domain = 0;
		info->error_enum = 0;
		if (info->package)
			g_free (info->package);
		info->package = NULL;
		g_free (info);
	}
}

static GHashTable * errors_by_domain = NULL;

=item void gperl_register_error_domain (GQuark domain, GType error_enum, const char * package)

Tell the bindings to bless GErrors with error->domain == I<domain> into
I<package>, and use I<error_enum> to find the nicknames for the error codes.
This will call C<gperl_set_isa> on I<package> to add "Glib::Error" to
I<package>'s @ISA.

I<domain> may not be 0, and I<package> may not be NULL; what would be the 
point?  I<error_enum> may be 0, in which case you'll get no fancy stringified
error values.

=cut
void
gperl_register_error_domain (GQuark domain,
                             GType error_enum,
                             const char * package)
{
	g_return_if_fail (domain != 0); /* pointless without this */
	g_return_if_fail (package != NULL); /* or this */

	if (!errors_by_domain)
		errors_by_domain = g_hash_table_new_full
					(g_direct_hash,
					 g_direct_equal,
					 NULL,
					 (GDestroyNotify) error_info_free);

	g_hash_table_insert (errors_by_domain,
	                     GUINT_TO_POINTER (domain),
	                     error_info_new (domain, error_enum, package));
	gperl_set_isa (package, "Glib::Error");
}

=item SV * gperl_sv_from_gerror (GError * error)

You should rarely, if ever, need to call this function.  This is what turns
a GError into a Perl object.

=cut
SV *
gperl_sv_from_gerror (GError * error)
{
	HV * hv;
	ErrorInfo * info;
	char * package;

	if (!error)
		return newSVsv (&PL_sv_undef);

	info = (ErrorInfo*)
		g_hash_table_lookup (errors_by_domain,
		                     GUINT_TO_POINTER (error->domain));

	hv = newHV ();
	hv_store (hv, "domain", 6,
	          newSVGChar (g_quark_to_string (error->domain)), 0);
	hv_store (hv, "code", 4, newSViv (error->code), 0);
	if (info)
		hv_store (hv, "value", 5,
		          gperl_convert_back_enum (info->error_enum,
		                                   error->code),
		          0);
	hv_store (hv, "message", 7, newSVGChar (error->message), 0);

	/* WARNING: using evil undocumented voodoo.  mess() is the function
	 * that die(), warn(), and croak() use to format messages, and it's
	 * what knows how to find the code location.  don't want to do that
	 * ourselves, since that's blacker magic, so we'll call this and 
	 * hope the perl API doesn't change.  */
	hv_store (hv, "location", 8, newSVsv (mess ("")), 0);

	package = info ? info->package : "Glib::Error";

	return sv_bless (newRV_noinc ((SV*) hv), gv_stashpv (package, TRUE)); 
}


=item void gperl_croak_gerror (const char * ignored, GError * err)

Croak with an exception based on I<err>.  I<err> may not be NULL.  I<ignored>
exists for backward compatibility, and is, well, ignored.  This function
calls croak(), which does not return.

Since croak() does not return, this function handles the magic behind 
not leaking the memory associated with the #GError.  To use this you'd
do something like

 PREINIT:
   GError * error = NULL;
 CODE:
   if (!funtion_that_can_fail (something, &error))
      gperl_croak_gerror (NULL, error);

It's just that simple!

=cut
void
gperl_croak_gerror (const char * ignored, GError * err)
{
	/* this really could only happen if there's a problem with XS bindings
	 * so we'll use a assertion to catch it, rather than handle null */
	g_return_if_fail (err != NULL);

	sv_setsv (ERRSV, gperl_sv_from_gerror (err));

	/* croak() does not return; free this now to avoid leaking it. */
	g_error_free (err);
	croak (Nullch);
}

=back

=cut

MODULE = Glib::Error	PACKAGE = Glib::Error	

BOOT:
	/* i can't quite decide whether i'm happy about registering all
	 * of these here.  in theory, it's possible to get any of these,
	 * so we should define them for later use; in practice, we may
	 * never see a few of them. */
	/* gconvert.h */
	gperl_register_error_domain (G_CONVERT_ERROR,
	                             GPERL_TYPE_CONVERT_ERROR,
	                             "Glib::Convert::Error");
	/* gfileutils.h */
	gperl_register_error_domain (G_FILE_ERROR,
	                             GPERL_TYPE_FILE_ERROR,
	                             "Glib::File::Error");
	/* giochannel.h */
	gperl_register_error_domain (G_IO_CHANNEL_ERROR,
	                             GPERL_TYPE_IO_CHANNEL_ERROR,
	                             "Glib::IOChannel::Error");
	/* gmarkup.h */
	gperl_register_error_domain (G_MARKUP_ERROR,
	                             GPERL_TYPE_MARKUP_ERROR,
	                             "Glib::Markup::Error");
	/* gshell.h */
	gperl_register_error_domain (G_SHELL_ERROR,
	                             GPERL_TYPE_SHELL_ERROR,
	                             "Glib::Shell::Error");
	/* gspawn.h */
	gperl_register_error_domain (G_SPAWN_ERROR,
	                             GPERL_TYPE_SPAWN_ERROR,
	                             "Glib::Spawn::Error");
	/* gthread.h */
	gperl_register_error_domain (G_THREAD_ERROR,
	                             GPERL_TYPE_THREAD_ERROR,
	                             "Glib::Thread::Error");
	

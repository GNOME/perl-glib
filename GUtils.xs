/*
 * Copyright (C) 2004 by the gtk2-perl team (see the file AUTHORS for a 
 * complete list)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */
#include "gperl.h"

MODULE = Glib::Utils	PACKAGE = Glib	PREFIX = g_


##
## are these effectively replaced by perl equivalents?    :
##
#G_CONST_RETURN gchar* g_get_user_name        (void);
#G_CONST_RETURN gchar* g_get_real_name        (void);
#G_CONST_RETURN gchar* g_get_home_dir         (void);
#G_CONST_RETURN gchar* g_get_tmp_dir          (void);
#gchar*                g_get_prgname          (void);
#void                  g_set_prgname          (const gchar *prgname);
#G_CONST_RETURN gchar* g_get_application_name (void);
#void                  g_set_application_name (const gchar *application_name);
#
#
## Check if a file name is an absolute path
#gboolean              g_path_is_absolute   (const gchar *file_name);
#
## In case of absolute paths, skip the root part
#G_CONST_RETURN gchar* g_path_skip_root     (const gchar *file_name);
#
#
## The returned strings are newly allocated with g_malloc()
#gchar*                g_get_current_dir    (void);
#gchar*                g_path_get_basename  (const gchar *file_name);
#gchar*                g_path_get_dirname   (const gchar *file_name);
#
#
## Look for an executable in PATH, following execvp() rules
#gchar*  g_find_program_in_path  (const gchar *program);
#
#
## Glib version.
## we prefix variable declarations so they can
## properly get exported in windows dlls.
##
#GLIB_VAR const guint glib_major_version;
#GLIB_VAR const guint glib_minor_version;
#GLIB_VAR const guint glib_micro_version;
#GLIB_VAR const guint glib_interface_age;
#GLIB_VAR const guint glib_binary_age;

=for apidoc __hide__
=for signature (major_version, minor_version, micro_version) = Gtk2::get_version_info
=cut
void
get_version_info ()
    PPCODE:
	EXTEND(SP,3);
	PUSHs(sv_2mortal(newSViv(glib_major_version)));
	PUSHs(sv_2mortal(newSViv(glib_minor_version)));
	PUSHs(sv_2mortal(newSViv(glib_micro_version)));
	PERL_UNUSED_VAR (ax);


=for apidoc __hide__
=for signature boolean = Glib::check_version ($major, $minor, $micro)

Returns true if the version of glib against which we are linked and running
is at least (I<$major>, I<$minor>, I<$micro>).

=cut
###define GLIB_CHECK_VERSION(major,minor,micro)
gboolean
check_version (int major, int minor, int micro)
    CODE:
	RETVAL = GLIB_CHECK_VERSION (major, minor, micro);
    OUTPUT:
	RETVAL

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
 *
 * $Header$
 */
#include "gperl.h"

MODULE = Glib::Utils	PACKAGE = Glib	PREFIX = g_

=for object Glib::Version
=cut

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

=for apidoc Glib::MAJOR_VERSION
Provides access to the version information that Glib was compiled against.
Essentially equivalent to the #define's GLIB_MAJOR_VERSION.
=cut

=for apidoc Glib::MINOR_VERSION
Provides access to the version information that Glib was compiled against.
Essentially equivalent to the #define's GLIB_MINOR_VERSION.
=cut

=for apidoc Glib::MICRO_VERSION
Provides access to the version information that Glib was compiled against.
Essentially equivalent to the #define's GLIB_MICRO_VERSION.
=cut

=for apidoc Glib::major_version
Provides access to the version information that Glib is linked against.
Essentially equivalent to the global variable glib_major_version.
=cut

=for apidoc Glib::minor_version
Provides access to the version information that Glib is linked against.
Essentially equivalent to the global variable glib_minor_version.
=cut

=for apidoc Glib::micro_version
Provides access to the version information that Glib is linked against.
Essentially equivalent to the global variable glib_micro_version.
=cut

guint
MAJOR_VERSION ()
    ALIAS:
	Glib::MINOR_VERSION = 1
	Glib::MICRO_VERSION = 2
	Glib::major_version = 3
	Glib::minor_version = 4
	Glib::micro_version = 5
    CODE:
	switch (ix)
	{
	case 0: RETVAL = GLIB_MAJOR_VERSION; break;
	case 1: RETVAL = GLIB_MINOR_VERSION; break;
	case 2: RETVAL = GLIB_MICRO_VERSION; break;
	case 3: RETVAL = glib_major_version; break;
	case 4: RETVAL = glib_minor_version; break;
	case 5: RETVAL = glib_micro_version; break;
	default:
		RETVAL = -1;
		g_assert_not_reached ();
	}
    OUTPUT:
	RETVAL

=for apidoc
Provides a mechanism for checking the version information that Glib was
compiled against. Essentially equvilent to the macro GLIB_CHECK_VERSION.
=cut
gboolean
CHECK_VERSION (class, guint required_major, guint required_minor, guint required_micro)
    CODE:
	RETVAL = GLIB_CHECK_VERSION (required_major, required_minor,
				    required_micro);
    OUTPUT:
	RETVAL

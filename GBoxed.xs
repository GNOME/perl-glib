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

static GHashTable * info_by_gtype = NULL;
static GHashTable * info_by_package = NULL;

typedef struct _BoxedInfo BoxedInfo;
typedef struct _BoxedWrapper BoxedWrapper;

struct _BoxedInfo {
	GType gtype;
	char * package;
	GPerlBoxedPackageFunc get_package;
};


BoxedInfo *
boxed_info_new (GType gtype,
		const char * package,
		GPerlBoxedPackageFunc get_package)
{
	BoxedInfo * boxed_info;
	boxed_info = g_new0 (BoxedInfo, 1);
	boxed_info->gtype = gtype;
	boxed_info->package = package ? g_strdup (package) : NULL;
	boxed_info->get_package = get_package;
	return boxed_info;
}

void
boxed_info_destroy (BoxedInfo * boxed_info)
{
	if (boxed_info) {
		boxed_info->gtype = 0;
		if (boxed_info->package)
			g_free (boxed_info->package);
		boxed_info->package = NULL;
		boxed_info->get_package = NULL;
		g_free (boxed_info);
	}
}

void
gperl_register_boxed (GType gtype,
		      const char * package,
		      GPerlBoxedPackageFunc get_package)
{
	BoxedInfo * boxed_info;
	if (!info_by_gtype) {
		info_by_gtype = g_hash_table_new_full (g_direct_hash,
						       g_direct_equal,
						       NULL, 
						       (GDestroyNotify)
							 boxed_info_destroy);
		info_by_package = g_hash_table_new_full (g_str_hash,
						         g_str_equal,
						         NULL, 
						         NULL);
	}
	boxed_info = boxed_info_new (gtype, package, get_package);
	g_hash_table_insert (info_by_gtype, (gpointer) gtype, boxed_info);
	g_hash_table_insert (info_by_package, (gchar*)package, boxed_info);

	/* FIXME add isa setting stuff like in gperl_register_object? */
#ifdef NOISY
	warn ("gperl_register_boxed (%d(%s), %s, %p)\n",
	      gtype, g_type_name (gtype), package, get_package);
#endif
}

GType
gperl_boxed_type_from_package (const char * package)
{
	BoxedInfo * boxed_info;

	boxed_info = (BoxedInfo*)
		g_hash_table_lookup (info_by_package, package);
	if (!boxed_info)
		return 0;
	return boxed_info->gtype;
}

const char *
gperl_boxed_package_from_type (GType type)
{
	BoxedInfo * boxed_info;

	boxed_info = (BoxedInfo*)
		g_hash_table_lookup (info_by_gtype, (gpointer)type);
	if (!boxed_info)
		return NULL;
	return boxed_info->package;
}

/************************************************************/

/* inspired by pygtk */
struct _BoxedWrapper {
	gpointer boxed;
	GType gtype;
	gboolean free_on_destroy;
};

BoxedWrapper *
boxed_wrapper_new (gpointer boxed,
                   GType gtype,
                   gboolean free_on_destroy)
{
	BoxedWrapper * boxed_wrapper;
	boxed_wrapper = g_new (BoxedWrapper, 1);
	boxed_wrapper->boxed = boxed;
	boxed_wrapper->gtype = gtype;
	boxed_wrapper->free_on_destroy = free_on_destroy;
	return boxed_wrapper;
}

void
boxed_wrapper_destroy (BoxedWrapper * boxed_wrapper)
{
	if (boxed_wrapper) {
		if (boxed_wrapper->free_on_destroy)
			g_boxed_free (boxed_wrapper->gtype, boxed_wrapper->boxed);
		g_free (boxed_wrapper);
	} else {
		warn ("boxed_wrapper_destroy called on NULL pointer");
	}
}

static const char *
get_package (BoxedInfo * boxed_info,
             gpointer boxed)
{
	const char * package = NULL;
	if (boxed_info->get_package)
		package = boxed_info->get_package (boxed_info->gtype, 
						   boxed);
	if (package == NULL)
		package = boxed_info->package;

	if (package == NULL)
		croak ("internal problem: no valid package found for GType %s (%d)",
			g_type_name (boxed_info->gtype), boxed_info->gtype);

	return package;
}

SV *
gperl_new_boxed (gpointer boxed,
		 GType gtype,
		 gboolean own)
{
	SV * sv;
	BoxedInfo * boxed_info;
	BoxedWrapper * boxed_wrapper;
	const char * package;

	if (!boxed)
		croak ("NULL pointer made it into gperl_new_boxed");

	boxed_wrapper = boxed_wrapper_new (boxed, gtype, own);

	boxed_info = (BoxedInfo*)
		g_hash_table_lookup (info_by_gtype, (gpointer) gtype);

	if (!boxed_info)
		croak ("GType %s (%d) is not registerer with gperl",
		       g_type_name (gtype), gtype);

	package = get_package (boxed_info, boxed);

	sv = newSV (0);
	sv_setref_pv (sv, package, boxed_wrapper);

#ifdef NOISY
	warn ("created boxed wrapper 0x%p for %s 0x%p",
	      boxed_wrapper, package, boxed);
#endif
	return sv;
}

SV *
gperl_new_boxed_copy (gpointer boxed,
                      GType gtype)
{
	return gperl_new_boxed (g_boxed_copy (gtype, boxed), gtype, TRUE);
}

#define _get_boxed_wrapper(sv) ((BoxedWrapper*) SvIV (SvRV (sv)))

gpointer
gperl_get_boxed_check (SV * sv, GType gtype)
{
	BoxedWrapper * boxed_wrapper;
	BoxedInfo * boxed_info;
	const char * package;

	if (!sv || !SvTRUE (sv))
		croak ("variable not allowed to be undef where %s is wanted",
		       g_type_name (gtype));
	boxed_wrapper = _get_boxed_wrapper (sv);
	if (!boxed_wrapper)
		croak ("internal nastiness: boxed wrapper contains NULL pointer");

	boxed_info = g_hash_table_lookup (info_by_gtype,
	                                  (gpointer)gtype);
	if (!boxed_info)
		croak ("internal problem: GType %s (%d) has not been registered with GPerl",
			gtype, g_type_name (gtype));

	package = get_package (boxed_info, boxed_wrapper->boxed);

	if (!sv_derived_from (sv, package))
		croak ("variable is not of type %s", package);
	return boxed_wrapper->boxed;
}


MODULE = Glib::Boxed	PACKAGE = Glib::Boxed

BOOT:
	gperl_register_boxed (G_TYPE_BOXED, "Glib::Boxed", NULL);
	gperl_register_boxed (G_TYPE_STRING, "Glib::String", NULL);
	gperl_set_isa ("Glib::String", "Glib::Boxed");

void
DESTROY (sv)
	SV * sv
    CODE:
#ifdef NOISY
	{
	BoxedWrapper * wrapper = _get_boxed_wrapper (sv);
	warn ("Glib::Boxed::DESTROY wrapper 0x%p --- %s 0x%p\n", wrapper,
	      g_type_name (wrapper ? wrapper->gtype : 0),
	      wrapper ? wrapper->boxed : NULL);
	}
#endif
	boxed_wrapper_destroy (_get_boxed_wrapper (sv));

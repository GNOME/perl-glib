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

//#define NOISY

/*

BoxedInfo

similar to ClassInfo in GObject.xs, BoxedInfo stores information about a
boxed type's mapping from C to perl.  we keep two hashes of these structures,
one indexed by GType, the other by perl package name, for quick and easy
lookup.

the fundamental job of this mapping is to tell us what perl package 
corresponds to a particular GType.

the next most important thing is the wrapper_class --- this tells the bindings
what set of functions to use to convert this boxed type in and out of perl.
a default implementation is supplied; see the BoxedWrapper and default_*
stuff.

 */

static GHashTable * info_by_gtype = NULL;
static GHashTable * info_by_package = NULL;

typedef struct _BoxedInfo BoxedInfo;
typedef struct _BoxedWrapper BoxedWrapper;

struct _BoxedInfo {
	GType                    gtype;
	char                   * package;
	GPerlBoxedWrapperClass * wrapper_class;
};


BoxedInfo *
boxed_info_new (GType gtype,
		const char * package,
		GPerlBoxedWrapperClass * wrapper_class)
{
	BoxedInfo * boxed_info;
	boxed_info = g_new0 (BoxedInfo, 1);
	boxed_info->gtype = gtype;
	boxed_info->package = package ? g_strdup (package) : NULL;
	boxed_info->wrapper_class = wrapper_class;
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
		boxed_info->wrapper_class = NULL;
		g_free (boxed_info);
	}
}

void
gperl_register_boxed (GType gtype,
                      const char * package,
                      GPerlBoxedWrapperClass * wrapper_class)
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
	boxed_info = boxed_info_new (gtype, package, wrapper_class);
	g_hash_table_insert (info_by_gtype, (gpointer) gtype, boxed_info);
	g_hash_table_insert (info_by_package, (gchar*)package, boxed_info);

	/* FIXME add isa setting stuff like in gperl_register_object? */
	if (package && gtype != G_TYPE_BOXED)
		gperl_set_isa (package, "Glib::Boxed");
#ifdef NOISY
	warn ("gperl_register_boxed (%d(%s), %s, %p)\n",
	      gtype, g_type_name (gtype), package, wrapper_class);
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

/*
BoxedWrapper

In order to make life simple, we supply a default GPerlBoxedWrapperClass,
which wraps boxed type objects into an opaque data structure.

GBoxed types don't know what their own type is, nor do they give you a way
to store metadata.  thus, we actually wrap a BoxedWrapper struct into 
the perl wrapper, and store the boxed object and some metadata in the
BoxedWrapper.
*/

/* inspired by pygtk */
struct _BoxedWrapper {
	gpointer boxed;
	GType gtype;
	gboolean free_on_destroy;
};

static BoxedWrapper *
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

static void
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

static SV *
default_boxed_wrap (GType        gtype,
		    const char * package,
		    gpointer     boxed,
		    gboolean     own)
{
	SV * sv;
	BoxedWrapper * boxed_wrapper;

	boxed_wrapper = boxed_wrapper_new (boxed, gtype, own);

	sv = newSV (0);
	sv_setref_pv (sv, package, boxed_wrapper);

#ifdef NOISY
	warn ("default_boxed_wrap 0x%p for %s 0x%p",
	      boxed_wrapper, package, boxed);
#endif
	return sv;
}

static gpointer
default_boxed_unwrap (GType        gtype,
		      const char * package,
		      SV         * sv)
{
	BoxedWrapper * boxed_wrapper;

	if (!SvROK (sv))
		croak ("expected a blessed reference");

	if (!sv_derived_from (sv, package))
		croak ("variable is not of type %s", package);

	boxed_wrapper = (BoxedWrapper*) SvIV (SvRV (sv));
	if (!boxed_wrapper)
		croak ("internal nastiness: boxed wrapper contains NULL pointer");
	return boxed_wrapper->boxed;

}

static void
default_boxed_destroy (SV * sv)
{
#ifdef NOISY
	{
	BoxedWrapper * wrapper = (BoxedWrapper*) SvIV (SvRV (sv));
	warn ("default_boxed_destroy wrapper 0x%p --- %s 0x%p\n", wrapper,
	      g_type_name (wrapper ? wrapper->gtype : 0),
	      wrapper ? wrapper->boxed : NULL);
	}
#endif
	boxed_wrapper_destroy ((BoxedWrapper*) SvIV (SvRV (sv)));
}


static GPerlBoxedWrapperClass _default_wrapper_class = {
	default_boxed_wrap,
	default_boxed_unwrap,
	default_boxed_destroy
};

GPerlBoxedWrapperClass *
gperl_default_boxed_wrapper_class (void)
{
	return &_default_wrapper_class;
}

/***************************************************************************/


SV *
gperl_new_boxed (gpointer boxed,
		 GType gtype,
		 gboolean own)
{
	BoxedInfo * boxed_info;
	GPerlBoxedWrapFunc wrap;

	if (!boxed)
		croak ("NULL pointer made it into gperl_new_boxed");

	boxed_info = (BoxedInfo*)
		g_hash_table_lookup (info_by_gtype, (gpointer) gtype);

	if (!boxed_info)
		croak ("GType %s (%d) is not registerer with gperl",
		       g_type_name (gtype), gtype);

	wrap = boxed_info->wrapper_class
	     ? boxed_info->wrapper_class->wrap
	     : _default_wrapper_class.wrap;
	
	if (!wrap)
		croak ("no function to wrap boxed objects of type %s / %s",
		       g_type_name (gtype), boxed_info->package);

	return (*wrap) (gtype, boxed_info->package, boxed, own);
}


SV *
gperl_new_boxed_copy (gpointer boxed,
                      GType gtype)
{
	return gperl_new_boxed (g_boxed_copy (gtype, boxed), gtype, TRUE);
}


gpointer
gperl_get_boxed_check (SV * sv, GType gtype)
{
	BoxedInfo * boxed_info;
	GPerlBoxedUnwrapFunc unwrap;

	if (!sv || !SvTRUE (sv))
		croak ("variable not allowed to be undef where %s is wanted",
		       g_type_name (gtype));

	boxed_info = g_hash_table_lookup (info_by_gtype,
	                                  (gpointer)gtype);
	if (!boxed_info)
		croak ("internal problem: GType %s (%d) has not been registered with GPerl",
			gtype, g_type_name (gtype));

	unwrap = boxed_info->wrapper_class
	       ? boxed_info->wrapper_class->unwrap
	       : _default_wrapper_class.unwrap;

	if (!unwrap)
		croak ("no function to unwrap boxed objects of type %s / %s",
		       g_type_name (gtype), boxed_info->package);

	return (*unwrap) (gtype, boxed_info->package, sv);
}



MODULE = Glib::Boxed	PACKAGE = Glib::Boxed

BOOT:
	gperl_register_boxed (G_TYPE_BOXED, "Glib::Boxed", NULL);
	gperl_register_boxed (G_TYPE_STRING, "Glib::String", NULL);
	gperl_set_isa ("Glib::String", "Glib::Boxed");

void
DESTROY (sv)
	SV * sv
    PREINIT:
	BoxedInfo * boxed_info;
	char * class;
	GPerlBoxedDestroyFunc destroy;
    CODE:
	if (!sv && !SvOK (sv) && !SvROK (sv) && !SvRV (sv))
		croak ("DESTROY called on a bad value");

	/* we need to find the wrapper class associated with whatever type
	 * the wrapper is blessed into. */
	class = sv_reftype (SvRV (sv), TRUE);
	boxed_info = g_hash_table_lookup (info_by_package, class);
#ifdef NOISY
	warn ("Glib::Boxed::DESTROY (%s) for %s -> %s", 
	      SvPV_nolen (sv),
	      class,
	      boxed_info ? g_type_name (boxed_info->gtype) : NULL);
#endif
#if 0
	if (!boxed_info) {
		warn ("no boxed_info type matches this boxed subclass.  assuming it's a default wrapper.  This is not necessarily a good idea.");
		destroy = _default_wrapper_class.destroy;
	} else
#endif
	destroy = boxed_info
	        ? (boxed_info->wrapper_class
		      ? boxed_info->wrapper_class->destroy
		      : _default_wrapper_class.destroy)
		: NULL;
	if (destroy)
		(*destroy) (sv);

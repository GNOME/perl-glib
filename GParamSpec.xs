/*
 * Copyright (C) 2003-2004, 2010 by the gtk2-perl team (see the file AUTHORS for
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
 * $Id$
 */

#include "gperl.h"

/*
 * this isn't already done for us.  :-(
 *
 * interestingly, the obvious G_TYPE_PARAM_FLAGS is taken by the 
 * GParamSpecFlags.
 */

static GType
g_param_flags_get_type (void)
{
  static GType etype = 0;
  if (etype == 0) {
    static const GFlagsValue values[] = {
      {G_PARAM_READABLE,       "G_PARAM_READABLE",       "readable"},
      {G_PARAM_WRITABLE,       "G_PARAM_WRITABLE",       "writable"},
      {G_PARAM_CONSTRUCT,      "G_PARAM_CONSTRUCT",      "construct"},
      {G_PARAM_CONSTRUCT_ONLY, "G_PARAM_CONSTRUCT_ONLY", "construct-only"},
      {G_PARAM_LAX_VALIDATION, "G_PARAM_LAX_VALIDATION", "lax-validation"},
      {G_PARAM_PRIVATE,        "G_PARAM_PRIVATE",        "private"},
      {0, NULL, NULL}
    };
    etype = g_flags_register_static ("GPerlParamFlags", values);
  }
  return etype;
}


SV *
newSVGParamFlags (GParamFlags flags)
{
	return gperl_convert_back_flags (g_param_flags_get_type (), flags);
}

GParamFlags
SvGParamFlags (SV * sv)
{
	return gperl_convert_flags (g_param_flags_get_type (), sv);
}

static GHashTable * param_package_by_type = NULL;

void
gperl_register_param_spec (GType gtype,
                           const char * package)
{
	if (!param_package_by_type) {
		param_package_by_type =
			g_hash_table_new_full (g_direct_hash,
			                       g_direct_equal,
			                       NULL,
			                       g_free);
		g_hash_table_insert (param_package_by_type,
		                     (gpointer) G_TYPE_PARAM,
		                     g_strdup ("Glib::ParamSpec"));
	}
	g_hash_table_insert (param_package_by_type,
	                     (gpointer) gtype,
	                     g_strdup (package));
	gperl_set_isa (package, "Glib::ParamSpec");
}

const char *
gperl_param_spec_package_from_type (GType gtype)
{
	g_return_val_if_fail (param_package_by_type != NULL, NULL);
	return (const char*) g_hash_table_lookup (param_package_by_type,
	                                          (gpointer) gtype);
}

/*
 * reverse lookup for paramspec types will be really rare, so we'll save
 * some storage space by sacrificing traversal time.
 */
struct FindData {
	const char * package;
	GType found_type;
};
#if GLIB_CHECK_VERSION (2, 4, 0)
static gboolean
find_func (gpointer key,
           gpointer value,
           gpointer user_data)
{
	struct FindData * fd = user_data;
	if (g_str_equal ((const char *) value, fd->package)) {
		fd->found_type = (GType) key;
		return TRUE;
	} else 
		return FALSE;
}
#else
static void
find_func (gpointer key,
           gpointer value,
           gpointer user_data)
{
	struct FindData * fd = user_data;
	if (g_str_equal ((const char *) value, fd->package))
		fd->found_type = (GType) key;
}
#endif

GType
gperl_param_spec_type_from_package (const char * package)
{
	struct FindData fd;
	fd.package = package;
	fd.found_type = 0;
	g_return_val_if_fail (param_package_by_type != NULL, 0);
#if GLIB_CHECK_VERSION (2, 4, 0)
	g_hash_table_find (param_package_by_type, find_func, (gpointer) &fd);
#else
	g_hash_table_foreach (param_package_by_type, find_func, (gpointer) &fd);
#endif
	return fd.found_type;
}

SV *
newSVGParamSpec (GParamSpec * pspec)
{
	const gchar * pv;
	HV * property;
	SV * sv;
	HV * stash;
	const char * package;

	if (!pspec)
		return &PL_sv_undef;

	g_param_spec_ref (pspec);
	g_param_spec_sink (pspec);

	property = newHV ();
	sv_magic ((SV*)property, 0, PERL_MAGIC_ext, (const char*)pspec, 0);


	/* for hysterical raisins (backward compatibility with the old
	 * versions which did not use the same C-to-Perl mapping for the
	 * paramspec list returned from Glib::Object::list_properties())
	 * we store a few select keys in the hash directly.
	 */
	gperl_hv_take_sv_s (property, "name",
	                    newSVpv (g_param_spec_get_name (pspec), 0));

	/* map type names to package names, if possible */
	pv = gperl_package_from_type (pspec->value_type);
	if (!pv) pv = g_type_name (pspec->value_type);
	gperl_hv_take_sv_s (property, "type", newSVpv (pv, 0));

	pv = gperl_package_from_type (pspec->owner_type);
	if (!pv)
		pv = g_type_name (pspec->owner_type);
	if (pv)
		gperl_hv_take_sv_s (property, "owner_type", newSVpv (pv, 0));

	pv = g_param_spec_get_blurb (pspec);
	if (pv) gperl_hv_take_sv_s (property, "descr", newSVpv (pv, 0));
	gperl_hv_take_sv_s (property, "flags", newSVGParamFlags (pspec->flags));

	/* wrap it, bless it, ship it. */
	sv = newRV_noinc ((SV*)property);

	package = gperl_param_spec_package_from_type
					(G_PARAM_SPEC_TYPE (pspec));
	if (!package) {
		package = "Glib::ParamSpec";
		warn ("unhandled paramspec type %s, falling back to %s",
		      G_PARAM_SPEC_TYPE_NAME (pspec), package);
	}

	stash = gv_stashpv (package, TRUE);

	sv_bless (sv, stash);

	return sv;
}

GParamSpec *
SvGParamSpec (SV * sv)
{
	MAGIC * mg;
	if (!sv || !SvROK (sv) || !(mg = mg_find (SvRV (sv), PERL_MAGIC_ext)))
		return NULL;
	return (GParamSpec*) mg->mg_ptr;
}


MODULE = Glib::ParamSpec	PACKAGE = Glib::ParamSpec	PREFIX = g_param_spec_

void
DESTROY (GParamSpec * pspec)
    CODE:
	g_param_spec_unref (pspec);

=for position DESCRIPTION

=head1 DESCRIPTION

Glib::ParamSpec encapsulates the metadata required to specify parameters.
You will see these most often when creating new Glib::Object types; see
C<< Glib::Type->register >> and L<Glib::Object::Subclass>.

Parameter specifications allow you to provide limits for validation as 
well as nicknames and blurbs to document the parameters.  Blurbs show up
in reference documentation such as this page or the gtk+ C API reference;
i'm not really sure where the nicknames get used.  The Perl bindings for
the most part ignore the difference between dashes and underscores in
the paramspec names, which typically find use as the actual keys for 
object parameters.

It's worth noting that Glib offers various sizes of integer and floating
point values, while Perl really only deals with full integers and double
precision floating point values.  The size distinction is important for
the underlying C libraries.

=cut

BOOT:
	gperl_register_fundamental (g_param_flags_get_type (),
	                            "Glib::ParamFlags");
	gperl_register_param_spec (G_TYPE_PARAM_CHAR, "Glib::Param::Char");
	gperl_register_param_spec (G_TYPE_PARAM_UCHAR, "Glib::Param::UChar");
	gperl_register_param_spec (G_TYPE_PARAM_UNICHAR, "Glib::Param::Unichar");
	gperl_register_param_spec (G_TYPE_PARAM_BOOLEAN, "Glib::Param::Boolean");
	gperl_register_param_spec (G_TYPE_PARAM_INT, "Glib::Param::Int");
	gperl_register_param_spec (G_TYPE_PARAM_UINT, "Glib::Param::UInt");
	gperl_register_param_spec (G_TYPE_PARAM_LONG, "Glib::Param::Long");
	gperl_register_param_spec (G_TYPE_PARAM_ULONG, "Glib::Param::ULong");
	gperl_register_param_spec (G_TYPE_PARAM_INT64, "Glib::Param::Int64");
	gperl_register_param_spec (G_TYPE_PARAM_UINT64, "Glib::Param::UInt64");
	gperl_register_param_spec (G_TYPE_PARAM_ENUM, "Glib::Param::Enum");
	gperl_register_param_spec (G_TYPE_PARAM_FLAGS, "Glib::Param::Flags");
	gperl_register_param_spec (G_TYPE_PARAM_FLOAT, "Glib::Param::Float");
	gperl_register_param_spec (G_TYPE_PARAM_DOUBLE, "Glib::Param::Double");
	gperl_register_param_spec (G_TYPE_PARAM_STRING, "Glib::Param::String");
	gperl_register_param_spec (G_TYPE_PARAM_PARAM, "Glib::Param::Param");
	gperl_register_param_spec (G_TYPE_PARAM_BOXED, "Glib::Param::Boxed");
	gperl_register_param_spec (G_TYPE_PARAM_POINTER, "Glib::Param::Pointer");
	gperl_register_param_spec (G_TYPE_PARAM_VALUE_ARRAY, "Glib::Param::ValueArray");
	gperl_register_param_spec (G_TYPE_PARAM_OBJECT, "Glib::Param::Object");
#if GLIB_CHECK_VERSION(2,4,0)
	gperl_register_param_spec (G_TYPE_PARAM_OVERRIDE, "Glib::Param::Override");
#endif
#if GLIB_CHECK_VERSION(2,10,0)
	gperl_register_param_spec (G_TYPE_PARAM_GTYPE, "Glib::Param::GType");
#endif

=for enum Glib::ParamFlags
=cut

## stuff from gparam.h

=for apidoc

=signature string = $paramspec->get_name

Dashes in the name are converted to underscores.

=cut
SV *
g_param_spec_get_name (GParamSpec * pspec)
    CODE:
        char *c;
        RETVAL = newSVpv (g_param_spec_get_name (pspec), 0);
        for (c = SvPV_nolen (RETVAL); c <= SvEND (RETVAL); c++)
                if (*c == '-')
                        *c = '_';
    OUTPUT:
        RETVAL

const gchar* g_param_spec_get_nick (GParamSpec * pspec)

const gchar* g_param_spec_get_blurb (GParamSpec * pspec)


## stuff from gparamspecs.h

###
### glib's param specs offer lots of different sizes of integers and floating
### point values, but perl only supports UV (uint), IV (int), and NV (double).
### so, we can save quite a bit of code space by just aliasing all these
### together (and letting the compiler take care of casting the values to
### the right sizes).
###

##  GParamSpec* g_param_spec_char (const gchar *name, const gchar *nick, const gchar *blurb, gint8 minimum, gint8 maximum, gint8 default_value, GParamFlags flags) 
##  GParamSpec* g_param_spec_int (const gchar *name, const gchar *nick, const gchar *blurb, gint minimum, gint maximum, gint default_value, GParamFlags flags) 
##  GParamSpec* g_param_spec_long (const gchar *name, const gchar *nick, const gchar *blurb, glong minimum, glong maximum, glong default_value, GParamFlags flags) 
GParamSpec*
IV (class, name, nick, blurb, minimum, maximum, default_value, flags)
	const gchar *name
	const gchar *nick
	const gchar *blurb
	IV minimum
	IV maximum
	IV default_value
	GParamFlags flags
    ALIAS:
	IV    = 0
	char  = 1
	int   = 2
	long  = 3
    CODE:
	RETVAL = NULL;
    	switch (ix) {
	    case 1:
		RETVAL = g_param_spec_char (name, nick, blurb,
		                            (char)minimum, (char)maximum,
		                            (char)default_value, flags);
		break;
	    case 2:
		RETVAL = g_param_spec_int (name, nick, blurb,
		                           minimum, maximum, default_value,
		                           flags);
		break;
	    case 0:
	    case 3:
		RETVAL = g_param_spec_long (name, nick, blurb,
		                            minimum, maximum, default_value,
		                            flags);
		break;
	}
    OUTPUT:
	RETVAL

##  GParamSpec* g_param_spec_int64 (const gchar *name, const gchar *nick, const gchar *blurb, gint64 minimum, gint64 maximum, gint64 default_value, GParamFlags flags) 
GParamSpec*
g_param_spec_int64 (class, name, nick, blurb, minimum, maximum, default_value, flags)
	const gchar *name
	const gchar *nick
	const gchar *blurb
	gint64 minimum
	gint64 maximum
	gint64 default_value
	GParamFlags flags
     C_ARGS:
 	name, nick, blurb, minimum, maximum, default_value, flags

##  GParamSpec* g_param_spec_uchar (const gchar *name, const gchar *nick, const gchar *blurb, guint8 minimum, guint8 maximum, guint8 default_value, GParamFlags flags) 
##  GParamSpec* g_param_spec_uint (const gchar *name, const gchar *nick, const gchar *blurb, guint minimum, guint maximum, guint default_value, GParamFlags flags) 
##  GParamSpec* g_param_spec_ulong (const gchar *name, const gchar *nick, const gchar *blurb, gulong minimum, gulong maximum, gulong default_value, GParamFlags flags) 
GParamSpec*
UV (class, name, nick, blurb, minimum, maximum, default_value, flags)
	const gchar *name
	const gchar *nick
	const gchar *blurb
	UV minimum
	UV maximum
	UV default_value
	GParamFlags flags
    ALIAS:
	UV     = 0
	uchar  = 1
	uint   = 2
	ulong  = 3
    CODE:
	RETVAL = NULL;
    	switch (ix) {
	    case 1:
		RETVAL = g_param_spec_uchar (name, nick, blurb,
		                             (guchar)minimum, (guchar)maximum,
		                             (guchar)default_value, flags);
		break;
	    case 2:
		RETVAL = g_param_spec_uint (name, nick, blurb,
		                            minimum, maximum, default_value,
		                            flags);
		break;
	    case 0:
	    case 3:
		RETVAL = g_param_spec_ulong (name, nick, blurb,
		                             minimum, maximum, default_value,
		                             flags);
		break;
	}
    OUTPUT:
	RETVAL

##  GParamSpec* g_param_spec_uint64 (const gchar *name, const gchar *nick, const gchar *blurb, guint64 minimum, guint64 maximum, guint64 default_value, GParamFlags flags) 
GParamSpec*
g_param_spec_uint64 (class, name, nick, blurb, minimum, maximum, default_value, flags)
	const gchar *name
	const gchar *nick
	const gchar *blurb
	guint64 minimum
	guint64 maximum
	guint64 default_value
	GParamFlags flags
    C_ARGS:
	name, nick, blurb, minimum, maximum, default_value, flags

##  GParamSpec* g_param_spec_boolean (const gchar *name, const gchar *nick, const gchar *blurb, gboolean default_value, GParamFlags flags) 
GParamSpec*
g_param_spec_boolean (class, name, nick, blurb, default_value, flags)
	const gchar *name
	const gchar *nick
	const gchar *blurb
	gboolean default_value
	GParamFlags flags
    C_ARGS:
	name, nick, blurb, default_value, flags


###  GParamSpec* g_param_spec_unichar (const gchar *name, const gchar *nick, const gchar *blurb, gunichar default_value, GParamFlags flags) 
GParamSpec*
g_param_spec_unichar (class, const gchar *name, const gchar *nick, const gchar *blurb, gunichar default_value, GParamFlags flags) 
    C_ARGS:
	name, nick, blurb, default_value, flags

###  GParamSpec* g_param_spec_enum (const gchar *name, const gchar *nick, const gchar *blurb, GType enum_type, gint default_value, GParamFlags flags) 
GParamSpec*
g_param_spec_enum (class, const gchar *name, const gchar *nick, const gchar *blurb, const char * enum_type, SV * default_value, GParamFlags flags)
    PREINIT:
	GType gtype;
    CODE:
	gtype = gperl_fundamental_type_from_package (enum_type);
	if (!gtype)
		croak ("package %s is not registered as an enum type",
		       enum_type);
	RETVAL = g_param_spec_enum (name, nick, blurb, gtype,
	                            gperl_convert_enum (gtype, default_value),
	                            flags);
    OUTPUT:
	RETVAL 

###  GParamSpec* g_param_spec_flags (const gchar *name, const gchar *nick, const gchar *blurb, GType flags_type, guint default_value, GParamFlags flags) 
GParamSpec*
g_param_spec_flags (class, const gchar *name, const gchar *nick, const gchar *blurb, const char * flags_type, SV * default_value, GParamFlags flags)
    PREINIT:
	GType gtype;
    CODE:
	gtype = gperl_fundamental_type_from_package (flags_type);
	if (!gtype)
		croak ("package %s is not registered as an flags type",
		       flags_type);
	RETVAL = g_param_spec_flags (name, nick, blurb, gtype,
	                             gperl_convert_flags (gtype, default_value),
	                             flags);
    OUTPUT:
	RETVAL 


##  GParamSpec* g_param_spec_float (const gchar *name, const gchar *nick, const gchar *blurb, gfloat minimum, gfloat maximum, gfloat default_value, GParamFlags flags) 
##  GParamSpec* g_param_spec_double (const gchar *name, const gchar *nick, const gchar *blurb, gdouble minimum, gdouble maximum, gdouble default_value, GParamFlags flags) 
GParamSpec*
g_param_spec_double (class, name, nick, blurb, minimum, maximum, default_value, flags)
	const gchar *name
	const gchar *nick
	const gchar *blurb
	double minimum
	double maximum
	double default_value
	GParamFlags flags
    ALIAS:
	float = 1
    CODE:
	if (ix == 1)
		RETVAL = g_param_spec_float (name, nick, blurb,
		                             (float)minimum, (float)maximum,
					     (float)default_value, flags);
	else
		RETVAL = g_param_spec_double (name, nick, blurb,
		                              minimum, maximum, default_value,
					      flags);
    OUTPUT:
	RETVAL

##  GParamSpec* g_param_spec_string (const gchar *name, const gchar *nick, const gchar *blurb, const gchar *default_value, GParamFlags flags) 
##
## "default_value" can be NULL.  Not actually described in the docs as
## of 2.18, but used that way in lots of the builtin classes
##
GParamSpec*
g_param_spec_string (class, name, nick, blurb, default_value, flags)
	const gchar *name
	const gchar *nick
	const gchar *blurb
	const gchar_ornull *default_value
	GParamFlags flags
    C_ARGS:
	name, nick, blurb, default_value, flags

###  GParamSpec* g_param_spec_param (const gchar *name, const gchar *nick, const gchar *blurb, GType param_type, GParamFlags flags) 
##  GParamSpec* g_param_spec_boxed (const gchar *name, const gchar *nick, const gchar *blurb, GType boxed_type, GParamFlags flags) 
##  GParamSpec* g_param_spec_object (const gchar *name, const gchar *nick, const gchar *blurb, GType object_type, GParamFlags flags) 

=for apidoc object
=for arg package name of the class, derived from Glib::Object, of the objects this property will hold.
=cut

=for apidoc boxed
=for arg package name of the class, derived from Glib::Boxed, of the objects this property will hold.
=cut

=for apidoc
=for arg package name of the class, derived from Glib::ParamSpec, of the objects this property will hold.
=cut
GParamSpec*
param_spec (class, name, nick, blurb, package, flags)
	const gchar *name
	const gchar *nick
	const gchar *blurb
	const char * package
	GParamFlags flags
    ALIAS:
	boxed = 1
	object = 2
    PREINIT:
	GType type = 0;
    CODE:
	RETVAL = NULL;
	switch (ix) {
	    case 0: type = gperl_param_spec_type_from_package (package); break;
	    case 1: type = gperl_boxed_type_from_package (package); break;
	    case 2: type = gperl_object_type_from_package (package); break;
	}
	if (!type)
		croak ("type %s is not registered with Glib-Perl", package);
	switch (ix) {
	    case 0:
		RETVAL = g_param_spec_param (name, nick, blurb, type, flags);
		break;
	    case 1:
		RETVAL = g_param_spec_boxed (name, nick, blurb, type, flags);
		break;
	    case 2:
		RETVAL = g_param_spec_object (name, nick, blurb, type, flags);
		break;
	}
    OUTPUT:
	RETVAL

=for apidoc
ParamSpec to be used for any generic perl scalar, including references to
complex objects.

Currently C<Gtk2::Builder> cannot set object properties of this type
(there's no hooks for property value parsing, as of Gtk 2.20), so
prefer the builtin types if buildable support for an object matters.
A C<boxed> of C<Glib::Strv> can give an array of strings.  A signal
handler callback can do most of what a coderef might.
=cut
GParamSpec*
scalar (class, name, nick, blurb, flags)
	const gchar *name
	const gchar *nick
	const gchar *blurb
	GParamFlags flags
    CODE:
	RETVAL = g_param_spec_boxed (name, nick, blurb, GPERL_TYPE_SV, flags);
    OUTPUT:
	RETVAL

### plain pointers are dangerous, and i don't even know how you'd create
### them from perl since there are no pointers in perl (references are SVs)
##  GParamSpec* g_param_spec_pointer (const gchar *name, const gchar *nick, const gchar *blurb, GParamFlags flags) 

#### we don't have full pspec support, and probably don't really need 
#### value arrays.
###  GParamSpec* g_param_spec_value_array (const gchar *name, const gchar *nick, const gchar *blurb, GParamSpec *element_spec, GParamFlags flags) 


#if GLIB_CHECK_VERSION(2, 4, 0)

GParamSpec*
g_param_spec_override (class, name, overridden)
	const gchar *name
	GParamSpec *overridden
    C_ARGS:
	name, overridden

GParamSpec_ornull *
g_param_spec_get_redirect_target (pspec)
	GParamSpec *pspec

#endif

#if GLIB_CHECK_VERSION(2, 10, 0)

=for apidoc
=for arg is_a_type  The name of a class whose subtypes are allowed as values of the property.  Use C<undef> to allow any type.
=cut
GParamSpec*
g_param_spec_gtype (class, name, nick, blurb, is_a_type, flags)
	const gchar *name
	const gchar *nick
	const gchar *blurb
	const gchar_ornull *is_a_type
	GParamFlags flags
    C_ARGS:
	name, nick, blurb, is_a_type ? gperl_type_from_package (is_a_type) : G_TYPE_NONE, flags

#endif


####
#### accessors
####
####  the various paramspec structures have important members in them, but
####  the API does not provide accessors for them.  (i presume to reduce
####  bloat and performance penalties.)  thus, we have to provide our own
####  accessors in order to be able to find important things like default
####  and limit values, etc.
####
####  an important choice is whether to use the simple and popular
####  dual-purpose accessor/mutator combo used widely in the Gtk2 module,
####  or to use get_foo/set_foo pairs.  well, that decision is pretty much
####  made for us, by the fact that the simple form for pspec.flags would
####  conflict directly with the GParamFlags constructor.  so, we use the
####  get_foo form throughout.  set_foo functions are currently not
####  implemented.
####
####  and finally, there's the sticky issue of documentation generation.
####  i've aliased a many of the repetitive accessors together, and this
####  results in some problems with the docgen tools, since the aliases
####  are actually in different packages.  to cut down on confusion and
####  the overall number of manpages generated, i've hidden all but the
####  "master" alias from the docs, e.g., for the integer types, only
####  Int is documented, and a note explains that the others are the same.
####  suggestions for a better scheme are quite welcome.
####

# name -> get_name()

GParamFlags
get_flags (GParamSpec * pspec)
    CODE:
	RETVAL = pspec->flags;
    OUTPUT:
	RETVAL

const char *
get_value_type (GParamSpec * pspec)
    ALIAS:
	get_owner_type = 1
    PREINIT:
	GType type;
    CODE:
	switch (ix) {
	    case 0: type = pspec->value_type; break;
	    case 1: type = pspec->owner_type; break;
	    default: g_assert_not_reached (); type = 0;
	}
	RETVAL = gperl_package_from_type (type);
	if (!RETVAL)
		RETVAL = g_type_name (type);
    OUTPUT:
	RETVAL


MODULE = Glib::ParamSpec	PACKAGE = Glib::ParamSpec	PREFIX = g_param_

=for apidoc
=signature bool = $paramspec->value_validate ($value)
=signature (bool, newval) = $paramspec->value_validate ($value)
In scalar context return true if $value must be modified to be valid
for $paramspec, or false if it's valid already.  In array context
return also a new value which is $value made valid.

$value must be the right type for $paramspec (with usual stringizing,
numizing, etc).  C<value_validate> checks the further restrictions
such as minimum and maximum for a numeric type or allowed characters
in a string.  The "made valid" return is then for instance clamped to
the min/max, or offending chars replaced by a substitutor.
=cut
void
g_param_value_validate (GParamSpec * pspec, SV *value)
    PREINIT:
	GValue v = { 0, };
	GType type;
	int modify, retcount=1;
    CODE:
	type = G_PARAM_SPEC_VALUE_TYPE (pspec);
	g_value_init (&v, type);
	gperl_value_from_sv (&v, value);
	modify = g_param_value_validate (pspec, &v);
	ST(0) = sv_2mortal (boolSV (modify));
	if (GIMME_V == G_ARRAY) {
		ST(1) = sv_2mortal (gperl_sv_from_value (&v));
		retcount = 2;
	}
	g_value_unset (&v);
	XSRETURN(retcount);

=for
Compares I<value1> with I<value2> according to I<pspec>, and returns -1, 0 or
+1, if value1 is found to be less than, equal to or greater than value2,
respectively.
=cut
int
g_param_values_cmp (GParamSpec * pspec, SV *value1, SV *value2)
    PREINIT:
	GValue v1 = { 0, };
	GValue v2 = { 0, };
	GType type;
    CODE:
	type = G_PARAM_SPEC_VALUE_TYPE (pspec);
	g_value_init (&v1, type);
	g_value_init (&v2, type);
	gperl_value_from_sv (&v1, value1);
	gperl_value_from_sv (&v2, value2);
	RETVAL = g_param_values_cmp (pspec, &v1, &v2);
	g_value_unset (&v1);
	g_value_unset (&v2);
    OUTPUT:
	RETVAL


MODULE = Glib::ParamSpec	PACKAGE = Glib::Param::Char

 ## actually for all signed integer types


=for object Glib::Param::Int - Paramspecs for integer types

=head1 DESCRIPTION

This page documents the extra accessors available for all of the integer type
paramspecs: Char, Int, and Long.  Perl really only supports full-size integers,
so all of these methods return IVs; the distinction of integer size is
important to the underlying C library and also determines the data value range.

=head1 HIERARCHY

  Glib::ParamSpec
  +----Glib::Param::Char

  Glib::ParamSpec
  +----Glib::Param::Int

  Glib::ParamSpec
  +----Glib::Param::Long

=cut

=for see_also Glib::ParamSpec
=cut


=for apidoc Glib::Param::Char::get_minimum __hide__
=cut

=for apidoc Glib::Param::Long::get_minimum __hide__
=cut

IV
get_minimum (GParamSpec * pspec)
    ALIAS:
	Glib::Param::Int::get_minimum = 1
	Glib::Param::Long::get_minimum = 2
    CODE:
	switch (ix) {
	    case 0: RETVAL = G_PARAM_SPEC_CHAR (pspec)->minimum; break;
	    case 1: RETVAL = G_PARAM_SPEC_INT (pspec)->minimum; break;
	    case 2: RETVAL = G_PARAM_SPEC_LONG (pspec)->minimum; break;
	    default: g_assert_not_reached (); RETVAL = 0;
	}
    OUTPUT:
	RETVAL


=for apidoc Glib::Param::Char::get_maximum __hide__
=cut

=for apidoc Glib::Param::Long::get_maximum __hide__
=cut

IV
get_maximum (GParamSpec * pspec)
    ALIAS:
	Glib::Param::Int::get_maximum = 1
	Glib::Param::Long::get_maximum = 2
    CODE:
	switch (ix) {
	    case 0: RETVAL = G_PARAM_SPEC_CHAR (pspec)->maximum; break;
	    case 1: RETVAL = G_PARAM_SPEC_INT (pspec)->maximum; break;
	    case 2: RETVAL = G_PARAM_SPEC_LONG (pspec)->maximum; break;
	    default: g_assert_not_reached (); RETVAL = 0;
	}
    OUTPUT:
	RETVAL


=for apidoc Glib::Param::Char::get_default_value __hide__
=cut

=for apidoc Glib::Param::Long::get_default_value __hide__
=cut

IV
get_default_value (GParamSpec * pspec)
    ALIAS:
	Glib::Param::Int::get_default_value = 1
	Glib::Param::Long::get_default_value = 2
    CODE:
	switch (ix) {
	    case 0: RETVAL = G_PARAM_SPEC_CHAR (pspec)->default_value; break;
	    case 1: RETVAL = G_PARAM_SPEC_INT (pspec)->default_value; break;
	    case 2: RETVAL = G_PARAM_SPEC_LONG (pspec)->default_value; break;
	    default: g_assert_not_reached (); RETVAL = 0;
	}
    OUTPUT:
	RETVAL

MODULE = Glib::ParamSpec	PACKAGE = Glib::Param::UChar

 ## similarly, all unsigned integer types


=for object Glib::Param::UInt

=head1 DESCRIPTION

This page documents the extra accessors available for all of the unsigned
integer type paramspecs: UChar, UInt, and ULong.  Perl really only supports
full-size integers, so all of these methods return UVs; the distinction of
integer size is important to the underlying C library and also determines the
data value range.

=head1 HIERARCHY

  Glib::ParamSpec
  +----Glib::Param::UChar

  Glib::ParamSpec
  +----Glib::Param::UInt

  Glib::ParamSpec
  +----Glib::Param::ULong

=cut

=for see_also Glib::ParamSpec
=cut


=for apidoc Glib::Param::UChar::get_minimum __hide__
=cut

=for apidoc Glib::Param::ULong::get_minimum __hide__
=cut

UV
get_minimum (GParamSpec * pspec)
    ALIAS:
	Glib::Param::UInt::get_minimum = 1
	Glib::Param::ULong::get_minimum = 2
    CODE:
	switch (ix) {
	    case 0: RETVAL = G_PARAM_SPEC_UCHAR (pspec)->minimum; break;
	    case 1: RETVAL = G_PARAM_SPEC_UINT (pspec)->minimum; break;
	    case 2: RETVAL = G_PARAM_SPEC_ULONG (pspec)->minimum; break;
	    default: g_assert_not_reached (); RETVAL = 0;
	}
    OUTPUT:
	RETVAL


=for apidoc Glib::Param::UChar::get_maximum __hide__
=cut

=for apidoc Glib::Param::ULong::get_maximum __hide__
=cut

UV
get_maximum (GParamSpec * pspec)
    ALIAS:
	Glib::Param::UInt::get_maximum = 1
	Glib::Param::ULong::get_maximum = 2
    CODE:
	switch (ix) {
	    case 0: RETVAL = G_PARAM_SPEC_UCHAR (pspec)->maximum; break;
	    case 1: RETVAL = G_PARAM_SPEC_UINT (pspec)->maximum; break;
	    case 2: RETVAL = G_PARAM_SPEC_ULONG (pspec)->maximum; break;
	    default: g_assert_not_reached (); RETVAL = 0;
	}
    OUTPUT:
	RETVAL


=for apidoc Glib::Param::UChar::get_default_value __hide__
=cut

=for apidoc Glib::Param::ULong::get_default_value __hide__
=cut

UV
get_default_value (GParamSpec * pspec)
    ALIAS:
	Glib::Param::UInt::get_default_value = 1
	Glib::Param::ULong::get_default_value = 2
    CODE:
	switch (ix) {
	    case 0: RETVAL = G_PARAM_SPEC_UCHAR (pspec)->default_value; break;
	    case 1: RETVAL = G_PARAM_SPEC_UINT (pspec)->default_value; break;
	    case 2: RETVAL = G_PARAM_SPEC_ULONG (pspec)->default_value; break;
	    default: g_assert_not_reached (); RETVAL = 0;
	}
    OUTPUT:
	RETVAL

MODULE = Glib::ParamSpec	PACKAGE = Glib::Param::Int64

=for object Glib::Param::Int64

=head1 DESCRIPTION

This page documents the extra accessors available for the signed 64 bit integer
type paramspecs.  On 32 bit machines and even on some 64 bit machines, perl
really only supports 32 bit integers, so all of these methods convert the
values to and from Perl strings if necessary.

=head1 HIERARCHY

  Glib::ParamSpec
  +----Glib::Param::Int64

=cut

gint64
get_minimum (GParamSpec * pspec)
    CODE:
	RETVAL = G_PARAM_SPEC_INT64 (pspec)->minimum;
    OUTPUT:
	RETVAL

gint64
get_maximum (GParamSpec * pspec)
    CODE:
	RETVAL = G_PARAM_SPEC_INT64 (pspec)->maximum;
    OUTPUT:
	RETVAL

gint64
get_default_value (GParamSpec * pspec)
    CODE:
	RETVAL = G_PARAM_SPEC_INT64 (pspec)->default_value;
    OUTPUT:
	RETVAL

MODULE = Glib::ParamSpec	PACKAGE = Glib::Param::UInt64

=for object Glib::Param::UInt64

=head1 DESCRIPTION

This page documents the extra accessors available for the unsigned 64 bit
integer type paramspecs.  On 32 bit machines and even on some 64 bit machines,
perl really only supports 32 bit integers, so all of these methods convert the
values to and from Perl strings if necessary.

=head1 HIERARCHY

  Glib::ParamSpec
  +----Glib::Param::UInt64

=cut

guint64
get_minimum (GParamSpec * pspec)
    CODE:
	RETVAL = G_PARAM_SPEC_UINT64 (pspec)->minimum;
    OUTPUT:
	RETVAL

guint64
get_maximum (GParamSpec * pspec)
    CODE:
	RETVAL = G_PARAM_SPEC_UINT64 (pspec)->maximum;
    OUTPUT:
	RETVAL

guint64
get_default_value (GParamSpec * pspec)
    CODE:
	RETVAL = G_PARAM_SPEC_UINT64 (pspec)->default_value;
    OUTPUT:
	RETVAL

MODULE = Glib::ParamSpec	PACKAGE = Glib::Param::Float

 ## and again for the floating-point types

=for object Glib::Param::Double

=head1 DESCRIPTION

This page documents the extra accessors available for both of the
floating-point type paramspecs: Float and Double.  Perl really only supports
doubles, so all of these methods return NVs (that is, the C type "double"); the
distinction of size is important to the underlying C library and also
determines the data value range.

=head1 HIERARCHY

  Glib::ParamSpec
  +----Glib::Param::Float

  Glib::ParamSpec
  +----Glib::Param::Double

=cut

=for see_also Glib::ParamSpec
=cut


=for apidoc Glib::Param::Float::get_minimum __hide__
=cut

double
get_minimum (GParamSpec * pspec)
    ALIAS:
	Glib::Param::Double::get_minimum = 1
    CODE:
	switch (ix) {
	    case 0: RETVAL = G_PARAM_SPEC_FLOAT (pspec)->minimum; break;
	    case 1: RETVAL = G_PARAM_SPEC_DOUBLE (pspec)->minimum; break;
	    default: g_assert_not_reached (); RETVAL = 0.0;
	}
    OUTPUT:
	RETVAL


=for apidoc Glib::Param::Float::get_maximum __hide__
=cut

double
get_maximum (GParamSpec * pspec)
    ALIAS:
	Glib::Param::Double::get_maximum = 1
    CODE:
	switch (ix) {
	    case 0: RETVAL = G_PARAM_SPEC_FLOAT (pspec)->maximum; break;
	    case 1: RETVAL = G_PARAM_SPEC_DOUBLE (pspec)->maximum; break;
	    default: g_assert_not_reached (); RETVAL = 0.0;
	}
    OUTPUT:
	RETVAL


=for apidoc Glib::Param::Float::get_default_value __hide__
=cut

double
get_default_value (GParamSpec * pspec)
    ALIAS:
	Glib::Param::Double::get_default_value = 1
    CODE:
	switch (ix) {
	    case 0: RETVAL = G_PARAM_SPEC_FLOAT (pspec)->default_value; break;
	    case 1: RETVAL = G_PARAM_SPEC_DOUBLE (pspec)->default_value; break;
	    default: g_assert_not_reached (); RETVAL = 0.0;
	}
    OUTPUT:
	RETVAL


=for apidoc Glib::Param::Float::get_epsilon __hide__
=cut

double
get_epsilon (GParamSpec * pspec)
    ALIAS:
	Glib::Param::Double::get_epsilon = 1
    CODE:
	switch (ix) {
	    case 0: RETVAL = G_PARAM_SPEC_FLOAT (pspec)->epsilon; break;
	    case 1: RETVAL = G_PARAM_SPEC_DOUBLE (pspec)->epsilon; break;
	    default: g_assert_not_reached (); RETVAL = 0.0;
	}
    OUTPUT:
	RETVAL

MODULE = Glib::ParamSpec	PACKAGE = Glib::Param::Boolean

=for position post_hierarchy

=head1 HIERARCHY

  Glib::ParamSpec
  +----Glib::Param::Boolean

=cut

=for see_also Glib::ParamSpec
=cut

gboolean
get_default_value (GParamSpec * pspec_boolean)
    CODE:
	RETVAL = G_PARAM_SPEC_BOOLEAN (pspec_boolean)->default_value;
    OUTPUT:
	RETVAL

MODULE = Glib::ParamSpec	PACKAGE = Glib::Param::Enum

=for position post_hierarchy

=head1 HIERARCHY

  Glib::ParamSpec
  +----Glib::Param::Enum

=cut

=for see_also Glib::ParamSpec
=cut

const char *
get_enum_class (GParamSpec * pspec_enum)
    CODE:
	RETVAL = gperl_fundamental_package_from_type
			(G_ENUM_CLASS_TYPE
				(G_PARAM_SPEC_ENUM (pspec_enum)->enum_class));
    OUTPUT:
	RETVAL

SV *
get_default_value (GParamSpec * pspec_enum)
    PREINIT:
	GParamSpecEnum * penum;
    CODE:
	penum = G_PARAM_SPEC_ENUM (pspec_enum);
	RETVAL = gperl_convert_back_enum (G_ENUM_CLASS_TYPE (penum->enum_class),
	                                  penum->default_value);
    OUTPUT:
	RETVAL

MODULE = Glib::ParamSpec	PACKAGE = Glib::Param::Flags

=for position post_hierarchy

=head1 HIERARCHY

  Glib::ParamSpec
  +----Glib::Param::Flags

=cut

=for see_also Glib::ParamSpec
=cut

const char *
get_flags_class (GParamSpec * pspec_flags)
    CODE:
	RETVAL = gperl_fundamental_package_from_type
			(G_FLAGS_CLASS_TYPE
				(G_PARAM_SPEC_FLAGS (pspec_flags)->flags_class));
    OUTPUT:
	RETVAL

SV *
get_default_value (GParamSpec * pspec_flags)
    PREINIT:
	GParamSpecFlags * pflags;
    CODE:
	pflags = G_PARAM_SPEC_FLAGS (pspec_flags);
	RETVAL = gperl_convert_back_flags
				(G_FLAGS_CLASS_TYPE (pflags->flags_class),
				 pflags->default_value);
    OUTPUT:
	RETVAL

MODULE = Glib::ParamSpec	PACKAGE = Glib::Param::String

=for position post_hierarchy

=head1 HIERARCHY

  Glib::ParamSpec
  +----Glib::Param::String

=cut

=for see_also Glib::ParamSpec
=cut

gchar *
get_default_value (GParamSpec * pspec_string)
    CODE:
	RETVAL = G_PARAM_SPEC_STRING (pspec_string)->default_value;
    OUTPUT:
	RETVAL

## the others are fairly uninteresting.
##  string cset_first
##  string cset_nth
##  char substitutor
##  bool null_fold_if_empty
##  bool ensure_non_null

MODULE = Glib::ParamSpec	PACKAGE = Glib::Param::Unichar

=for position post_hierarchy

=head1 HIERARCHY

  Glib::ParamSpec
  +----Glib::Param::Unichar

=cut

=for see_also Glib::ParamSpec
=cut

gunichar
get_default_value (GParamSpec * pspec_unichar)
    CODE:
	RETVAL = G_PARAM_SPEC_UNICHAR (pspec_unichar)->default_value;
    OUTPUT:
	RETVAL

##MODULE = Glib::ParamSpec	PACKAGE = Glib::Param::ValueArray

##element_spec
##fixed_n_elements

## G_TYPE_PARAM_PARAM, "Glib::Param::Param" -- no members
## G_TYPE_PARAM_BOXED, "Glib::Param::Boxed" -- no members
## G_TYPE_PARAM_POINTER, "Glib::Param::Pointer" -- no members
## G_TYPE_PARAM_OBJECT, "Glib::Param::Object" -- no members
## G_TYPE_PARAM_OVERRIDE, "Glib::Param::Override" -- no public members


MODULE = Glib::ParamSpec	PACKAGE = Glib::Param::GType

#if GLIB_CHECK_VERSION(2, 10, 0)

=for section DESCRIPTION

=head1 DESCRIPTION

This object describes a parameter which holds the name of a class known to the
GLib type system.  The name of the class is considered to be the common
ancestor for valid values.  To create a param that allows any type name,
specify C<undef> for the package name.  Beware, however, that although
we say "any type name", this actually refers to any type registered
with Glib; normal Perl packages will not work.

=cut

=for apidoc
If C<undef>, then any class is allowed.
=cut
const gchar_ornull *
get_is_a_type (GParamSpec * pspec_gtype)
    CODE:
	GParamSpecGType * p = G_PARAM_SPEC_GTYPE (pspec_gtype);
	RETVAL = p->is_a_type == G_TYPE_NONE
		? NULL
		: gperl_package_from_type (p->is_a_type);
    OUTPUT:
	RETVAL

#endif

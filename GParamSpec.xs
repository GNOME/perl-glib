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

SV *
newSVGParamSpec (GParamSpec * pspec)
{
	g_param_spec_ref (pspec);
	g_param_spec_sink (pspec);
	return sv_setref_pv (newSV (0), "Glib::ParamSpec", pspec);
}

GParamSpec *
SvGParamSpec (SV * sv)
{
	if (!sv || !SvROK (sv) || !sv_derived_from (sv, "Glib::ParamSpec"))
		croak ("variable is not a Glib::ParamSpec");
	return (GParamSpec*) SvIV (SvRV (sv));
}


MODULE = Glib::ParamSpec	PACKAGE = Glib::ParamSpec	PREFIX = g_param_spec_

## stuff from gparam.h

const gchar* g_param_spec_get_name (GParamSpec * pspec)

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
##  GParamSpec* g_param_spec_int64 (const gchar *name, const gchar *nick, const gchar *blurb, gint64 minimum, gint64 maximum, gint64 default_value, GParamFlags flags) 
GParamSpec*
IV (class, name, nick, blurb, minimum, maximum, default_value, flags)
	SV * class
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
	int64 = 4
    CODE:
    	switch (ix) {
	    case 1:
		RETVAL = g_param_spec_char (name, nick, blurb,
		                            minimum, maximum, default_value,
		                            flags);
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
	    case 4:
		RETVAL = g_param_spec_int64 (name, nick, blurb,
		                             minimum, maximum, default_value,
		                             flags);
		break;
	}
    OUTPUT:
	RETVAL

##  GParamSpec* g_param_spec_uchar (const gchar *name, const gchar *nick, const gchar *blurb, guint8 minimum, guint8 maximum, guint8 default_value, GParamFlags flags) 
##  GParamSpec* g_param_spec_uint (const gchar *name, const gchar *nick, const gchar *blurb, guint minimum, guint maximum, guint default_value, GParamFlags flags) 
##  GParamSpec* g_param_spec_ulong (const gchar *name, const gchar *nick, const gchar *blurb, gulong minimum, gulong maximum, gulong default_value, GParamFlags flags) 
##  GParamSpec* g_param_spec_uint64 (const gchar *name, const gchar *nick, const gchar *blurb, guint64 minimum, guint64 maximum, guint64 default_value, GParamFlags flags) 
GParamSpec*
UV (class, name, nick, blurb, minimum, maximum, default_value, flags)
	SV * class
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
	uint64 = 4
    CODE:
    	switch (ix) {
	    case 1:
		RETVAL = g_param_spec_uchar (name, nick, blurb,
		                             minimum, maximum, default_value,
		                             flags);
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
	    case 4:
		RETVAL = g_param_spec_uint64 (name, nick, blurb,
		                              minimum, maximum, default_value,
		                              flags);
		break;
	}
    OUTPUT:
	RETVAL

##  GParamSpec* g_param_spec_boolean (const gchar *name, const gchar *nick, const gchar *blurb, gboolean default_value, GParamFlags flags) 
GParamSpec*
g_param_spec_boolean (class, name, nick, blurb, default_value, flags)
	SV * class
	const gchar *name
	const gchar *nick
	const gchar *blurb
	gboolean default_value
	GParamFlags flags
    C_ARGS:
	name, nick, blurb, default_value, flags


#### gunichar not in typemap
###  GParamSpec* g_param_spec_unichar (const gchar *name, const gchar *nick, const gchar *blurb, gunichar default_value, GParamFlags flags) 
#
#### GType not in typemap.  actually, the GTypes for enums and flags are
#### never exposed to perl at all.  how do we handle these?
###  GParamSpec* g_param_spec_enum (const gchar *name, const gchar *nick, const gchar *blurb, GType enum_type, gint default_value, GParamFlags flags) 
###  GParamSpec* g_param_spec_flags (const gchar *name, const gchar *nick, const gchar *blurb, GType flags_type, guint default_value, GParamFlags flags) 


##  GParamSpec* g_param_spec_float (const gchar *name, const gchar *nick, const gchar *blurb, gfloat minimum, gfloat maximum, gfloat default_value, GParamFlags flags) 
##  GParamSpec* g_param_spec_double (const gchar *name, const gchar *nick, const gchar *blurb, gdouble minimum, gdouble maximum, gdouble default_value, GParamFlags flags) 
GParamSpec*
g_param_spec_double (class, name, nick, blurb, minimum, maximum, default_value, flags)
	SV * class
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
		                             minimum, maximum, default_value,
					     flags);
	else
		RETVAL = g_param_spec_double (name, nick, blurb,
		                              minimum, maximum, default_value,
					      flags);
    OUTPUT:
	RETVAL

##  GParamSpec* g_param_spec_string (const gchar *name, const gchar *nick, const gchar *blurb, const gchar *default_value, GParamFlags flags) 
GParamSpec*
g_param_spec_string (class, name, nick, blurb, default_value, flags)
	SV * class
	const gchar *name
	const gchar *nick
	const gchar *blurb
	const gchar *default_value
	GParamFlags flags
    C_ARGS:
	name, nick, blurb, default_value, flags

###  GParamSpec* g_param_spec_param (const gchar *name, const gchar *nick, const gchar *blurb, GType param_type, GParamFlags flags) 
##  GParamSpec* g_param_spec_boxed (const gchar *name, const gchar *nick, const gchar *blurb, GType boxed_type, GParamFlags flags) 
##  GParamSpec* g_param_spec_object (const gchar *name, const gchar *nick, const gchar *blurb, GType object_type, GParamFlags flags) 
GParamSpec*
typed (class, name, nick, blurb, package, flags)
	SV * class
	const gchar *name
	const gchar *nick
	const gchar *blurb
	const char * package
	GParamFlags flags
    ALIAS:
	param_spec = 0
	boxed = 1
	object = 2
    PREINIT:
	GType type;
    CODE:
	switch (ix) {
	    case 0: croak ("param specs not supported as param specs yet");
	    case 1: type = gperl_boxed_type_from_package (package); break;
	    case 2: type = gperl_object_type_from_package (package); break;
	}
	if (!type)
		croak ("type %s is not registered with Glib-Perl", package);
	switch (ix) {
	    case 1:
		RETVAL = g_param_spec_boxed (name, nick, blurb, type, flags);
		break;
	    case 2: type = gperl_object_type_from_package (package); break;
		RETVAL = g_param_spec_object (name, nick, blurb, type, flags);
		break;
	}
    OUTPUT:
	RETVAL

### plain pointers are dangerous, and i don't even know how you'd create
### them from perl since there are no pointers in perl (references are SVs)
##  GParamSpec* g_param_spec_pointer (const gchar *name, const gchar *nick, const gchar *blurb, GParamFlags flags) 

#### we don't have full pspec support, and probably don't really need 
#### value arrays.
###  GParamSpec* g_param_spec_value_array (const gchar *name, const gchar *nick, const gchar *blurb, GParamSpec *element_spec, GParamFlags flags) 


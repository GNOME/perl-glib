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

=head2 GValue

GValue is GLib's generic value container, and it is because of GValue that the
run time type handling of GObject parameters and GClosure marshaling can
function, and most usages of these functions will be from those two points.

Client code will run into uses for gperl_sv_from_value() and
gperl_value_from_sv() when trying to convert lists of parameters into GValue
arrays and the like.

=over

=cut

#include "gperl.h"


/****************************************************************************
 * GValue handling
 * 
 * we have code here to handle the fundamental types listed in the API
 * reference, plus the G_TYPE_ENUM and G_TYPE_FLAGS fundamentals.
 * we won't, however, handle any *other* fundamentals created by
 * g_type_fundamental_next().  if we want to handle that, we probably
 * need to move away from a switch statement to an array of function
 * pointers (at least for the non-standard ones) so that the perl bindings
 * for the library that creates these new fundamentals can register 
 * conversion functions for them.
 */

=item gboolean gperl_value_from_sv (GValue * value, SV * sv)

set a I<value> from a whatever is in I<sv>.  I<value> must be initialized 
so the code knows what kind of value to coerce out of I<sv>.

Returns TRUE if the code knows how to perform the conversion. FIXME this
really ought to always succeed; a failed conversion should be considered a bug
or unimplemented code!

=cut
gboolean
gperl_value_from_sv (GValue * value,
		     SV * sv)
{
	char* tmp;
	int typ = G_TYPE_FUNDAMENTAL(G_VALUE_TYPE(value)); 
	/* printf("TYPE: %d, S: %s\n", typ, g_strdup(SvPV_nolen(sv))); */
	switch (typ) {
    		case G_TYPE_INTERFACE:
			/* pygtk mentions something about only handling 
			   GInterfaces with a GObject prerequisite.  i'm
			   just blindly treating them as objects until
			   this breaks and i understand what they mean. */
    			g_value_set_object(value, gperl_get_object(sv));
			break;
		case G_TYPE_CHAR:
			tmp = SvGChar (sv);
			g_value_set_char (value, (char)(tmp ? tmp[0] : 0));
			break;
		case G_TYPE_UCHAR:
			tmp = SvPV_nolen (sv);
			g_value_set_uchar (value, (guchar)(tmp ? tmp[0] : 0));
			break;
		case G_TYPE_BOOLEAN:
			/* undef is also false. */
			g_value_set_boolean (value, SvTRUE (sv));
			break;
		case G_TYPE_INT:
			g_value_set_int(value, SvIV(sv));
			break;
		case G_TYPE_UINT:
			g_value_set_uint(value, SvIV(sv));
			break;
		case G_TYPE_LONG:
			g_value_set_long(value, SvIV(sv));
			break;
		case G_TYPE_ULONG:
			g_value_set_ulong(value, SvIV(sv));
			break;
		case G_TYPE_INT64:
			g_value_set_int64(value, SvIV(sv));
			break;
		case G_TYPE_UINT64:
			g_value_set_uint64(value, SvIV(sv));
			break;
		case G_TYPE_FLOAT:
			g_value_set_float(value, (gfloat)SvNV(sv));
			break;
		case G_TYPE_DOUBLE:
			g_value_set_double(value, SvNV(sv));
			break;
		case G_TYPE_STRING:
			g_value_set_string(value, SvGChar(sv));
			break;
		case G_TYPE_POINTER:
			g_value_set_pointer(value, (gpointer) SvIV(sv));
			break;
		case G_TYPE_BOXED:
			/* SVs need special treatment! */
			if (G_VALUE_HOLDS (value, GPERL_TYPE_SV))
				g_value_set_boxed (value, 
				                   sv == &PL_sv_undef 
				                    ? NULL
				                    : sv);
			else
				g_value_set_boxed (value, gperl_get_boxed_check (sv, G_VALUE_TYPE(value)));
			break;
		case G_TYPE_PARAM:
			g_value_set_param(value, (gpointer) SvIV(sv));
			break;
		case G_TYPE_OBJECT:
			g_value_set_object(value, gperl_get_object_check (sv, G_VALUE_TYPE(value)));
			break;

		case G_TYPE_ENUM:
			g_value_set_enum(value, gperl_convert_enum(G_VALUE_TYPE(value), sv));
			break;
		case G_TYPE_FLAGS:
			g_value_set_flags(value, gperl_convert_flags(G_VALUE_TYPE(value), sv));
			break;
			
		default:
			/* if we get here, there's something seriously wrong. */
			croak ("[gperl_value_from_sv] FIXME: unhandled type - %d (%s fundamental for %s)\n",
			       typ, g_type_name(G_TYPE_FUNDAMENTAL(G_VALUE_TYPE(value))), G_VALUE_TYPE_NAME(value));
			return FALSE;
	}
	return TRUE;
}


=item SV * gperl_sv_from_value (const GValue * value)

coerce whatever is in I<value> into a perl scalar and return it.

Returns NULL if the code doesn't know how to perform the conversion.  FIXME
this really ought to always succeed; a failed conversion should be considered a
bug or unimplemented code!

=cut
SV *
gperl_sv_from_value (const GValue * value)
{
	int typ = G_TYPE_FUNDAMENTAL(G_VALUE_TYPE(value)); 
	switch (typ) {
    		case G_TYPE_INTERFACE:
			/* pygtk mentions something about only handling 
			   GInterfaces with a GObject prerequisite.  i'm
			   just blindly treating them as objects until
			   this breaks and i understand what they mean. */
			return gperl_new_object (g_value_get_object (value), FALSE);
		case G_TYPE_CHAR:
			return newSViv (g_value_get_char (value));

		case G_TYPE_UCHAR:
			return newSVuv (g_value_get_uchar (value));

		case G_TYPE_BOOLEAN:
			return newSViv(g_value_get_boolean(value));

		case G_TYPE_INT:
			return newSViv(g_value_get_int(value));

		case G_TYPE_UINT:
			return newSVuv(g_value_get_uint(value));

		case G_TYPE_LONG:
			return newSViv(g_value_get_long(value));

		case G_TYPE_ULONG:
			return newSVuv(g_value_get_ulong(value));

		case G_TYPE_INT64:
			/* in reality, i think this only makes sense on
			 * a 64-bit machine. */
			return newSViv((IV)g_value_get_int64(value));

		case G_TYPE_UINT64:
			return newSVuv((UV)g_value_get_uint64(value));

		case G_TYPE_FLOAT:
			return newSVnv(g_value_get_float(value));

		case G_TYPE_DOUBLE:
			return newSVnv(g_value_get_double(value));

		case G_TYPE_STRING:
			return newSVGChar (g_value_get_string (value));

		case G_TYPE_POINTER:
			return newSViv((IV) g_value_get_pointer(value));

		case G_TYPE_BOXED:
			/* special case for SVs, which are stored directly
			 * rather than inside blessed wrappers. */
			if (G_VALUE_HOLDS (value, GPERL_TYPE_SV)) {
				SV * sv = g_value_get_boxed (value);
				return sv ? g_value_dup_boxed (value)
				          : &PL_sv_undef;
			}

			/* the wrapper does not own the boxed object */
			return gperl_new_boxed (g_value_get_boxed (value),
						G_VALUE_TYPE (value),
						FALSE);

		case G_TYPE_PARAM:
			croak ("[gperl_sv_from_value] G_TYPE_PARAM not implemented");

		case G_TYPE_OBJECT:
			return gperl_new_object (g_value_get_object (value), FALSE);

		case G_TYPE_ENUM:
			return gperl_convert_back_enum (G_VALUE_TYPE (value),
							g_value_get_enum (value));

		case G_TYPE_FLAGS:
			return gperl_convert_back_flags (G_VALUE_TYPE (value),
							 g_value_get_flags (value));

		default:
			croak ("[gperl_sv_from_value] FIXME: unhandled type - %d (%s fundamental for %s)\n",
			       typ, g_type_name (G_TYPE_FUNDAMENTAL (G_VALUE_TYPE (value))),
			       G_VALUE_TYPE_NAME (value));
	}
	
	return NULL;
}

=back

=cut

/* apparently this line is required by ExtUtils::ParseXS, but not by xsubpp. */
MODULE = Glib::Value	PACKAGE = Glib::Value	PREFIX = g_value_

PROTOTYPES: ENABLE

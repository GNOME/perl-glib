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

/* for fundamental types */
static GHashTable * types_by_package = NULL;
static GHashTable * packages_by_type = NULL;


/*
 * this is just like gtk_type_class --- it keeps a reference on the classes
 * it returns to they stick around.  this is most important for enums and
 * flags, which will be created and destroyed every time you look them up
 * unless you pull this trick.  duplicates a pointer when you are using
 * gtk, but you aren't always using gtk and it's better to be safe than sorry.
 */
gpointer
gperl_type_class (GType type)
{
	static GQuark quark_static_class = 0;
	gpointer class;

	if (!G_TYPE_IS_ENUM (type) && !G_TYPE_IS_FLAGS (type))
		g_return_val_if_fail (G_TYPE_IS_OBJECT (type), NULL);

	class = g_type_get_qdata (type, quark_static_class);
	if (!class) {
		if (!quark_static_class)
			quark_static_class = g_quark_from_static_string 
						("GPerlStaticTypeClass");
		class = g_type_class_ref (type);
		g_assert (class != NULL);
		g_type_set_qdata (type, quark_static_class, class);
	}

	return class;
}

/****************************************************************************
 * enum and flags handling (mostly from the original gtk2_perl code)
 */

static gboolean
streq_enum (register const char * a, 
	    register const char * b)
{
	while (*a && *b) {
		if (*a == *b || 
		    ((*a == '-' || *a == '_') && (*b == '-' || *b == '_'))) {
			a++;
			b++;
		} else
			return FALSE;
	}
	return *a == *b;
}

static GEnumValue *
gperl_type_enum_get_values (GType enum_type)
{
	GEnumClass * class;
	g_return_val_if_fail (G_TYPE_IS_ENUM (enum_type), NULL);
	class = gperl_type_class (enum_type);
	return class->values;
}

static GFlagsValue *
gperl_type_flags_get_values (GType flags_type)
{
	GFlagsClass * class;
	g_return_val_if_fail (G_TYPE_IS_FLAGS (flags_type), NULL);
	class = gperl_type_class (flags_type);
	return class->values;
}



gboolean
gperl_try_convert_enum (GType type,
			SV * sv,
			gint * val)
{
	GEnumValue * vals;
	char *val_p = SvPV_nolen(sv);
	if (*val_p == '-') val_p++;
	vals = gperl_type_enum_get_values (type);
	while (vals && vals->value_nick && vals->value_name) {
		if (streq_enum (val_p, vals->value_nick) || 
		    streq_enum (val_p, vals->value_name)) {
			*val = vals->value;
			return TRUE;
		}
		vals++;
	}
	return FALSE;
}

gint
gperl_convert_enum (GType type, SV * val)
{
	SV * r;
	int ret;
	GEnumValue * vals;
	if (gperl_try_convert_enum (type, val, &ret))
		return ret;
	
	/*
	 * This is an error, val should be included in the enum type.
	 * croak with a message.  note that we build the message in an
	 * SV so it will be properly GC'd
	 */
	vals = gperl_type_enum_get_values (type);
	r = newSVpv ("", 0);
	while (vals && vals->value_nick) {
		sv_catpv (r, vals->value_nick);
		if (vals->value_name) {
			sv_catpv (r, " / ");
			sv_catpv (r, vals->value_name);
		}
		if (++vals && vals->value_nick)
			sv_catpv (r, ", ");
	}
	croak ("FATAL: invalid enum %s value %s, expecting: %s",
	       g_type_name (type), SvPV_nolen (val), SvPV_nolen (r));

	/* not reached */
	return 0;
}

SV *
gperl_convert_back_enum_pass_unknown (GType type,
				      gint val)
{
	GEnumValue * vals = gperl_type_enum_get_values (type);
	while (vals && vals->value_nick && vals->value_name) {
		if (vals->value == val)
			return newSVpv (vals->value_nick, 0);
		vals++;
	}
	return newSViv (val);
}

SV *
gperl_convert_back_enum (GType type,
			 gint val)
{
	GEnumValue * vals = gperl_type_enum_get_values (type);
	while (vals && vals->value_nick && vals->value_name) {
		if (vals->value == val)
			return newSVpv (vals->value_nick, 0);
		vals++;
	}
	croak ("FATAL: could not convert value %d to enum type %s",
	       val, g_type_name (type));
}

gboolean
gperl_try_convert_flag (GType type,
                        const char * val_p,
                        gint * val)
{
	GFlagsValue * vals = gperl_type_flags_get_values (type);
	while (vals && vals->value_nick && vals->value_name) {
		if (streq_enum (val_p, vals->value_name) || 
		    streq_enum (val_p, vals->value_nick)) {
                        *val = vals->value;
                        return TRUE;
		}
		vals++;
	}
        
        return FALSE;
}

gint
gperl_convert_flag_one (GType type, 
			const char * val_p)
{
	SV *r;
	GFlagsValue * vals = gperl_type_flags_get_values (type);
	gint ret;
	if (gperl_try_convert_flag (type, val_p, &ret))
		return ret;

	/* This is an error, val should be included in the flags type, die */
	vals = gperl_type_flags_get_values (type);
	r = newSVpv("", 0);
	while (vals && vals->value_nick) {
		sv_catpv (r, vals->value_nick);
		if (vals->value_name) {
			sv_catpv (r, " / ");
			sv_catpv (r, vals->value_name);
		}
		if (++vals && vals->value_nick)
			sv_catpv (r, ", ");
	}
	croak ("FATAL: invalid flags %s value %s, expecting: %s",
	       g_type_name (type), val_p, SvPV_nolen (r));

	/* not reached */
	return 0;
}


gint
gperl_convert_flags (GType type,
		     SV * val)
{
	if (SvTYPE (val) == SVt_PV)
		return gperl_convert_flag_one (type, SvPV_nolen (val));
	if (SvROK (val) && SvTYPE (SvRV(val)) == SVt_PVAV) {
		AV* vals = (AV*) SvRV(val);
		gint value = 0;
		int i;
		for (i=0; i<=av_len(vals); i++)
			value |= gperl_convert_flag_one (type,
					 SvPV_nolen (*av_fetch (vals, i, 0)));
		return value;
	}
	croak ("FATAL: invalid flags %s value %s, expecting a string scalar or an arrayref of strings", 
	       g_type_name (type), SvPV_nolen (val));
}

SV *
gperl_convert_back_flags (GType type,
			  gint val)
{
	GFlagsValue * vals = gperl_type_flags_get_values (type);
	AV * flags = newAV ();
	while (vals && vals->value_nick && vals->value_name) {
		if (vals->value & val)
			av_push (flags, newSVpv (vals->value_nick, 0));
		vals++;
	}
	return newRV_noinc ((SV*) flags);
}


/*
 * set the @ISA variable to tell perl a particular package inherits from
 * another.
 */
void
gperl_set_isa (const char * child_package,
               const char * parent_package)
{
	char * child_isa_full;
	AV * isa;

	child_isa_full = g_strconcat (child_package, "::ISA", NULL);
	isa = get_av (child_isa_full, TRUE); /* create on demand */
	//warn ("--> @%s = qw(%s);\n", child_isa_full, parent_package);
	g_free (child_isa_full);

	av_push (isa, newSVpv (parent_package, 0));
}


void
gperl_prepend_isa (const char * child_package,
                   const char * parent_package)
{
	char * child_isa_full;
	AV * isa;

	child_isa_full = g_strconcat (child_package, "::ISA", NULL);
	isa = get_av (child_isa_full, TRUE); /* create on demand */
	//warn ("--> @%s = qw(%s);\n", child_isa_full, parent_package);
	g_free (child_isa_full);

	av_unshift (isa, 1);
	av_store (isa, 0, newSVpv (parent_package, 0));
}


void
gperl_register_fundamental (GType gtype, const char * package)
{
	char * p;
	if (!types_by_package) {
		types_by_package = 
			g_hash_table_new_full (g_str_hash,
			                       g_str_equal,
			                       NULL, NULL);
		packages_by_type =
			g_hash_table_new_full (g_direct_hash,
			                       g_direct_equal,
			                       NULL, 
			                       (GDestroyNotify)g_free);
	}
	p = g_strdup (package);
	g_hash_table_insert (packages_by_type, (gpointer)gtype, p);
	g_hash_table_insert (types_by_package, p, (gpointer)gtype);
}

GType
gperl_fundamental_type_from_package (const char * package)
{
	return (GType) g_hash_table_lookup (types_by_package, package);
}

const char * 
gperl_fundamental_package_from_type (GType gtype)
{
	return (const char *)
		g_hash_table_lookup (packages_by_type, (gpointer)gtype);
}


/*
 * get a type mapping, not matter where it may be.
 */
GType
gperl_type_from_package (const char * package)
{
	GType t;
	t = gperl_object_type_from_package (package);
	if (t)
		return t;

	t = gperl_boxed_type_from_package (package);
	if (t)	
		return t;

	t = gperl_fundamental_type_from_package (package);
	if (t)	
		return t;

	return 0;
}

const char * 
gperl_package_from_type (GType type)
{
	const char * p;
	p = gperl_object_package_from_type (type);
	if (p)
		return p;

	p = gperl_boxed_package_from_type (type);
	if (p)	
		return p;

	p = gperl_fundamental_package_from_type (type);
	if (p)	
		return p;

	return NULL;
}


/*
 * now we need a GBoxed wrapper for a generic SV, so we can store SVs
 * in GObjects reliably.
 */

void
gperl_sv_free (SV * sv)
{
	SvREFCNT_dec (sv);
}

SV *
gperl_sv_copy (SV * sv)
{
	return newSVsv (sv);
}

GType
gperl_sv_get_type (void)
{
	static GType sv_type = 0;
	if (sv_type == 0)
		sv_type = g_boxed_type_register_static ("GPerlSV",
		                                        (GBoxedCopyFunc) gperl_sv_copy,
		                                        (GBoxedFreeFunc) gperl_sv_free);
	return sv_type;
}



/*
 * clean function wrappers for treating gchar* as UTF8 strings, in the
 * same idiom as the rest of the cast macros.  these are wrapped up
 * as functions because comma expressions in macros get kinda tricky.
 */
/*const*/ gchar *
SvGChar (SV * sv)
{
	sv_utf8_upgrade (sv);
	return (/*const*/ gchar*) SvPV_nolen (sv);
}

SV *
newSVGChar (const gchar * str)
{
	SV * sv;
	if (!str) return &PL_sv_undef;
	/* sv_setpv ((SV*)$arg, $var); */
	sv = newSVpv (str, 0);
	SvUTF8_on (sv);
	return sv;
}




/*
 * support for pure-perl GObject subclasses.
 *
 * we don't need to worry about overriding virtual functions; the perl
 * type system helps us out there --- a method defined in the subclass'
 * package will be chosen first as it will be found first in the @ISA,
 * and the perl code can use SUPER to get to the parent class' methods.
 *
 * we can use hard-coded object method names to avoid the need to pass
 * function pointers around.  similarly, we don't need to worry about a
 * finalize method --- perl's DESTROY will suffice.
 *                            ^^^^^^^ NO, it won't!
 *     DESTROY will be called on each wrapper, not on the actual C
 *     object which will be created by Glib::Object->new.
 * 
 * the object will be a C object, so the perl code will have to use
 * user data keys to store data.  that's also easy, and a perl-level
 * AUTOLOAD can be used to write cleaner accessors.
 *
 * then there's the hard part -- overriding virtual functions.
 * when called from perl, this is not a problem, as the standard perl 
 * method lookup works great, but when called from C, as with something
 * like widget's size request method and such, the actual C function 
 * pointer in the class structure must be changed.  this doesn't do that.
 * it would be possible to supply a new vtable for each class, but that
 * could get really messy really quickly.  haven't figured that one out
 * yet.
 *
 * most of the rest of this implementation is directly inspired by or
 * in some cases copied from pygtk.
 */

/* a closure used for the `class closure' of a signal.  As this gets
 * all the info from the first argument to the closure and the
 * invocation hint, we can have a single closure that handles all
 * class closure cases.  We call a method by the name of the signal
 * with "do_" prepended.
 */

static void
gperl_signal_class_closure_marshal (GClosure *closure,
				    GValue *return_value,
				    guint n_param_values,
				    const GValue *param_values,
				    gpointer invocation_hint,
				    gpointer marshal_data)
{
	GObject *object;
	GSignalInvocationHint *hint = (GSignalInvocationHint *)invocation_hint;
	gchar * tmp;
	SV * method_name;
	guint i;

	dSP;

warn ("gperl_signal_class_closure_marshal");
	g_return_if_fail(invocation_hint != NULL);

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);

	/* get the object passed as the first argument to the closure */
	object = g_value_get_object (&param_values[0]);
	g_return_if_fail (object != NULL && G_IS_OBJECT (object));
	EXTEND (SP, 1 + n_param_values);
	PUSHs (sv_2mortal (gperl_new_object (object, FALSE)));

	/* push parameter values onto the stack */
	for (i = 1; i < n_param_values; i++)
		PUSHs (sv_2mortal (gperl_sv_from_value ((GValue*)
		                                        &param_values[i])));

	PUTBACK;

	/* construct method name for this class closure */
	method_name = newSVpvf ("do_%s", g_signal_name (hint->signal_id));

	/* convert dashes to underscores.  g_signal_name converts all the
	 * underscores in the signal name to dashes, but dashes are not
	 * valid in subroutine names. */
	for (tmp = SvPV_nolen (method_name); *tmp != '\0'; tmp++)
		if (*tmp == '-') *tmp = '_';

warn ("    calling method %s", SvPV_nolen (method_name));
	/* now call it */
	if (return_value) {
		if (1 != call_sv (method_name, G_SCALAR))
			croak ("somethin' ain't right");
		SPAGAIN;
		gperl_value_from_sv (return_value, POPs);
	} else {
		call_sv (method_name, G_VOID|G_DISCARD);
	}

	FREETMPS;
	LEAVE;
}

/**
 * gperl_signal_class_closure_get:
 *
 * Returns the GClosure used for the class closure of signals.  When
 * called, it will invoke the method do_signalname (for the signal
 * "signalname").
 *
 * Returns: the closure.
 */
GClosure *
gperl_signal_class_closure_get(void)
{
	static GClosure *closure;

	if (closure == NULL) {
		closure = g_closure_new_simple(sizeof(GClosure), NULL);
		g_closure_set_marshal (closure,
		                       gperl_signal_class_closure_marshal);

		g_closure_ref (closure);
		g_closure_sink (closure);
	}
	return closure;
}

static void
create_signal (GType instance_type,
               const gchar * signal_name,
               HV * hv)
{
	GSignalFlags signal_flags = 0;
	GType return_type = G_TYPE_NONE;
	guint n_params = 0, i;
	GType * param_types = NULL;
	guint signal_id = 0;
	SV ** svp;

	svp = hv_fetch (hv, "return_type", 11, FALSE);
	if (svp && (*svp) && SvTRUE (*svp)) {
		return_type = gperl_type_from_package (SvPV_nolen (*svp));
		if (!return_type)
			croak ("unknown or unregistered return type %s",
			       SvPV_nolen (*svp));
	}

	svp = hv_fetch (hv, "param_types", 11, FALSE);
	if (svp && (*svp) && SvTRUE (*svp) && SvROK (*svp)
	    && SvTYPE (SvRV (*svp)) == SVt_PVAV) {
		AV * av = (AV*) SvRV (*svp);
		n_params = av_len (av) + 1;
		param_types = g_new (GType, n_params);
		for (i = 0 ; i < n_params ; i++) {
			svp = av_fetch (av, i, 0);
			if (!svp) croak ("how did this happen?");
			param_types[i] =
				gperl_type_from_package (SvPV_nolen (*svp));
			if (!param_types[i])
				croak ("unknown or unregistered param type %s",
				       SvPV_nolen (*svp));
		}
	}

//	svp = hv_fetch (hv, "flags", 5, FALSE);
//	if (svp && (*svp) && SvTRUE (*svp))
//		signal_flags = SvGSignalFlags (*svp);
signal_flags = G_SIGNAL_RUN_FIRST;

	signal_id = g_signal_newv (signal_name, instance_type, signal_flags,
	                           gperl_signal_class_closure_get (),
				   NULL, NULL, NULL,
				   return_type, n_params, param_types);
warn ("created signal %s with id %d", signal_name, signal_id);
	g_free (param_types);

	if (signal_id == 0)
		croak ("failed to create signal");
}

static void
override_signal (GType instance_type,
                 const gchar *signal_name)
{
	guint signal_id;

	signal_id = g_signal_lookup(signal_name, instance_type);
	if (!signal_id)
		croak ("could not look up %s", signal_name);
	g_signal_override_class_closure (signal_id, instance_type,
	                                 gperl_signal_class_closure_get ());
}

static void
add_signals (GType instance_type, HV * signals)
{
	GObjectClass *oclass;
	HE * he;

	oclass = g_type_class_ref (instance_type);

	hv_iterinit (signals);
	while (NULL != (he = hv_iternext (signals))) {
		I32 keylen;
		char * signal_name = hv_iterkey (he, &keylen);
		SV * value = hv_iterval (signals, he);
		if (SvROK (value) && SvTYPE (SvRV (value)) == SVt_PVHV) {
			HV * hv = (HV*) SvRV (value);
			SV ** override = hv_fetch (hv, "override", 8, 0);
			if (override && SvTRUE (*override))
				override_signal (instance_type, signal_name);
			else
				create_signal (instance_type, signal_name, hv);
		} else {
			croak ("value for key 'signals' must be a hash reference");
		}
	}

	g_type_class_unref (oclass);
}

static void
gperl_type_get_property (GObject * object,
                         guint property_id,
                         GValue * value,
                         GParamSpec * pspec)
{
	warn ("%s:%d: gperl_type_get_property - stub", G_STRLOC);
/*
	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);

	XPUSHs (sv_2mortal (gperl_new_object (instance, FALSE)));

	PUTBACK;

	call_method ("GET_PROPERTY", G_VOID|G_DISCARD);

	SPAGAIN;

	FREETMPS;
	LEAVE;
*/
}

static void
gperl_type_set_property (GObject * object,
                         guint property_id,
                         const GValue * value,
                         GParamSpec * pspec)
{
	warn ("%s:%d: gperl_type_set_property - stub", G_STRLOC);
/*
	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);

	XPUSHs (sv_2mortal (gperl_new_object (instance, FALSE)));

	PUTBACK;

	call_method ("SET_PROPERTY", G_VOID|G_DISCARD);

	SPAGAIN;

	FREETMPS;
	LEAVE;
*/
}

static void
gperl_type_finalize (GObject * instance)
{
	GObjectClass *parent_class;

        if (!PL_in_clean_objs) {
                dSP;

                instance->ref_count += 2; /* HACK: temporarily revive the object. */

                ENTER;
                SAVETMPS;

                PUSHMARK (SP);
                XPUSHs (sv_2mortal (gperl_new_object (instance, FALSE)));
                PUTBACK;

                call_method ("FINALIZE_INSTANCE", G_VOID|G_DISCARD);

                FREETMPS;
                LEAVE;

                instance->ref_count -= 2; /* HACK END */
        }

        parent_class = g_type_class_peek_parent (G_OBJECT_GET_CLASS (instance));
	parent_class->finalize (instance);
}

static void
gperl_type_class_init (GObjectClass * class)
{
	class->finalize     = gperl_type_finalize;
	class->get_property = gperl_type_get_property;
	class->set_property = gperl_type_set_property;
}

static void
gperl_type_instance_init (GObject * instance)
{
        /* be sure to ref the object here --- we're still in creation,
         * we don't want the object to go away with the temporary wrapper! */
        SV *obj = sv_2mortal (gperl_new_object (instance, FALSE));
        SV **init = hv_fetch (SvSTASH (SvRV(obj)), "INIT_INSTANCE", sizeof ("INIT_INSTANCE") - 1, 0);

        /* does the function exist? then call it. */
        if (init && GvCV (*init)) {
                dSP;

                ENTER;
                SAVETMPS;

                PUSHMARK (SP);

                XPUSHs (obj);

                PUTBACK;

                call_sv ((SV *)GvCV (*init), G_VOID|G_DISCARD);

                FREETMPS;
                LEAVE;
        }
}

MODULE = Glib::Type	PACKAGE = Glib::Type	PREFIX = g_type_

BOOT:
	gperl_register_fundamental (G_TYPE_BOOLEAN, "Glib::Boolean");
	gperl_register_fundamental (G_TYPE_INT, "Glib::Int");
	gperl_register_fundamental (G_TYPE_UINT, "Glib::Uint");
	gperl_register_fundamental (G_TYPE_DOUBLE, "Glib::Double");
	gperl_register_boxed (GPERL_TYPE_SV, "Glib::Scalar", NULL);


void
g_type_register (class, parent_package, new_package, ...);
	SV * class
	char * parent_package
	char * new_package
    PREINIT:
	int i;
	GTypeInfo type_info;
	GTypeQuery query;
	GType parent_type, new_type;
	char * new_type_name, * s;
    CODE:
	/* start with a clean slate */
	memset (&type_info, 0, sizeof (GTypeInfo));
	type_info.class_init = (GClassInitFunc) gperl_type_class_init;
	type_info.instance_init = (GInstanceInitFunc) gperl_type_instance_init;

	/* yeah, i could just call gperl_object_type_from_package directly,
	 * but i want the error messages to be more informative. */
	parent_type = gperl_type_from_package (parent_package);
	if (!parent_type)
		croak ("package %s has not been registered with GPerl",
		       parent_package);
	if (!g_type_is_a (parent_type, G_TYPE_OBJECT))
		croak ("%s (%s) is not a descendent of Glib::Object (GObject)",
		       parent_package, g_type_name (parent_type));

	/* ask the type system for the missing values */
	g_type_query (parent_type, &query);
	type_info.class_size = query.class_size;
	type_info.instance_size = query.instance_size;

	/* and now register with the gtype system */
	/* mangle the name to remove illegal characters */
	new_type_name = g_strdup (new_package);
	for (s = new_type_name ; *s != '\0' ; s++)
		if (*s == ':')
			*s = '_';
	new_type = g_type_register_static (parent_type, new_type_name, 
	                                   &type_info, 0);
	//warn ("registered %s, son of %s nee %s(%d), as %s(%d)",
	//      new_package, parent_package,
	//      g_type_name (parent_type), parent_type,
	//      new_type_name, new_type);
	g_free (new_type_name);
	/* and with the bindings */
	gperl_register_object (new_type, new_package);

	for (i = 3 ; i < items ; i += 2) {
		char * key = SvPV_nolen (ST (i));
		if (strEQ (key, "signals"))
			add_signals (new_type, (HV*)SvRV (ST (i+1)));
	}
	//warn ("leaving g_type_register");


/*
 * $Header$
 */

#include "gperl.h"

typedef struct _ClassInfo ClassInfo;

struct _ClassInfo {
	GType gtype;
	const char * class;
	char * package;
};

static GHashTable * types_by_type = NULL;
static GHashTable * types_by_package = NULL;

static GHashTable * nowarn_by_type = NULL;

ClassInfo *
class_info_new (GType gtype,
		const char * package)
{
	ClassInfo * class_info;

	class_info = g_new0 (ClassInfo, 1);
	class_info->gtype = gtype;
	class_info->class = g_type_name (gtype);
	class_info->package = g_strdup (package);

	return class_info;
}

void
class_info_destroy (ClassInfo * class_info)
{
	if (class_info) {
		/* do NOT free the class name */
		if (class_info->package)
			g_free (class_info->package);
		g_free (class_info);
	}
}

/*
 * tell the GPerl type subsystem what perl package corresponds with a 
 * given GType.  creates internal forward and reverse mappings and sets
 * up @ISA magic.
 */
void
gperl_register_object (GType gtype,
                       const char * package)
{
	GType parent_type;
	ClassInfo * class_info;
	if (!types_by_type) {
		/* we put the same data pointer into each hash table, so we
		 * must only associate the destructor with one of them.
		 * also, for the string-keyed hashes, the keys will be 
		 * destroyed by the ClassInfo destructor, so we don't need
		 * a key_destroy_func. */
		types_by_type = g_hash_table_new_full (g_direct_hash,
						       g_direct_equal,
						       NULL,
						       (GDestroyNotify)
						          class_info_destroy);
		types_by_package = g_hash_table_new_full (g_str_hash,
							  g_str_equal,
							  NULL,
							  NULL);
	}
	class_info = class_info_new (gtype, package);
	g_hash_table_insert (types_by_type, (gpointer)class_info->gtype, class_info);
	g_hash_table_insert (types_by_package, class_info->package, class_info);
	//warn ("registered class %s to package %s\n", class_info->class, class_info->package);

	parent_type = g_type_parent (gtype);
	if (parent_type != 0) {
		static GList * pending_isa = NULL;
		GList * i;

		/*
		 * add this class to the list of pending ISA creations.
		 *
		 * "list of pending ISA creations?!?" you ask...
		 * to minimize the possible errors in setting up the class
		 * relationships, we only require the caller to provide 
		 * the GType and name of the corresponding package; we don't
		 * also require the name of the parent class' package, since
		 * getting the parent GType is more likely to be error-free.
		 * (the developer setting up the registrations may have bad
		 * information, for example.)
		 *
		 * the nasty side effect is that the parent GType may not
		 * yet have been registered at the time the child type is
		 * registered.  so, we keep a list of classes for which 
		 * ISA has not yet been set up, and each time we run through
		 * this function, we'll try to eliminate as many as possible.
		 *
		 * since this one is fresh we append it to the list, so that
		 * we have a chance of registering its parent first.
		 */
		pending_isa = g_list_append (pending_isa, class_info);

		/* handle whatever pending requests we can */
		/* not a for loop, because we're modifying the list as we go */
		i = pending_isa;
		while (i != NULL) {
			const char * parent_package;

			/* NOTE: reusing class_info --- it's not the same as
			 * it was at the top of the function */
			class_info = (ClassInfo*)(i->data);
			parent_package = gperl_object_package_from_type 
					(g_type_parent (class_info->gtype));

			if (parent_package) {
				gperl_set_isa (class_info->package,
				               parent_package);
				pending_isa = g_list_remove (pending_isa, 
				                             class_info);
				/* go back to the beginning, in case we
				 * just registered one that is the base
				 * of several items earlier in the list.
				 * besides, it's dangerous to remove items
				 * while iterating... */
				i = pending_isa;
			} else {
				/* go fish */
				i = g_list_next (i);
			}
		}
	}
}

void
gperl_object_set_no_warn_unreg_subclass (GType gtype,
                                         gboolean nowarn)
{
	if (!nowarn_by_type) {
		if (!nowarn)
			return;
		nowarn_by_type = g_hash_table_new (g_direct_hash, g_direct_equal);
	}
	g_hash_table_insert (nowarn_by_type, (gpointer)gtype, (gpointer)nowarn);
}

static gboolean
gperl_object_get_no_warn_unreg_subclass (GType gtype)
{
	if (!nowarn_by_type)
		return FALSE;
	return (gboolean) g_hash_table_lookup (nowarn_by_type,
	                                       (gpointer)gtype);
}

/*
 * get the package corresponding to gtype; 
 * returns NULL if gtype is not registered.
 */
const char *
gperl_object_package_from_type (GType gtype)
{
	if (types_by_type) {
		ClassInfo * class_info;
		class_info = (ClassInfo *) 
			g_hash_table_lookup (types_by_type, (gpointer)gtype);
		if (class_info)
			return class_info->package;
		else
			return NULL;
	} else
		croak ("internal problem: gperl_object_package_from_type called before any classes were registered");
}

/*
 * inverse of gperl_object_package_from_type, 
 * returns 0 if package is not registered.
 */
GType
gperl_object_type_from_package (const char * package)
{
	if (types_by_package) {
		ClassInfo * class_info;
		class_info = (ClassInfo *) 
			g_hash_table_lookup (types_by_package, package);
		if (class_info)
			return class_info->gtype;
		else
			return 0;
	} else
		croak ("internal problem: gperl_object_type_from_package called before any classes were registered");
}

/*
 * extensive commentary in gperl.h
 */
SV *
gperl_new_object (GObject * object,
                  gboolean noinc)
{
	SV * sv;
	GType gtype;
	const char * package;

	/* take the easy way out if we can */
	if (!object) {
		warn ("gperl_new_object (NULL) => undef"); 
		return &PL_sv_undef;
	}

	if (!G_IS_OBJECT (object))
		croak ("object %p is not really a GObject", object);

	/* create a new wrapper */
	gtype = G_OBJECT_TYPE (object);
	package = gperl_object_package_from_type (gtype);
	if (!package) {
		GType parent;
		while (package == NULL) {
			parent = g_type_parent (gtype);
			package = gperl_object_package_from_type (parent);
		}
		if (!gperl_object_get_no_warn_unreg_subclass (parent))
			warn ("GType '%s' is not registered with GPerl; representing this object as first known parent type '%s' instead",
			      g_type_name (gtype),
			      g_type_name (parent));
	}

	sv = newSV (0);		
	sv_setref_pv (sv, package, object);
	if (!noinc)
		g_object_ref (object);
#ifdef NOISY
	warn ("gperl_new_object (%p)[%d] => %s (%p)[%d]", 
	      object, object->ref_count,
	      gperl_object_package_from_type (G_OBJECT_TYPE (object)),
	      sv, SvREFCNT (sv));
#endif
	return sv;
}

GObject *
gperl_get_object (SV * sv)
{
	if (!sv || !SvOK (sv) || sv == &PL_sv_undef || ! SvROK (sv))
		return NULL;
	return (GObject *) SvIV (SvRV (sv));
}

GObject *
gperl_get_object_check (SV * sv,
			GType gtype)
{
	const char * package;
	package = gperl_object_package_from_type (gtype);
	if (!package)
		croak ("INTERNAL: GType %s (%d) is not registered with GPerl!",
		       g_type_name (gtype), gtype);
	if (!SvTRUE(sv) || !SvROK (sv) || !sv_derived_from (sv, package))
		croak ("variable is not of type %s", package);
	return gperl_get_object (sv);
}

SV *
gperl_object_check_type (SV * sv,
                         GType gtype)
{
	gperl_get_object_check (sv, gtype);
	return sv;
}



static void
destroy_data (gpointer data)
{
#ifdef NOISY
	warn ("destroy data\n");
#endif
	SvREFCNT_dec ((SV*)data);
}


/*
 * helper for list_properties
 *
 * this flags type isn't hasn't type information as the others, I
 * suppose this is because it's too low level 
 */
static SV *
newSVGParamFlags (GParamFlags flags)
{
	AV * flags_av = newAV ();
	if ((flags & G_PARAM_READABLE) != 0)
		av_push (flags_av, newSVpv ("readable", 0));
	if ((flags & G_PARAM_WRITABLE) != 0)
		av_push (flags_av, newSVpv ("writable", 0));
	if ((flags & G_PARAM_CONSTRUCT) != 0)
		av_push (flags_av, newSVpv ("construct", 0));
	if ((flags & G_PARAM_CONSTRUCT_ONLY) != 0)
		av_push (flags_av, newSVpv ("construct-only", 0));
	if ((flags & G_PARAM_LAX_VALIDATION) != 0)
		av_push (flags_av, newSVpv ("lax-validation", 0));
	if ((flags & G_PARAM_PRIVATE) != 0)
		av_push (flags_av, newSVpv ("private", 0));
	return newRV_noinc ((SV*) flags_av);
}

/* helper for g_object_[gs]et_parameter */
static void
init_property_value (GObject * object, 
		     const char * name, 
		     GValue * value)
{
	GParamSpec * pspec;
	pspec = g_object_class_find_property (G_OBJECT_GET_CLASS (object), 
	                                      name);
	if (!pspec)
		croak ("property %s not found in object class %s",
		       name, G_OBJECT_TYPE_NAME (object));
	g_value_init (value, G_PARAM_SPEC_VALUE_TYPE (pspec));
}


MODULE = Glib::Object	PACKAGE = Glib::Object	PREFIX = g_object_

BOOT:
	gperl_register_object (G_TYPE_OBJECT, "Glib::Object");

void
DESTROY (object)
	GObject * object
    CODE:
	//warn ("Glib::Object::DESTROY");
	if (object) {
#ifdef NOISY
		warn ("DESTROY on %s(0x%08p) [ref %d]", 
		      G_OBJECT_TYPE_NAME (object),
		      object,
		      object->ref_count);
#endif
		g_object_unref (object);
	} else {
		warn ("Glib::Object::DESTROY called on NULL GObject");
	}

void
g_object_set_data (object, key, data)
	GObject * object
	gchar * key
	SV * data
    CODE:
	/* FIXME this may lead to some strange problems, such as the variable
	 * changing out from under us.  needs testing.  see "Using call_sv"
	 * in perlcall for some explanation of why you use newSVsv to copy
	 * SV for storage in some instances... */
	SvREFCNT_inc (data);
	g_object_set_data_full (object, key, data, destroy_data);


SV *
g_object_get_data (object, key)
	GObject * object
	gchar * key
    CODE:
	RETVAL = (SV*) g_object_get_data (object, key);
	SvREFCNT_inc(RETVAL); /* this is necessary because the output section
	                         will call sv_2mortal on ST(0), which is 
	                         RETVAL! */
    OUTPUT:
	RETVAL


SV *
g_object_get (object, name)
	GObject * object
	char * name
    ALIAS:
	Glib::Object::get = 0
	Glib::Object::get_property = 1
    PREINIT:
	GValue value = {0,};
    CODE:
	init_property_value (object, name, &value);
	g_object_get_property (object, name, &value);
	RETVAL = gperl_sv_from_value (&value);
	g_value_unset (&value);
    OUTPUT:
	RETVAL

void
g_object_set (object, name, newval)
	GObject * object
	char * name
	SV * newval
    ALIAS:
	Glib::Object::set = 0
	Glib::Object::set_property = 1
    PREINIT:
	GValue value = {0,};
    CODE:
	init_property_value (object, name, &value);
	gperl_value_from_sv (&value, newval);
	g_object_set_property (object, name, &value);
	g_value_unset (&value);


void
g_object_list_properties (object)
	GObject * object
    PREINIT:
	GParamSpec ** props;
	guint n_props = 0, i;
    PPCODE:
	props = g_object_class_list_properties (G_OBJECT_GET_CLASS (object),
						&n_props);
#ifdef NOISY
	warn ("list_properties: %d properties\n", n_props);
#endif
	for (i = 0; i < n_props; i++) {
		const gchar * pv;
		HV * property = newHV ();
		hv_store (property, "name",  4, newSVpv (g_param_spec_get_name (props[i]), 0), 0);
		hv_store (property, "type",  4, newSVpv (g_type_name (props[i]->value_type), 0), 0);
		/* this one can be NULL, it seems */
		pv = g_param_spec_get_blurb (props[i]);
		if (pv) hv_store (property, "descr", 5, newSVpv (pv, 0), 0);
		hv_store (property, "flags", 5, newSVGParamFlags (props[i]->flags), 0) ;
		
		XPUSHs (sv_2mortal (newRV_noinc((SV*)property)));
	}
	g_free(props);

gboolean
g_object_eq (object1, object2, swap=FALSE)
	GObject * object1
	GObject * object2
	IV swap
    ###OVERLOAD: g_object_eq ==
    CODE:
	RETVAL = (object1 == object2);
    OUTPUT: 
	RETVAL


###
### rudimentary support for foreign objects.
###

 ## NOTE: note that the cast from arbitrary integer to GObject may result
 ##       in a core dump without warning, because the type-checking macro
 ##       attempts to dereference the pointer to find a GTypeClass 
 ##       structure, and there is no portable way to validate the pointer.
SV *
new_from_pointer (class, pointer, noinc=FALSE)
	SV * class
	guint32 pointer
	gboolean noinc
    CODE:
	RETVAL = gperl_new_object (G_OBJECT (pointer), noinc);
    OUTPUT:
	RETVAL

guint32
get_pointer (object)
	GObject * object
    CODE:
	RETVAL = GPOINTER_TO_UINT (object);
    OUTPUT:
	RETVAL

SV *
g_object__new (class, object_class, ...)
	SV * class
	const char * object_class
    PREINIT:
	int n_params = 0;
	GParameter * params = NULL;
	GType object_type;
	GObject * object;
    CODE:
	object_type = gperl_object_type_from_package (object_class);
	if (!object_type)
		croak ("%s is not registered with gperl as an object type",
		       object_class);
	if (G_TYPE_IS_ABSTRACT (object_type))
		croak ("cannot create instance of abstract (non-instantiatable)"
		       " type `%s'", g_type_name (object_type));
	if (items > 2) {
		int i;
		GObjectClass * class;
		if (NULL == (class = g_type_class_ref (object_type)))
			croak ("could not get a reference to type class");
		n_params = (items - 2) / 2;
		params = g_new0 (GParameter, n_params);
		for (i = 0 ; i < n_params ; i++) {
			const char * key = SvPV_nolen (ST (2+i*2+0));
			GParamSpec * pspec;
			pspec = g_object_class_find_property (class, key);
			if (!pspec) 
				/* FIXME this bails out, but does not clean up 
				 * properly. */
				croak ("type %s does not support property %s, skipping",
				       object_class, key);
			g_value_init (&params[i].value,
			              G_PARAM_SPEC_VALUE_TYPE (pspec));
			if (!gperl_value_from_sv (&params[i].value, 
			                          ST (2+i*2+1)))
				/* FIXME and neither does this */
				croak ("could not convert value for property %s",
				       key);
			params[i].name = key; /* will be valid until this
			                       * xsub is finished */
		}
	}

	object = g_object_newv (object_type, n_params, params);	
	/* WARNING! this is not correct for GtkObjects! */
	RETVAL = gperl_new_object (object, TRUE); /* noinc! */

    //cleanup: /* C label, not the XS keyword */
	if (n_params) {
		int i;
		for (i = 0 ; i < n_params ; i++)
			g_value_unset (&params[i].value);
		g_free (params);
	}
	g_type_class_unref (class);

    OUTPUT:
	RETVAL

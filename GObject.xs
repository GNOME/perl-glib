/*
 * Copyright (C) 2003-2004 by the gtk2-perl team (see the file AUTHORS for
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
 * $Header$
 */

/* 
 * the POD directives in here will be stripped by xsubpp before compilation,
 * and are intended to be extracted by podselect when creating xs api 
 * reference documentation.  pod must NOT appear within C comments, because
 * it gets replaced by a comment that says "embedded pod stripped".
 */

=head2 GObject

To deal with the intricate interaction of the different reference-counting semantics of Perl objects versus GObjects, the bindings create a combined PerlObject+GObject, with the GObject's pointer in magic attached to the Perl object, and the Perl object's pointer in the GObject's user data.  Thus it's not really a "wrapper", but we refer to it as one, because "combined Perl object + GObject" is a cumbersome and confusing mouthful.

GObjects are represented as blessed hash references.  The GObject user data mechanism is not typesafe, and thus is used only for unsigned integer values; the Perl-level hash is available for any type of user data.  The combined nature of the wrapper means that data stored in the hash will stick around as long as the object is alive.

Since the C pointer is stored in attached magic, the C pointer is not available to the Perl developer via the hash object, so there's no need to worry about breaking it from perl.

Propers go to Marc Lehmann for dreaming most of this up.

=over

=cut

#include "gperl.h"

typedef struct _ClassInfo ClassInfo;
typedef struct _SinkFunc  SinkFunc;

struct _ClassInfo {
	GType   gtype;
	char  * package;
        HV *	stash;
};

struct _SinkFunc {
	GType               gtype;
	GPerlObjectSinkFunc func;
};

static GHashTable * types_by_type    = NULL;
static GHashTable * types_by_package = NULL;

/* store outside of the class info maps any options we expect to be sparse;
 * this will save us a fair amount of space. */
static GHashTable * nowarn_by_type = NULL;
static GArray     * sink_funcs     = NULL;

static GQuark wrapper_quark; /* this quark stores the object's wrapper sv */


/* thread safety locks for the modifiables above */
G_LOCK_DEFINE_STATIC (types_by_type);
G_LOCK_DEFINE_STATIC (types_by_package);
G_LOCK_DEFINE_STATIC (nowarn_by_type);
G_LOCK_DEFINE_STATIC (sink_funcs);


ClassInfo *
class_info_new (GType gtype,
		const char * package)
{
	ClassInfo * class_info;

	class_info = g_new0 (ClassInfo, 1);
	class_info->gtype = gtype;
	class_info->package = g_strdup (package);
        /* Taking a reference to the stash is not really correct,
         * as the stash might be replaced, giving us the wrong stash.
         * Fortunately doing this is not documented nor really supported,
         * nor does perl cope with it gracefully. So this just shields us
         * from segfaults. */
        class_info->stash = (HV *)SvREFCNT_inc (gv_stashpv (package, 1));

	return class_info;
}

void
class_info_destroy (ClassInfo * class_info)
{
	if (class_info) {
                SvREFCNT_dec (class_info->stash);
		g_free (class_info->package);
		g_free (class_info);
	}
}


=item void gperl_register_object (GType gtype, const char * package)

tell the GPerl type subsystem what Perl package corresponds with a given
GObject by GType.  automagically sets up @I<package>::ISA for you.

note that @ISA will not be created for gtype until gtype's parent has
been registered.  if you are experiencing strange problems with a class'
@ISA not being set up, change the order in which you register them.

=cut

void
gperl_register_object (GType gtype,
                       const char * package)
{
	GType parent_type;
	ClassInfo * class_info;

	G_LOCK (types_by_type);
	G_LOCK (types_by_package);

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
	g_hash_table_insert (types_by_type,
	                     (gpointer) class_info->gtype, class_info);
	g_hash_table_insert (types_by_package, class_info->package, class_info);
	/* warn ("registered class %s to package %s\n", class_info->class, class_info->package); */

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
			ClassInfo * parent_class_info;

			/* NOTE: reusing class_info --- it's not the same as
			 * it was at the top of the function */
			class_info = (ClassInfo*)(i->data);

			parent_class_info = (ClassInfo *) 
			         g_hash_table_lookup (types_by_type,
			                    (gpointer) g_type_parent
			                               (class_info->gtype));

			if (parent_class_info) {
				gperl_set_isa (class_info->package,
				               parent_class_info->package);
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

	G_UNLOCK (types_by_type);
	G_UNLOCK (types_by_package);
}


=item void gperl_register_sink_func (GType gtype, GPerlObjectSinkFunc func)

Tell gperl_new_object() to use I<func> to claim ownership of objects derived
from I<gtype>.

gperl_new_object() always refs a GObject when wrapping it for the first time.
To have the Perl wrapper claim ownership of a GObject as part of
gperl_new_object(), you unref the object after ref'ing it. however, different
GObject subclasses have different ways to claim ownership; for example,
GtkObject simply requires you to call gtk_object_sink().  To make this concept
generic, this function allows you to register a function to be called when then
wrapper should claim ownership of the object.  The I<func> registered for a
given I<type> will be called on any object for which C<< g_type_isa
(G_TYPE_OBJECT (object), type) >> succeeds.

If no sinkfunc is found for an object, g_object_unref() will be used.

Even though GObjects don't need sink funcs, we need to have them in Glib
as a hook for upstream objects.  If we create a GtkObject (or any
other type of object which uses a different way to claim ownership) via
Glib::Object->new, any upstream wrappers, such as gtk2perl_new_object(), will
B<not> be called.  Having a sink func facility down here enables us always to
do the right thing.

=cut
/* 
 * this stuff is directly inspired by pygtk.  i didn't actually copy
 * and paste the code, but it sure looks like i did, down to the names.
 * hey, they were the obvious names!
 *
 * for the record, i think this is a rather dodgy way to do sink funcs 
 * --- it presumes that you'll find the right one first; i prepend new
 * registrees in the hopes that this will work out, but nothing guarantees
 * that this will work.  to do it right, the wrappers need to have
 * some form of inherited vtable or something...  but i've had enough
 * problems just getting the object caching working, so i can't really
 * mess with that right now.
 */
void
gperl_register_sink_func (GType gtype,
                          GPerlObjectSinkFunc func)
{
	SinkFunc sf;

	G_LOCK (sink_funcs);

	if (!sink_funcs)
		sink_funcs = g_array_new (FALSE, FALSE, sizeof (SinkFunc));
	sf.gtype = gtype;
	sf.func  = func;
	g_array_prepend_val (sink_funcs, sf);

	G_UNLOCK (sink_funcs);
}

/*
 * helper for gperl_new_object; do whatever you have to do to this
 * object to ensure that the calling code now owns the object.  assumes
 * the object has already been ref'd once.  to do this, we look up the 
 * proper sink func; if none has been registered for this type, then
 * just call g_object_unref.
 */
static void
gperl_object_take_ownership (GObject * object)
{
	G_LOCK (sink_funcs);

	if (sink_funcs) {
		guint i;
		for (i = 0 ; i < sink_funcs->len ; i++)
			if (g_type_is_a (G_OBJECT_TYPE (object),
			                 g_array_index (sink_funcs,
			                                SinkFunc, i).gtype)) {
				g_array_index (sink_funcs,
				               SinkFunc, i).func (object);
				G_UNLOCK (sink_funcs);
				return;
			}
	}

	G_UNLOCK (sink_funcs);

	g_object_unref (object);
}


=item void gperl_object_set_no_warn_unreg_subclass (GType gtype, gboolean nowarn)

how's that for a long and supposedly self-documenting function name!
(sorry...).   basically, it does just as it says -- if I<nowarn> is true, 
do not spew a warning if a GType derived from I<gtype> is not registered
with the bindings' type system.  this is important for things like
GtkStyles (unregistered subclasses come from theme engines) and GdkGCs
(unregistered subclasses come from various gdk backends) for which it's not
possible or practical to force the registration of the classes.  in
general, we want to warn about the unregistered types because it may mean
that a developer has forgotten something.

note: this assumes I<gtype> has already been registered with
gperl_register_object().

=cut
void
gperl_object_set_no_warn_unreg_subclass (GType gtype,
                                         gboolean nowarn)
{
	G_LOCK (nowarn_by_type);

	if (!nowarn_by_type) {
		if (!nowarn)
			return;
		nowarn_by_type = g_hash_table_new (g_direct_hash,
		                                   g_direct_equal);
	}
	g_hash_table_insert (nowarn_by_type,
	                     (gpointer) gtype,
	                     GINT_TO_POINTER (nowarn));

	G_UNLOCK (nowarn_by_type);
}

static gboolean
gperl_object_get_no_warn_unreg_subclass (GType gtype)
{
	gboolean result;

	G_LOCK (nowarn_by_type);

	if (!nowarn_by_type)
		result = FALSE;
	else
		result = GPOINTER_TO_INT
		              (g_hash_table_lookup (nowarn_by_type,
		                                    (gpointer) gtype));

	G_UNLOCK (nowarn_by_type);

	return result;
}


=item const char * gperl_object_package_from_type (GType gtype)

get the package corresponding to I<gtype>; returns NULL if I<gtype>
is not registered.

=cut
const char *
gperl_object_package_from_type (GType gtype)
{
	if (types_by_type) {
		ClassInfo * class_info;

		G_LOCK (types_by_type);

		class_info = (ClassInfo *) 
			g_hash_table_lookup (types_by_type, (gpointer) gtype);

		G_UNLOCK (types_by_type);

		if (class_info)
			return class_info->package;
                else
                  	return NULL;
	} else
		croak ("internal problem: gperl_object_package_from_type "
		       "called before any classes were registered");
	return NULL; /* not reached */
}


=item HV * gperl_object_stash_from_type (GType gtype)

Get the stash corresponding to I<gtype>; returns NULL if I<gtype> is
not registered.  The stash is useful for C<bless>ing.

=cut

HV *
gperl_object_stash_from_type (GType gtype)
{
	if (types_by_type) {
		ClassInfo * class_info;

		G_LOCK (types_by_type);

		class_info = (ClassInfo *) 
			g_hash_table_lookup (types_by_type, (gpointer) gtype);

		G_UNLOCK (types_by_type);

		if (class_info)
			return class_info->stash;
                else
                  	return NULL;
	} else
		croak ("internal problem: gperl_object_stash_from_type "
		       "called before any classes were registered");
	return NULL; /* not reached */
}


=item GType gperl_object_type_from_package (const char * package)

Inverse of gperl_object_package_from_type(),  returns 0 if I<package>
is not registered.

=cut

GType
gperl_object_type_from_package (const char * package)
{
	if (types_by_package) {
		ClassInfo * class_info;

		G_LOCK (types_by_package);

		class_info = (ClassInfo *) 
			g_hash_table_lookup (types_by_package, package);

		G_UNLOCK (types_by_package);

		if (class_info)
			return class_info->gtype;
		else
			return 0;
	} else
		croak ("internal problem: gperl_object_type_from_package "
		       "called before any classes were registered");
	return 0; /* not reached */
}

/*
 * this function is called whenever the gobject gets destroyed. this only
 * happens if the perl object is no longer referenced anywhere else, so
 * put it to final rest here.
 */
static void
gobject_destroy_wrapper (SV *obj)
{
	if (PL_in_clean_objs)
        	return;

#ifdef NOISY
        warn ("gobject_destroy_wrapper (%p)[%d]", obj, SvREFCNT (obj));
#endif
        sv_unmagic (obj, PERL_MAGIC_ext);

        /* we might want to optimize away the call to DESTROY here for non-perl classes. */
        SvREFCNT_dec (obj);
}


=item SV * gperl_new_object (GObject * object, gboolean own)

Use this function to get the perl part of a GObject.  If I<object>
has never been seen by perl before, a new, empty perl object will
be created and added to a private key under I<object>'s qdata.  If
I<object> already has a perl part, a new reference to it will be
created. The gobject + perl object together form a combined object that
is properly refcounted, i.e. both parts will stay alive as long as at
least one of them is alive, and only when both perl object and gobject are
no longer referenced will both be freed.

The perl object will be blessed into the package corresponding to the GType
returned by calling G_OBJECT_TYPE() on I<object>; if that class has not
been registered via gperl_register_object(), this function will emit a
warning to that effect (with warn()), and attempt to bless it into the
first known class in the object's ancestry.  Since Glib::Object is
already registered, you'll get a Glib::Object if you are lazy, and thus
this function can fail only if I<object> isn't descended from GObject,
in which case it croaks.  (In reality, if you pass a non-GObject to this
function, you'll be lucky if you don't get a segfault, as there's not
really a way to trap that.)  In practice these warnings can be unavoidable,
so you can use gperl_object_set_no_warn_unreg_subclass() to quell them
on a class-by-class basis.

However, when perl code is calling a GObject constructor (any function
which returns a new GObject), call gperl_new_object() with I<own> set to
%TRUE; this will cause the first matching sink function to be called
on the GObject to claim ownership of that object, so that it will be
destroyed when the perl object goes out of scope. The default sink func
is g_object_unref(); other types should supply the proper function;
e.g., GtkObject should use gtk_object_sink() here.

Returns the blessed perl object, or #&PL_sv_undef if object was #NULL.

=cut

SV *
gperl_new_object (GObject * object,
                  gboolean own)
{
	SV *obj;
	SV *sv;

	/* take the easy way out if we can */
	if (!object) {
#ifdef NOISY
		warn ("gperl_new_object (NULL) => undef"); 
#endif
		return &PL_sv_undef;
	}

	if (!G_IS_OBJECT (object))
		croak ("object %p is not really a GObject", object);

        /* fetch existing wrapper_data */
        obj = (SV *)g_object_get_qdata (object, wrapper_quark);

        if (!obj) {
                /* create the perl object */
                GType gtype = G_OBJECT_TYPE (object);

                HV *stash = gperl_object_stash_from_type (gtype);

		/* there are many possible cases in which we may be asked to
		 * create a wrapper for objects whose GTypes are not
		 * registered with us; we need to find the first known class
		 * and use that.  see the docs for
		 * gperl_object_set_no_warn_unreg_subclass for more info. */
                if (!stash) {
			/* walk the anscestry to the first known GType.
			 * since GObject is registered to Glib::Object,
			 * this will always succeed. */
			GType parent = gtype;
			while (stash == NULL) {
				parent = g_type_parent (parent);
				stash = gperl_object_stash_from_type (parent);
			}
			if (!gperl_object_get_no_warn_unreg_subclass (parent))
				warn ("GType '%s' is not registered with "
				      "GPerl; representing this object as "
				      "first known parent type '%s' instead",
				      g_type_name (gtype),
				      g_type_name (parent));
		}

                /*
                 * Create the "object", a hash.
                 *
                 * This does not need to be a HV, the only problem is finding
                 * out what to use, and HV is certainly the way to go for any
                 * built-in objects.
                 */

                /* this increases the combined object's refcount. */
                obj = (SV *)newHV ();
                /* attach magic */
                sv_magic (obj, 0, PERL_MAGIC_ext, (const char *)object, 0);

		/* this is the one refcount that represents all non-zero perl
		 * refcounts. it is just temporarily given to the gobject,
		 * DESTROY takes it back again. this effectively increases
		 * the combined refcount by one. */
                g_object_ref (object);

                /* create the wrapper to return, the _noinc decreases the
                 * combined refcount by one. */
                sv = newRV_noinc (obj);

                /* bless into the package */
                sv_bless (sv, stash);

                /* attach it to the gobject */
                g_object_set_qdata_full (object,
                                         wrapper_quark,
                                         (gpointer)obj,
                                         (GDestroyNotify)gobject_destroy_wrapper);

                /* the noinc above is actually the trick, as it leaves the
                 * attached object's refcount artificially one too low,
                 * so DESTROY gets called when all handed-out refs are gone
                 * and we still have the object attached. DESTROY will
                 * then borrow the ref added by g_object_ref back, and
                 * thus will eventually trigger gobject destruction, which
                 * in turn will trigger perl wrapper destruction. */

#ifdef NOISY
		warn ("gperl_new_object%d %s(%p)[%d] => %s (%p) (NEW)", own,
		      G_OBJECT_TYPE_NAME (object), object, object->ref_count,
		      gperl_object_package_from_type (G_OBJECT_TYPE (object)),
		      SvRV (sv));
#endif
        } else {
                /* create the wrapper to return, increases the combined
                 * refcount by one. */
                sv = newRV_inc (obj);

                /* Now we need to handle the case of a gobject that has
                 * been DESTROYed but gets "revived" later. This operation
                 * does not alter the refcount of the combined object.
                 * This can only happen if the call with own is not
                 * the first call. Unfortunately, this is the common case
                 * for gobjectclasses implemented in perl.
                 */
                if (object->ref_count == 1 && own) {
                        g_object_ref (object);
                	SvREFCNT_dec (obj);
                }
                  
        }

#ifdef NOISY
	warn ("gperl_new_object%d %s(%p)[%d] => %s (%p)[%d] (PRE-OWN)", own,
	      G_OBJECT_TYPE_NAME (object), object, object->ref_count,
	      gperl_object_package_from_type (G_OBJECT_TYPE (object)),
	      SvRV (sv), SvREFCNT (SvRV (sv)));
#endif
	if (own)
		gperl_object_take_ownership (object);

	return sv;
}


=item GObject * gperl_get_object (SV * sv)

retrieve the GObject pointer from a Perl object.  Returns NULL if I<sv> is not
linked to a GObject.

Note, this one is not safe -- in general you want to use
gperl_get_object_check().

=cut

GObject *
gperl_get_object (SV * sv)
{
	MAGIC *mg;

	if (!sv || !SvOK (sv) || !SvROK (sv) || !(mg = mg_find (SvRV (sv), PERL_MAGIC_ext)))
		return NULL;
	return (GObject *) mg->mg_ptr;
}


=item GObject * gperl_get_object_check (SV * sv, GType gtype);

croaks if I<sv> is undef or is not blessed into the package corresponding 
to I<gtype>.  use this for bringing parameters into xsubs from perl.
Returns the same as gperl_get_object() (provided it doesn't croak first).

=cut

GObject *
gperl_get_object_check (SV * sv,
			GType gtype)
{
	const char * package;
	package = gperl_object_package_from_type (gtype);
	if (!package)
		croak ("INTERNAL: GType %s (%d) is not registered with GPerl!",
		       g_type_name (gtype), gtype);
	if (!sv || !SvROK (sv) || !sv_derived_from (sv, package))
		croak ("variable is not of type %s", package);
	return gperl_get_object (sv);
}


=item SV * gperl_object_check_type (SV * sv, GType gtype)

Essentially the same as gperl_get_object_check().

FIXME this croaks if the types aren't compatible, but it would be useful if it just return FALSE instead.

=cut

SV *
gperl_object_check_type (SV * sv,
                         GType gtype)
{
	gperl_get_object_check (sv, gtype);
	return sv;
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
	if (!pspec) {
		const char * classname =
			gperl_object_package_from_type (G_OBJECT_TYPE (object));
		if (!classname)
			classname = G_OBJECT_TYPE_NAME (object);
		croak ("type %s does not support property '%s'",
		       classname, name);
	}
	g_value_init (value, G_PARAM_SPEC_VALUE_TYPE (pspec));
}


=item typedef GObject GObject_noinc

=item typedef GObject GObject_ornull

=item newSVGObject(obj)

=item newSVGObject_noinc(obj)

=item SvGObject(sv)

=item SvGObject_ornull(sv)


=back

=cut

MODULE = Glib::Object	PACKAGE = Glib::Object	PREFIX = g_object_

=for object Glib::Object Bindings for GObject
=cut

=for position DESCRIPTION

=head1 DESCRIPTION

GObject is the base object class provided by the gobject library.  It provides
object properties with a notification system, and emittable signals.

Glib::Object is the corresponding Perl object class.  Glib::Objects are
represented by blessed hash references, with a magical connection to the
underlying C object.

=cut

BOOT:
	gperl_register_object (G_TYPE_OBJECT, "Glib::Object");
	wrapper_quark = g_quark_from_static_string ("Perl-wrapper-object");


void
DESTROY (SV *sv)
    CODE:
	GObject *object = gperl_get_object (sv);

        if (!object) /* Happens on object destruction. */
                return;
#ifdef NOISY
        warn ("DESTROY< (%p)[%d] => %s (%p)[%d]", 
              object, object->ref_count,
              gperl_object_package_from_type (G_OBJECT_TYPE (object)),
              sv, SvREFCNT (SvRV(sv)));
#endif
        /* gobject object still exists, so take back the refcount we lend it. */
        /* this operation does NOT change the refcount of the combined object. */

	if (PL_in_clean_objs) {
                /* be careful during global destruction. basically,
                 * don't bother, since refcounting is no longer meaningful. */
                sv_unmagic (SvRV (sv), PERL_MAGIC_ext);

                g_object_steal_qdata (object, wrapper_quark);
        } else {
                SvREFCNT_inc (SvRV (sv));
        }
        g_object_unref (object);
#ifdef NOISY
        warn ("DESTROY> (%p)[%d] => %s (%p)[%d]", 
              object, object->ref_count,
              gperl_object_package_from_type (G_OBJECT_TYPE (object)),
              sv, SvREFCNT (SvRV(sv)));
#endif


=for apidoc

=for signature object = $class->new (...)

=for arg ... of key/value pairs, property values to set on creation

Instantiate a Glib::Object of type I<$class>.  Any key/value pairs in
I<...> are used to set properties on the new object; see C<set>.
This is designed to be inherited by Perl-derived subclasses (see
L<Glib::Object::Subclass>), but you can actually use it to create
any GObject-derived type.

=cut
SV *
g_object_new (class, ...)
	const char *class
    PREINIT:
	int n_params = 0;
	GParameter * params = NULL;
	GType object_type;
	GObject * object;
	GObjectClass *oclass = NULL;
    CODE:
#define FIRST_ARG	1
	object_type = gperl_object_type_from_package (class);
	if (!object_type)
		croak ("%s is not registered with gperl as an object type",
		       class);
	if (G_TYPE_IS_ABSTRACT (object_type))
		croak ("cannot create instance of abstract (non-instantiatable)"
		       " type `%s'", g_type_name (object_type));
	if (items > FIRST_ARG) {
		int i;
		if (NULL == (oclass = g_type_class_ref (object_type)))
			croak ("could not get a reference to type class");
		n_params = (items - FIRST_ARG) / 2;
		params = g_new0 (GParameter, n_params);
		for (i = 0 ; i < n_params ; i++) {
			const char * key = SvPV_nolen (ST (FIRST_ARG+i*2+0));
			GParamSpec * pspec;
			pspec = g_object_class_find_property (oclass, key);
			if (!pspec) {
				/* clean up... */
				int j;
				for (j = 0 ; j < i ; j++)
					g_value_unset (&params[j].value);
				g_free (params);
				/* and bail out. */
				croak ("type %s does not support property '%s'",
				       class, key);
			}
			g_value_init (&params[i].value,
			              G_PARAM_SPEC_VALUE_TYPE (pspec));
			/* note: this croaks if there is a problem.  this is
			 * usually the right thing to do, because if it
			 * doesn't know how to convert the value, then there's
			 * something seriously wrong; however, it means that
			 * if there is a problem, all non-trivial values we've
			 * converted will be leaked. */
			gperl_value_from_sv (&params[i].value,
			                     ST (FIRST_ARG+i*2+1));
			params[i].name = key; /* will be valid until this
			                       * xsub is finished */
		}
	}
#undef FIRST_ARG

	object = g_object_newv (object_type, n_params, params);	

	/* this wrapper *must* own this object!
	 * because we've been through initialization, the perl object
	 * will already exist at this point --- but this still causes
	 * gperl_object_take_ownership to be called. */
	RETVAL = gperl_new_object (object, TRUE);

	if (n_params) {
		int i;
		for (i = 0 ; i < n_params ; i++)
			g_value_unset (&params[i].value);
		g_free (params);
	}
	if (oclass)
		g_type_class_unref (oclass);
    OUTPUT:
	RETVAL


=for apidoc Glib::Object::get
=for arg ... (list) list of property names

Fetch and return the values for the object properties named in I<...>.

=cut

=for apidoc Glib::Object::get_property
=for arg ... (__hide__)

Alias for C<get>.

=cut

void
g_object_get (object, ...)
	GObject * object
    ALIAS:
	Glib::Object::get = 0
	Glib::Object::get_property = 1
    PREINIT:
	GValue value = {0,};
	int i;
    PPCODE:
	PERL_UNUSED_VAR (ix);
	EXTEND (SP, items-1);
	for (i = 1; i < items; i++) {
		char *name = SvPV_nolen (ST (i));
		init_property_value (object, name, &value);
		g_object_get_property (object, name, &value);
		PUSHs (sv_2mortal (gperl_sv_from_value (&value)));
		g_value_unset (&value);
	}


=for apidoc Glib::Object::set
=for signature $object->set (key => $value, ...)
=for arg ... (key/value pairs)

Set object properties.

=cut

=for apidoc Glib::Object::set_property
=for signature $object->set_property (key => $value, ...)
=for arg ... (__hide__)

Alias for C<set>.

=cut

void
g_object_set (object, ...)
	GObject * object
    ALIAS:
	Glib::Object::set = 0
	Glib::Object::set_property = 1
    PREINIT:
	GValue value = {0,};
	int i;
    CODE:
	PERL_UNUSED_VAR (ix);
	if (0 != ((items - 1) % 2))
		croak ("set method expects name => value pairs "
		       "(odd number of arguments detected)");

	for (i = 1; i < items; i += 2) {
		char *name = SvPV_nolen (ST (i));
		SV *newval = ST (i + 1);

		init_property_value (object, name, &value);
		gperl_value_from_sv (&value, newval);
		g_object_set_property (object, name, &value);
		g_value_unset (&value);
	}


=for apidoc

Stops emission of "notify" signals on I<$object>. The signals are queued
until C<thaw_notify> is called on I<$object>.

=cut
void g_object_freeze_notify (GObject * object)

=for apidoc

Reverts the effect of a previous call to C<freeze_notify>. This causes all
queued "notify" signals on I<$object> to be emitted.

=cut
void g_object_thaw_notify (GObject * object)

=for apidoc

List all the object properties for I<$object_or_class_name>; returns them as
a list of hashes, containing these keys:

=over

=item name

=item type

=item owner_type

=item descr

=back

=cut
void
g_object_list_properties (object_or_class_name)
	SV * object_or_class_name
    PREINIT:
	GType type;
	GParamSpec ** props;
	guint n_props = 0, i;
    PPCODE:
	if (object_or_class_name &&
	    SvOK (object_or_class_name) &&
	    SvROK (object_or_class_name)) {
		GObject * object = SvGObject (object_or_class_name);
		if (!object)
			croak ("wha?  NULL object in list_properties");
		type = G_OBJECT_TYPE (object);
	} else {
		type = gperl_object_type_from_package
		                          (SvPV_nolen (object_or_class_name));
		if (!type)
			croak ("package %s is not registered with GPerl",
			       SvPV_nolen (object_or_class_name));
	}
	if (G_TYPE_IS_OBJECT (type))
	{
		/* classes registered by perl are kept alive by the bindings.
		 * those coming straight from C are not.  if we had an actual
		 * object, the class will be alive, but if we just had a
		 * package, the class may not exist yet.  thus, we'll have to
		 * do an honest ref here, rather than a peek. 
		 */
		GObjectClass * object_class = g_type_class_ref (type);
		props = g_object_class_list_properties (object_class, &n_props);
		g_type_class_unref (object_class);
	}
#if GLIB_CHECK_VERSION(2,4,0)
	else if (G_TYPE_IS_INTERFACE (type))
	{
		gpointer iface = g_type_default_interface_ref (type);
		props = g_object_interface_list_properties (iface, &n_props);
		g_type_default_interface_unref (iface);
	}
#endif
	else
		XSRETURN_EMPTY;
#ifdef NOISY
	warn ("list_properties: %d properties\n", n_props);
#endif
	for (i = 0; i < n_props; i++) {
		const gchar * pv;
		HV * property = newHV ();

		hv_store (property, "name",  4,
		          newSVpv (g_param_spec_get_name (props[i]), 0), 0);

		/* map type names to package names, if possible */
		pv = gperl_package_from_type (props[i]->value_type);
		if (!pv) pv = g_type_name (props[i]->value_type);
		hv_store (property, "type",  4, newSVpv (pv, 0), 0);

		pv = gperl_package_from_type (props[i]->owner_type);
		if (!pv) pv = g_type_name (props[i]->owner_type);
		hv_store (property, "owner_type", 10, newSVpv (pv, 0), 0);

		/* this one can be NULL, it seems */
		pv = g_param_spec_get_blurb (props[i]);
		if (pv) hv_store (property, "descr", 5, newSVpv (pv, 0), 0);
		hv_store (property, "flags", 5, newSVGParamFlags (props[i]->flags), 0) ;
		
		XPUSHs (sv_2mortal (newRV_noinc((SV*)property)));
	}
	g_free(props);


=for apidoc

GObject provides an arbitrary data mechanism that assigns unsigned integers
to key names.  Functionality overlaps with the hash used as the Perl object
instance, so we strongly recommend you use hash keys for your data storage.
The GObject data values cannot store type information, so they are not safe
to use for anything but integer values, and you really should use this method
only if you know what you are doing.

=cut
void
g_object_set_data (object, key, data)
	GObject * object
	gchar * key
	SV * data
    CODE:
	if (SvROK (data) || !SvIOK (data))
		croak ("set_data only sets unsigned integers, use"
		       " a key in the object hash for anything else");
	g_object_set_data (object, key, INT2PTR (gpointer, SvUV (data)));


=for apidoc

Fetch the integer stored under the object data key I<$key>.  These values do not
have types; type conversions must be done manually.  See C<set_data>.

=cut
UV
g_object_get_data (object, key)
	GObject * object
	gchar * key
    CODE:
        RETVAL = PTR2UV (g_object_get_data (object, key));
    OUTPUT:
        RETVAL


###
### rudimentary support for foreign objects.
###

=for apidoc Glib::Object::new_from_pointer

=for arg pointer (unsigned) a C pointer value as an integer.

=for arg noinc (boolean) if true, do not increase the GObject's reference count when creating the Perl wrapper.  this typically means that when the Perl wrapper will own the object.  in general you don't want to do that, so the default is false. 

Create a Perl Glib::Object reference for the C object pointed to by I<$pointer>.
You should need this I<very> rarely; it's intended to support foreign objects.

NOTE: the cast from arbitrary integer to GObject may result in a core dump without
warning, because the type-checking macro G_OBJECT() attempts to dereference the
pointer to find a GTypeClass structure, and there is no portable way to validate
the pointer.

=cut
SV *
new_from_pointer (class, pointer, noinc=FALSE)
	gpointer pointer
	gboolean noinc
    CODE:
	RETVAL = gperl_new_object (G_OBJECT (pointer), noinc);
    OUTPUT:
	RETVAL


=for apidoc

Complement of C<new_from_pointer>.

=cut
gpointer
get_pointer (object)
	GObject * object
    CODE:
	RETVAL = object;
    OUTPUT:
	RETVAL

#if 0
=for apidoc
=for arg all if FALSE (or omitted) tie only properties for this object's class, if TRUE tie the properties of this and all parent classes.

A special method avaiable to Glib::Object derivatives, it uses perl's tie
facilities to associate hash keys with the properties of the object. For
example:

  $button->tie_properties;
  # equivilent to $button->set (label => 'Hello World');
  $button->{label} = 'Hello World';
  print "the label is: ".$button->{label}."\n";

Attempts to write to read-only properties will croak, reading a write-only
property will return '[write-only]'.

Care must be taken when using tie_properties with objects of types created with
Glib::Object::Subclass as there may be clashes with existing hash keys that
could cause infinite loops. The solution is to use custom property get/set
functions to alter the storage locations of the properties.
=cut
void
tie_properties (GObject * object, gboolean all=FALSE)

#endif


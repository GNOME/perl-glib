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

#ifndef _GPERL_H_
#define _GPERL_H_

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <glib-object.h>

/*
 * miscellaneous
 */

/* 
 * never use this function directly.  see GPERL_CALL_BOOT, below.
 *
 * for the curious, this calls a perl sub by function pointer rather than
 * by name; call_sv requires that the xsub already be registered, but we
 * need this to call a function which will register xsubs.  this is an
 * evil hack and should not be used outside of the GPERL_CALL_BOOT macro.
 * it's implemented as a function to avoid code size bloat, and exported
 * so that extension modules can pull the same trick.
 */
void _gperl_call_XS (pTHX_ void (*subaddr) (pTHX_ CV *), CV * cv, SV ** mark);

/*
 * call the boot code of a module by symbol rather than by name.
 *
 * in a perl extension which uses several xs files but only one pm, you
 * need to bootstrap the other xs files in order to get their functions
 * exported to perl.  if the file has MODULE = Foo::Bar, the boot symbol
 * would be boot_Foo__Bar.
 */
#define GPERL_CALL_BOOT(name)	\
	{						\
		extern XS(name);			\
		_gperl_call_XS (aTHX_ name, cv, mark);	\
	}


/**
 * gperl_croak_gerror:
 * @prefix: some string to be prefixed (with a colon) to the message in @err,
 *    or #NULL.
 * @err: a #GError.  must not be #NULL.
 * 
 * Use this when wrapping a function that uses #GError for reporting runtime
 * errors.  The bindings map the concept of #GError to runtime exceptions;
 * thus, where a C programmer would wrap a function call with code that
 * checks for a #GError and bails out when one is found, the perl developer
 * simply wraps a block of code in an eval(), and the bindings croak() when
 * a #GError is found.
 *
 * Since croak() does not return, this function handles the magic behind 
 * not leaking the memory associated with the #GError.  To use this you'd
 * do something like
 *
 *  PREINIT:
 *    GError * error = NULL;
 *  CODE:
 *    if (!funtion_that_can_fail (something, &error))
 *       gperl_croak_gerror (NULL, error);
 *
 * it's just that simple!
 */
void gperl_croak_gerror (const char * prefix, GError * err);


/**
 * gperl_alloc_temp:
 * @nbytes: number of bytes to allocate
 *
 * Allocate a temporary buffer that will be reaped at the next garbage 
 * collection sweep.  This is handy for allocating things that need to be
 * alloc'ed before a croak (since croak doesn't return and give you the
 * chance to free them).  The trick is that the memory is allocated in a 
 * mortal perl scalar.  See the perl online manual for notes on using this
 * technique.
 *
 * returns: pointer to freshly allocated and zeroed memory.  do NOT call 
 *    g_free or any other deallocator on this pointer!
 */
gpointer gperl_alloc_temp (int nbytes);

/*
 * enums and flags
 */
/* return FALSE if sv can't be mapped to a valid member of the registered
 * enum type, otherwise, return TRUE and val gets the new value. */
gboolean gperl_try_convert_enum (GType type, SV * sv, gint * val);
/* croak if val is not part of type, otherwise return corresponding value */
gint gperl_convert_enum (GType type, SV * val);
/* return a scalar which is the nickname of the enum value val, or the integer
 * of val if val is not a member of the enum. */
SV * gperl_convert_back_enum_pass_unknown (GType type, gint val);
/* return a scalar which is the nickname of the enum value val, or croak if
 * val is not a member of the enum. */
SV * gperl_convert_back_enum (GType type, gint val);

/* like gperl_try_convert_enum, but for GFlags. */
gboolean gperl_try_convert_flag (GType type, const char * val_p, gint * val);
/* croak if val is not part of type, otherwise return corresponding value */
gint gperl_convert_flag_one (GType type, const char * val_p);
/* collapse a list of strings to an integer with all the correct bits set,
 * croak if anything is invalid. */
gint gperl_convert_flags (GType type, SV * val);
/* convert a bitfield to a list of strings. */
SV * gperl_convert_back_flags (GType type, gint val);

/*
 * inheritance management
 */
/* push @{$parent_package}::ISA, $child_package */
void gperl_set_isa (const char * child_package, const char * parent_package);
/* unshift @{$parent_package}::ISA, $child_package */
void gperl_prepend_isa (const char * child_package, const char * parent_package);

/* these work regardless of what the actual type is (GBoxed or GObject) */
GType gperl_type_from_package (const char * package);
const char * gperl_package_from_type (GType type);


/*
 * we need a GBoxed wrapper for a generic SV, so we can store SVs
 * in GObjects reliably.
 */
#define GPERL_TYPE_SV	(gperl_sv_get_type ())
GType gperl_sv_get_type (void); //G_CONST_RETURN;
SV * gperl_sv_copy (SV * sv);
void gperl_sv_free (SV * sv);


/*
 * clean function wrappers for treating gchar* as UTF8 strings, in the
 * same idiom as the rest of the cast macros.  these are wrapped up
 * as functions because comma expressions in macros get kinda tricky.
 */
/*const*/ gchar * SvGChar (SV * sv);
SV * newSVGChar (const gchar * str);



/*
 * GValues
 */
/**
 * gperl_value_from_sv:
 * @value: #GValue to set
 * @sv: #SV to read
 *
 * set a #GValue from a perl scalar.  @value must be initialized so the
 * code knows what kind of value to coerce out of @sv.
 *
 * returns: TRUE if the code knows how to perform the conversion. FIXME
 *    this really ought to always succeed; a failed conversion should be
 *    considered a bug or unimplemented code!
 */
gboolean gperl_value_from_sv (GValue * value, SV * sv);

/**
 * gperl_sv_from_value:
 * @value: a #GValue
 *
 * coerce whatever is in @value into a perl scalar and return it.
 *
 * returns: an #SV.  returns NULL if the code doesn't know how to perform
 *    the conversion.  FIXME this really ought to always succeed; a failed
 *    conversion should be considered a bug or unimplemented code!
 */
SV * gperl_sv_from_value (const GValue * value);

/*
 * GBoxed
 */

typedef struct _GPerlBoxedWrapperClass GPerlBoxedWrapperClass;

/*
 * turn a boxed pointer into an SV.  gtype is the type of the boxed pointer,
 * and package is the package to which that gtype is registered (the lookup
 * has already been done for you at this point).  if own is true, the wrapper
 * is responsible for freeing the object; if it is false, some other code 
 * owns the object and you must NOT free it.
 */ 
typedef SV*      (*GPerlBoxedWrapFunc)    (GType        gtype,
					   const char * package,
					   gpointer     boxed,
					   gboolean     own);
/*
 * turn an SV into a boxed pointer.  like GPerlBoxedWrapFunc, gtype and package
 * are the registered type pair, already looked up for you (in the process of
 * finding the proper wrapper class).  sv is the sv to unwrap.
 */
typedef gpointer (*GPerlBoxedUnwrapFunc)  (GType        gtype,
					   const char * package,
					   SV         * sv);
/* 
 * this will be called by Glib::Boxed::DESTROY, when the wrapper is destroyed.
 * it is a hook that allows you to destroy an object owned by the wrapper;
 * note, however, that you will have had to keep track yourself of whether
 * the object was to be freed.
 */
typedef void     (*GPerlBoxedDestroyFunc) (SV         * sv);

struct _GPerlBoxedWrapperClass {
	GPerlBoxedWrapFunc    wrap;
	GPerlBoxedUnwrapFunc  unwrap;
	GPerlBoxedDestroyFunc destroy;
};

/* get a pointer to the default wrapper class; handy if you want to use
 * the normal wrapper, with minor modifications.  note that you can just
 * pass NULL to gperl_register_boxed(), so you really only need this in
 * fringe cases. */
GPerlBoxedWrapperClass * gperl_default_boxed_wrapper_class (void);

/**
 * gperl_register_boxed:
 * @gtype: #GType to register
 * @package: name of the package corresponding to @gtype.  This may not be
 *    #NULL, as it is needed for reverse lookups even when a @get_package
 *    function is specified.
 * @wrapper_class: pointer to a function table for manipulating the perl
 *    wrappers for this boxed type.  you can pass %NULL to use the default
 *    wrapper (same as returned by gperl_default_boxed_wrapper_class()).
 *
 * In normal usage, the standard opaque wrapper supplied by the library is 
 * sufficient and correct.  In some cases, however, you want a boxed type to
 * map directly to a native perl type; for example, some struct may be more
 * appropriately represented as a hash in perl.  Since the most necessary place
 * for this conversion to happen is in gperl_value_from_sv() and 
 * gperl_sv_from_value(), the only reliable and robust way to implement this is
 * a hook into gperl_get_boxed() and gperl_new_boxed(); that is exactly the 
 * purpose of @wrap_func and @unwrap_func.
 */
void gperl_register_boxed (GType gtype,
			   const char * package,
			   GPerlBoxedWrapperClass * wrapper_class);

/** 
 * gperl_new_boxed:
 * @boxed: pointer to wrap up.  may not be #NULL.
 * @gtype: GType to wrap into
 * @own: if #TRUE, the wrapper will "own" @boxed and will call g_boxed_free()
 *   on @boxed when the wrapper is destroyed.  use #FALSE if the wrapper should
 *   not own the boxed object.
 *
 * returns: a new, blessed wrapper.
 */
SV * gperl_new_boxed (gpointer boxed, GType gtype, gboolean own);
/** 
 * gperl_new_boxed_copy:
 * @boxed: pointer to copy and wrap.  may not be #NULL.
 * @gtype: GType to wrap into
 * 
 * Create a new copy of @boxed and return an owner wrapper for it.
 *
 * returns: a new, blessed wrapper.
 */
SV * gperl_new_boxed_copy (gpointer boxed, GType gtype);
/**
 * gperl_get_boxed_check:
 * @sv: the SV to check
 * @gtype: the type against which to check @sv
 *
 * Extract the boxed pointer from a wrapper; croaks if the wrapper is not
 * blessed into a derivative of the expected type.  Does not allow undef.
 *
 * returns: the pointer to the boxed object.
 */
gpointer gperl_get_boxed_check (SV * sv, GType gtype);


GType gperl_boxed_type_from_package (const char * package);
const char * gperl_boxed_package_from_type (GType type);


/*
 * GObject
 */
/**
 * gperl_register_object:
 * @gtype: GType to register
 * @package: name of the perl package to which @gtype should be mapped.
 * 
 * tell the GPerl type subsystem what perl package corresponds with a given
 * GObject by GType.  automagically sets up @<package>::ISA for you.
 *
 * note that @ISA will not be created for gtype until gtype's parent has
 * been registered.  if you are experiencing strange problems with a class'
 * @ISA not being set up, change the order in which you register them.
 */
void gperl_register_object (GType gtype, const char * package);

/**
 * gperl_register_sink_func:
 * @gtype: #GType of the class for which to register a sink func
 * @func: pointer to a function which knows how to take ownership of any
 *        object derived from @gtype.  This function will be called by
 *        gperl_new_object() when noinc is TRUE.
 *
 * To have the perl wrapper claim ownership of the object, you unref
 * the object after ref'ing it. however, different GObject subclasses
 * have different ways to claim ownership; for example, GtkObject simply
 * requires you to call gtk_object_sink(). to make this concept generic,
 * this function allows you to register a function to be called when then
 * wrapper should claim ownership of the object. the @func registered
 * for a given @type will be called on any object for which g_type_isa
 * (G_TYPE_OBJECT (object), type) succeeds.
 *
 * If no sinkfunc is found for an object, g_object_unref() will be used.
 * 
 * note -- this is rather hokey right now, simply using an array of functions,
 * as inspired by pygtk.  this should be done in a more robust fashion.
 */
typedef void (*GPerlObjectSinkFunc) (GObject *);
void gperl_register_sink_func (GType               gtype,
                               GPerlObjectSinkFunc func);

/**
 * gperl_object_set_no_warn_unreg_subclass:
 * @gtype: #GType of the class whose flag to set
 * @nowarn: #TRUE to disable warnings.
 *
 * how's that for a long and supposedly self-documenting function name!
 * (sorry...).   basically, it does just as it says -- 
 * do not spew a warning if a GType derived from @gtype is not registered
 * with the bindings' type system.  this is important for things like
 * GtkStyles (unregistered subclasses come from theme engines) and GdkGCs
 * (unregistered subclasses come from various gdk backends) for which it's not
 * possible or practical to force the registration of the classes.  in
 * general, we want to warn about the unregistered types because it may mean
 * that a developer has forgotten something.
 *
 * note: this assumes @gtype has already been registered with
 *   gperl_register_object().
 */
void gperl_object_set_no_warn_unreg_subclass (GType gtype, gboolean nowarn);

/**
 * gperl_object_package_from_type:
 * @gtype: type to look up
 *
 * returns: name of the perl package corresponding to @gtype, NULL if @gtype
 *    has not been registered.
 */
const char * gperl_object_package_from_type (GType gtype);
HV * gperl_object_stash_from_type (GType gtype);
/**
 * gperl_object_type_from_package:
 * @package: package name to look up
 *
 * returns: GType number corresponding to the given package, or 0 if
 *    @package cannot be found (that is, no GType has been registered 
 *    for @package)
 */
GType gperl_object_type_from_package (const char * package);

/**
 * gperl_new_object:
 * @object: #GObject to wrap
 * @own: if #TRUE, the first matching sink function will be called on the
 *    object after ref'ing it, so that that perl wrapper owns the GObject.
 *    see discussion for more info.
 *
 * Use this function to get the perl part of a GObject.  If the object
 * has never been seen by perl before, a new, empty perl object will
 * be created and added to a private key under the object's qdata.  If
 * the object already has a perl part, a new reference to it will be
 * created. The gobject + perl object together form a combined objectt hat
 * is properly refcounted, i.e. both parts will stay alive as long as at
 * least one of them is alive, only when both perl object and gobject are
 * no longer referenced will both be freed.
 *
 * The perl object will be blessed into the package corresponding to the GType
 * returned by calling G_OBJECT_TYPE() on the @object; if that class has not
 * been registered via gperl_register_object(), this function will emit a
 * warning to that effect (with warn()), and attempt to bless it into the
 * first known class in the object's ancestry.  Since Glib::Object is
 * already registered, you'll get a Glib::Object if you are lazy, and thus
 * this function can fail only if @object isn't descended from #GObject,
 * in which case it croaks.  (In reality, if you pass a non-GObject to this
 * function, you'll be lucky if you don't get a segfault, as there's not
 * really a way to trap that.)  In practice these warnings can be unavoidable,
 * so you can use gperl_object_set_no_warn_unreg_subclass() to quell them
 * on a class-by-class basis.
 *
 * However, when perl code is calling a GObject constructor (any function
 * which returns a new GObject), call gperl_new_object() with @own set to
 * %TRUE; this will cause the first matching sink function to be called
 * on the GObject to claim ownership of that object, so that it will be
 * destroyed when the perl object goes out of scope. The default sink func
 * is g_object_unref(); other types should supply the proper function;
 * e.g., GtkObject should use gtk_object_sink here.
 * 
 * returns: blessed scalar wrapper, or #&PL_sv_undef if object was #NULL
 */
SV * gperl_new_object (GObject * object, gboolean own);

/**
 * gperl_get_object:
 * @sv: perl scalar to examine
 *
 * retrieve the GObject pointer from a perl wrapper variable.
 *
 * returns: #GObject pointer, or NULL if @sv is not linked to a gobject.
 */
GObject * gperl_get_object (SV * sv);

/**
 * gperl_get_object_check:
 * @sv: #SV to check.  &PL_sv_undef is *not* allowed.
 * @gtype: GType against which to chec @sv
 *
 * croaks if @sv is undef or is not blessed into the package corresponding 
 * to @gtype.  use this for bringing parameters into xsubs from perl.
 * 
 * returns: the same as gperl_get_object() (provided it doesn't croak).
 */
GObject * gperl_get_object_check (SV * sv, GType gtype);

/**
 * gperl_object_check_type:
 * @sv: #SV to check
 * @gtype: #GType against which to check #SV
 *
 * returns: @sv.  calls gperl_get_object_check internally.
 */
SV * gperl_object_check_type (SV * sv, GType gtype);

/* typedefs and macros for use with the typemap */
typedef gchar gchar_length;
typedef gchar gchar_own;
typedef GObject GObject_ornull;
typedef GObject GObject_noinc;

#define newSVGObject(obj)	(gperl_new_object ((obj), FALSE))
#define newSVGObject_noinc(obj)	(gperl_new_object ((obj), TRUE))
#define SvGObject(sv)		(gperl_get_object (sv))
#define SvGObject_ornull(sv)	((sv && SvTRUE (sv)) ? SvGObject (sv) : NULL)


/*
 * GSignal.xs
 */

/**
 * gperl_signal_connect:
 * @instance: SV wrapper for the #GObject to connect; must not be 
 *    #NULL or &PL_sv_undef.
 * @detailed_signal: name of the signal to which to connect.
 * @callback: perl subroutine #SV to connect.  must not be #NULL.
 * @data: #SV to be passed as data to @callback.  reference count will be
 *    incremented by gperl_closure_new() internally.
 * @flags: #GConnectFlags determining how this signal should be connected.
 *
 * The actual workhorse behind Glib::signal_connect, for use from within XS.
 * This creates a #GPerlClosure wrapper for the given @callback and @data,
 * and connects that closure the to the named @detailed_signal.  This is
 * only good for named signals.
 *
 * returns: the id of the installed callback.
 */
gulong gperl_signal_connect (SV            * instance,
                             char          * detailed_signal,
                             SV            * callback,
                             SV            * data,
                             GConnectFlags   flags);


/*
 * GClosure
 *
 * GPerlClosure is a wrapper around the gobject library's GClosure with
 * special handling for marshalling perl subroutines as callbacks.
 * This is specially tuned for use with GSignal and stuff like io watch,
 * timeout, and idle handlers.
 *
 * For generic callback functions, which need parameters but do not get
 * registered with the type system, this is sometimes overkill.  See
 * GPerlCallback, below.
 */
typedef struct _GPerlClosure GPerlClosure;
struct _GPerlClosure {
	GClosure closure;
	SV * target;
	SV * callback;
	SV * data; /* callback data */
	gboolean swap; /* TRUE if target and data are to be swapped */
	gchar * name;
	int id;
};

/* evaluates to true if the instance and data are to be swapped on invocation */
#define GPERL_CLOSURE_SWAP_DATA(gpc)	((gpc)->swap)

/**
 * gperl_closure_new:
 * @name: name for the closure.  FIXME this is unused... should it be used?
 * @target: instance on which the closure is to be invoked.
 * @callback: subroutine to call.  must not be #NULL
 * @data: additional data parameter to pass to @callback.  may be #NULL.
 * @swap: if #TRUE, @data and @target will be swapped on invocation.  (used 
 *    to implement g_signal_connect_swapped())
 *
 * returns: new #GClosure subclass.
 */
GClosure * gperl_closure_new (gchar * name, 
			      SV * target, 
			      SV * callback, 
			      SV * data, 
			      gboolean swap);
//void gperl_closure_destroy (SV * g_perl_closure);

/*
 * GPerlCallback
 *
 * generic callback functions usually get invoked directly, and are not
 * passed parameter lists as GValues.  we could very easily wrap up such
 * generic callbacks with something that converts the parameters to
 * GValues and then channels everything through GClosure, but this has
 * two problems:  1) the above implementation of GClosure is tuned to 
 * marshalling signal handlers, which always have an instance object, and
 * 2) it's more work than is strictly necessary.
 *
 * additionally, generic callbacks aren't always kind to the GClosure
 * paradigm.
 *
 * so, here's GPerlCallback, which is designed specifically to run
 * generic callback functions.  it reads parameters off the C stack and
 * converts them into parameters on the perl stack.  (it uses the GValue
 * to/from SV mechanism to do so, but doesn't allocate any temps on the
 * heap.)  the callback object itself stores the parameter type list.
 *
 * unfortunately, since the data element is always last, but the number
 * of arguments is not known until we have the callback object, we can't
 * pass gperl_callback_invoke directly to functions requiring a callback;
 * you'll have to write a proxy callback which calls gperl_callback_invoke.
 */

typedef struct _GPerlCallback GPerlCallback;
struct _GPerlCallback {
	gint    n_params;
	GType * param_types;
	GType   return_type;
	SV    * func;
	SV    * data;
	void  * priv;
};

/**
 * gperl_callback_new:
 * @func: perl subroutine to call.  this #SV will be copied, so don't worry
 *    about reference counts.  must *not* be #NULL.
 * @data: scalar to pass to @func in addition to all other arguments.
 *    the SV will be copied, so don't worry about reference counts.
 *    may be #NULL.
 * @n_params: the number of elements in @param_types.
 * @param_types: the #GType of each argument that should be passed from
 *    the invocation to @func.  may be #NULL if @n_params is zero, otherwise
 *    it must be @n_params elements long or nasty things will happen.
 *    this array will be copied; see gperl_callback_invoke() for how 
 *    it is used.
 * @return_type: the #GType of the return value, or 0 if there is no return.
 *
 * returns: a new #GPerlCallback.  use gperl_callback_destroy on it when you
 *    are finished with it.
 */
GPerlCallback * gperl_callback_new     (SV            * func,
                                        SV            * data,
                                        gint            n_params,
                                        GType           param_types[],
					GType           return_type);

/**
 * gperl_callback_destroy:
 * @callback: #GPerlCallback to dispose of
 */
void            gperl_callback_destroy (GPerlCallback * callback);

/**
 * gperl_callback_invoke:
 * @callback: a #GPerlCallback
 * @return_value: #GValue to which to write the callback's return value,
 *    or #NULL if you don't want it (or it is a void-return callback).
 * ...: parameters to pass to the callback.  these are typically proxied 
 *    directly.
 *
 * a typical callback handler would look like this:
 *
 * <codelisting>
 *   gint
 *   real_c_callback (Foo * f, Bar * b, int a, gpointer data)
 *   {
 *           GPerlCallback * callback = (GPerlCallback*)data;
 *           GValue return_value = {0,};
 *           gint retval;
 *           g_value_init (&return_value, callback->return_type);
 *           gperl_callback_invoke (callback, &return_value,
 *                                  f, b, a);
 *           retval = g_value_get_int (&return_value);
 *           g_value_unset (&return_value);
 *           return retval;
 *   }
 * </codelisting>
 */
void            gperl_callback_invoke  (GPerlCallback * callback,
                                        GValue        * return_value,
                                        ...);


/*
 * gparamspec.h / GParamSpec.xs
 *
 * functions to get GParamSpecs in and out of perl.
 */
SV * newSVGParamSpec (GParamSpec * pspec);
GParamSpec * SvGParamSpec (SV * sv);
SV * newSVGParamFlags (GParamFlags flags);
GParamFlags SvGParamFlags (SV * sv);

/*
 * helpful debugging stuff
 */
#define GPERL_OBJECT_VITALS(o) \
	((o)							\
	  ? form ("%s(%p)[%d]", G_OBJECT_TYPE_NAME (o), (o),	\
		  G_OBJECT (o)->ref_count)			\
	  : "NULL")
#define GPERL_WRAPPER_VITALS(w)	\
	((SvTRUE (w))					\
	  ? (SvROK (w))					\
	    (? form ("SvRV(%p)->%s(%p)[%d]", (w),	\
		     sv_reftype (SvRV (w), TRUE),	\
		     SvRV (w), SvREFCNT (SvRV (w)))	\
	     : "[not a reference!]")			\
	  : "undef")

#endif /* _GPERL_H_ */

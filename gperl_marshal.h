#ifndef __GPERL_MARSHAL_H__
#define __GPERL_MARSHAL_H__

/*
 * here lie a few macros to reduce the amount of copied code needed when
 * writing custom marshallers for GPerlClosures.  you'll typically need
 * this if you are trying to make a signal's arguments writable, implement
 * custom handling of G_TYPE_POINTER arguments, or other special
 * circumstances.
 */

#if 0 /* comment with embedded C comments... */
=for example
	 
A typical marshaller skeleton will look like this:

 static void
 some_custom_marshaler (GClosure * closure,
                        GValue * return_value,
                        guint n_param_values,
                        const GValue * param_values,
                        gpointer invocation_hint,
                        gpointer marshal_data)
 {
         dGPERL_CLOSURE_MARSHAL_ARGS;

         GPERL_CLOSURE_MARSHAL_INIT (closure, marshal_data);

         PERL_UNUSED_VAR (return_value);
         PERL_UNUSED_VAR (n_param_values);
         PERL_UNUSED_VAR (invocation_hint);

         ENTER;
         SAVETMPS;

         PUSHMARK (SP);

         GPERL_CLOSURE_MARSHAL_PUSH_INSTANCE (param_values);

         /*
	  * push more parameters onto the perl stack... the ones
	  * in which we are interested are param_values[1] through
          * param_values[n_param_values-1], because the 0th one
	  * has been handled for us.
	  */

         GPERL_CLOSURE_MARSHAL_PUSH_DATA;

         PUTBACK;

	 /* this example invokes the callback in array context.
	  * other options are G_DISCARD and G_SCALAR.  see C<call_sv>
	  * in L<perlcall>. */
         GPERL_CLOSURE_MARSHAL_CALL (G_ARRAY);

         /*
	  * get return values, if needed, and clean up.
	  * "count" will contain the number of values returned on the
	  * stack.
	  */

         FREETMPS;
         LEAVE;
 }

=cut
#endif

/*
=item dGPERL_CLOSURE_MARSHAL_ARGS

Declare several stack variables that the various GPERL_CLOSURE_MARSHAL macros
will need.  Does C<dSP> for you.  This must go near the top of your C
function, before any code statements.

=cut
 */
#define dGPERL_CLOSURE_MARSHAL_ARGS	\
	GPerlClosure * pc;	\
	int count;		\
	SV * data;		\
	SV * instance;		\
	dSP;

/*
=item GPERL_CLOSURE_MARSHAL_INIT (closure, marshal_data)

This must be called as the first non-declaration statement in the marshaller
function.  In a threaded/threadable Perl, this ensures that all Perl API
calls within the function happen in the same Perl interpreter that created
the callback; if this is not first, strange things will happen.  This
statement also initalizes C<pc> (the perl closure object) on the stack.

=cut
 */
#ifdef PERL_IMPLICIT_CONTEXT

# define GPERL_CLOSURE_MARSHAL_INIT(closure, marshal_data)	\
	/* make sure we're executed by the same interpreter */	\
	/* that created the closure object. */			\
	PERL_SET_CONTEXT (marshal_data);			\
	SPAGAIN;						\
	pc = (GPerlClosure *) closure;

#else

# define GPERL_CLOSURE_MARSHAL_INIT(marshal_data)	\
	PERL_UNUSED_VAR (marshal_data);				\
	pc = (GPerlClosure *) closure;

#endif

/*
=item GPERL_CLOSURE_MARSHAL_PUSH_INSTANCE(param_values)

This pushes the callback's instance (first parameter) onto the Perl argument
stack, with XPUSHs.  Handles the case of swapped instance and data.  
I<param_values> is the array of GValues passed into your marshaller.
Note that the instance comes from param_values[0], so you needn't worry
about that one when putting the rest of the parameters on the arg stack.

This assumes that n_param_values > 1.

=cut
*/
/* note -- keep an eye on the refcounts of instance and data! */
#define GPERL_CLOSURE_MARSHAL_PUSH_INSTANCE(param_values)	\
	if (GPERL_CLOSURE_SWAP_DATA (pc)) {			\
		/* swap instance and data */			\
		data     = gperl_sv_from_value (param_values);	\
		instance = SvREFCNT_inc (pc->data);		\
	} else {						\
		/* normal */					\
		instance = gperl_sv_from_value (param_values);	\
		data     = SvREFCNT_inc (pc->data);		\
	}							\
	if (!instance)						\
		instance = &PL_sv_undef;			\
	/* the instance is always the first item in @_ */	\
	XPUSHs (sv_2mortal (instance));

/*
=item GPERL_CLOSURE_MARSHAL_PUSH_DATA

Push the callback's user data onto the Perl arg stack, with XPUSHs.  Handles
the case of swapped instance and data.  The user data is not included in
param_values.

=cut
*/
#define GPERL_CLOSURE_MARSHAL_PUSH_DATA	\
	if (data) XPUSHs (sv_2mortal (data));


/*
=item GPERL_CLOSURE_MARSHAL_CALL(flags)

Invoke the callback.  You must ensure that all the arguments are already on
the stack, and that you've called PUTBACK.  This will invoke call_sv(), adding
G_EVAL to the I<flags> you supply, and store the return value in I<count> on
the stack (count is declared by C<dGPERL_CLOSURE_MARSHAL_ARGS>).  It then
refreshes the stack pointer.  If an exception occurred, the function returns
after running exception handlers.

You'll be interested in the following values for I<flags>:

 G_DISCARD
     this is effectively "void return", as it discards whatever the
     callback put on the return stack.
 G_SCALAR
     invoke the callback in scalar context.  you are pretty much
     guaranteed that one item will be on the stack, even if it is
     undef.
 G_ARRAY
     invoke the callback in array context.  C<count> (declared by
     C<dGPERL_CLOSURE_MARSHAL_ARGS>) will contain the number of
     items on the return stack.

See C<call_sv> in L<perlcall> for more information.

=cut
*/
#define GPERL_CLOSURE_MARSHAL_CALL(flags)	\
	count = call_sv (pc->callback, (flags) | G_EVAL);	\
	SPAGAIN;						\
	if (SvTRUE (ERRSV)) {					\
		gperl_run_exception_handlers ();		\
		FREETMPS;					\
		LEAVE;						\
		return;						\
	}




#endif /* __GPERL_MARSHAL_H__ */

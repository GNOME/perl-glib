/*
 * Copyright (c) 2006 by the gtk2-perl team (see the file AUTHORS)
 *
 * Licensed under the LGPL, see LICENSE file for more information.
 *
 * $Id$
 */

/*
 * This is a private header file intended for functions that are used in more
 * than one xs file.  These functions are not part of the public API.
 */

#ifndef _GPERL_PRIVATE_H_
#define _GPERL_PRIVATE_H_

#include "perl.h"

/*
 * Thread-safety macros and helpers
 */
void _gperl_set_master_interp (PerlInterpreter *interp);
PerlInterpreter *_gperl_get_master_interp (void);
#define GPERL_SET_CONTEXT						\
	{								\
		PerlInterpreter *me = _gperl_get_master_interp ();	\
		if (me && !PERL_GET_CONTEXT) {				\
			PERL_SET_CONTEXT (me);				\
		}			 				\
	}

/*
 * Misc. stuff
 */
SV * _gperl_sv_from_value_internal (const GValue * value, gboolean copy_boxed);

SV * _gperl_fetch_wrapper_key (GObject * object, const char * name, gboolean create);

#endif /* _GPERL_PRIVATE_H_ */

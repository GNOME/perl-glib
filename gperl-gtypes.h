#ifndef __GPERL_GTYPES_H__
#define __GPERL_GTYPES_H__ 1

#include <glib-object.h>

G_BEGIN_DECLS

#if GLIB_CHECK_VERSION (2, 12, 0)
#define GPERL_TYPE_BOOKMARK_FILE_ERROR gperl_bookmark_file_error_get_type()
GType gperl_bookmark_file_error_get_type (void);
#endif /* GLIB_CHECK_VERSION (2, 12, 0) */

#define GPERL_TYPE_CONVERT_ERROR gperl_convert_error_get_type()
GType gperl_convert_error_get_type (void);

#define GPERL_TYPE_FILE_ERROR gperl_file_error_get_type()
GType gperl_file_error_get_type (void);

#if GLIB_CHECK_VERSION (2, 6, 0)
#define GPERL_TYPE_KEY_FILE_ERROR gperl_key_file_error_get_type()
GType gperl_key_file_error_get_type (void);
#endif /* GLIB_CHECK_VERSION (2, 6, 0) */

#define GPERL_TYPE_IO_ERROR gperl_io_error_get_type()
GType gperl_io_error_get_type (void);

#define GPERL_TYPE_IO_CHANNEL_ERROR gperl_io_channel_error_get_type()
GType gperl_io_channel_error_get_type (void);

#define GPERL_TYPE_MARKUP_ERROR gperl_markup_error_get_type()
GType gperl_markup_error_get_type (void);

#define GPERL_TYPE_SHELL_ERROR gperl_shell_error_get_type()
GType gperl_shell_error_get_type (void);

#define GPERL_TYPE_SPAWN_ERROR gperl_spawn_error_get_type()
GType gperl_spawn_error_get_type (void);

#define GPERL_TYPE_THREAD_ERROR gperl_thread_error_get_type()
GType gperl_thread_error_get_type (void);

G_END_DECLS

#endif /* __GPERL_GTYPES_H__ */

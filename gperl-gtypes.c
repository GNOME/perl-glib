/*
 * this was initially generated by glib-mkenums, but i stripped out all the
 * non-Error definitions, as we won't use them.
 */
#include "gperl.h"

static const GEnumValue _gperl_g_convert_error_values[] = {
  { G_CONVERT_ERROR_NO_CONVERSION, "G_CONVERT_ERROR_NO_CONVERSION", "no-conversion" },
  { G_CONVERT_ERROR_ILLEGAL_SEQUENCE, "G_CONVERT_ERROR_ILLEGAL_SEQUENCE", "illegal-sequence" },
  { G_CONVERT_ERROR_FAILED, "G_CONVERT_ERROR_FAILED", "failed" },
  { G_CONVERT_ERROR_PARTIAL_INPUT, "G_CONVERT_ERROR_PARTIAL_INPUT", "partial-input" },
  { G_CONVERT_ERROR_BAD_URI, "G_CONVERT_ERROR_BAD_URI", "bad-uri" },
  { G_CONVERT_ERROR_NOT_ABSOLUTE_PATH, "G_CONVERT_ERROR_NOT_ABSOLUTE_PATH", "not-absolute-path" },
  { 0, NULL, NULL }
};

GType
gperl_g_convert_error_get_type (void)
{
  static GType type = 0;

  if (!type)
    type = g_enum_register_static ("GConvertError", _gperl_g_convert_error_values);

  return type;
}

#define GPERL_TYPE_CONVERT_ERROR gperl_g_convert_error_get_type()
GType gperl_g_convert_error_get_type (void);




static const GEnumValue _gperl_g_file_error_values[] = {
  { G_FILE_ERROR_EXIST, "G_FILE_ERROR_EXIST", "exist" },
  { G_FILE_ERROR_ISDIR, "G_FILE_ERROR_ISDIR", "isdir" },
  { G_FILE_ERROR_ACCES, "G_FILE_ERROR_ACCES", "acces" },
  { G_FILE_ERROR_NAMETOOLONG, "G_FILE_ERROR_NAMETOOLONG", "nametoolong" },
  { G_FILE_ERROR_NOENT, "G_FILE_ERROR_NOENT", "noent" },
  { G_FILE_ERROR_NOTDIR, "G_FILE_ERROR_NOTDIR", "notdir" },
  { G_FILE_ERROR_NXIO, "G_FILE_ERROR_NXIO", "nxio" },
  { G_FILE_ERROR_NODEV, "G_FILE_ERROR_NODEV", "nodev" },
  { G_FILE_ERROR_ROFS, "G_FILE_ERROR_ROFS", "rofs" },
  { G_FILE_ERROR_TXTBSY, "G_FILE_ERROR_TXTBSY", "txtbsy" },
  { G_FILE_ERROR_FAULT, "G_FILE_ERROR_FAULT", "fault" },
  { G_FILE_ERROR_LOOP, "G_FILE_ERROR_LOOP", "loop" },
  { G_FILE_ERROR_NOSPC, "G_FILE_ERROR_NOSPC", "nospc" },
  { G_FILE_ERROR_NOMEM, "G_FILE_ERROR_NOMEM", "nomem" },
  { G_FILE_ERROR_MFILE, "G_FILE_ERROR_MFILE", "mfile" },
  { G_FILE_ERROR_NFILE, "G_FILE_ERROR_NFILE", "nfile" },
  { G_FILE_ERROR_BADF, "G_FILE_ERROR_BADF", "badf" },
  { G_FILE_ERROR_INVAL, "G_FILE_ERROR_INVAL", "inval" },
  { G_FILE_ERROR_PIPE, "G_FILE_ERROR_PIPE", "pipe" },
  { G_FILE_ERROR_AGAIN, "G_FILE_ERROR_AGAIN", "again" },
  { G_FILE_ERROR_INTR, "G_FILE_ERROR_INTR", "intr" },
  { G_FILE_ERROR_IO, "G_FILE_ERROR_IO", "io" },
  { G_FILE_ERROR_PERM, "G_FILE_ERROR_PERM", "perm" },
  { G_FILE_ERROR_FAILED, "G_FILE_ERROR_FAILED", "failed" },
  { 0, NULL, NULL }
};

GType
gperl_g_file_error_get_type (void)
{
  static GType type = 0;

  if (!type)
    type = g_enum_register_static ("GFileError", _gperl_g_file_error_values);

  return type;
}

#define GPERL_TYPE_FILE_ERROR gperl_g_file_error_get_type()
GType gperl_g_file_error_get_type (void);




static const GEnumValue _gperl_g_io_error_values[] = {
  { G_IO_ERROR_NONE, "G_IO_ERROR_NONE", "none" },
  { G_IO_ERROR_AGAIN, "G_IO_ERROR_AGAIN", "again" },
  { G_IO_ERROR_INVAL, "G_IO_ERROR_INVAL", "inval" },
  { G_IO_ERROR_UNKNOWN, "G_IO_ERROR_UNKNOWN", "unknown" },
  { 0, NULL, NULL }
};

GType
gperl_g_io_error_get_type (void)
{
  static GType type = 0;

  if (!type)
    type = g_enum_register_static ("GIOError", _gperl_g_io_error_values);

  return type;
}

#define GPERL_TYPE_IO_ERROR gperl_g_io_error_get_type()
GType gperl_g_io_error_get_type (void);


static const GEnumValue _gperl_g_io_channel_error_values[] = {
  { G_IO_CHANNEL_ERROR_FBIG, "G_IO_CHANNEL_ERROR_FBIG", "fbig" },
  { G_IO_CHANNEL_ERROR_INVAL, "G_IO_CHANNEL_ERROR_INVAL", "inval" },
  { G_IO_CHANNEL_ERROR_IO, "G_IO_CHANNEL_ERROR_IO", "io" },
  { G_IO_CHANNEL_ERROR_ISDIR, "G_IO_CHANNEL_ERROR_ISDIR", "isdir" },
  { G_IO_CHANNEL_ERROR_NOSPC, "G_IO_CHANNEL_ERROR_NOSPC", "nospc" },
  { G_IO_CHANNEL_ERROR_NXIO, "G_IO_CHANNEL_ERROR_NXIO", "nxio" },
  { G_IO_CHANNEL_ERROR_OVERFLOW, "G_IO_CHANNEL_ERROR_OVERFLOW", "overflow" },
  { G_IO_CHANNEL_ERROR_PIPE, "G_IO_CHANNEL_ERROR_PIPE", "pipe" },
  { G_IO_CHANNEL_ERROR_FAILED, "G_IO_CHANNEL_ERROR_FAILED", "failed" },
  { 0, NULL, NULL }
};

GType
gperl_g_io_channel_error_get_type (void)
{
  static GType type = 0;

  if (!type)
    type = g_enum_register_static ("GIOChannelError", _gperl_g_io_channel_error_values);

  return type;
}

#define GPERL_TYPE_IO_CHANNEL_ERROR gperl_g_io_channel_error_get_type()
GType gperl_g_io_channel_error_get_type (void);



static const GEnumValue _gperl_g_markup_error_values[] = {
  { G_MARKUP_ERROR_BAD_UTF8, "G_MARKUP_ERROR_BAD_UTF8", "bad-utf8" },
  { G_MARKUP_ERROR_EMPTY, "G_MARKUP_ERROR_EMPTY", "empty" },
  { G_MARKUP_ERROR_PARSE, "G_MARKUP_ERROR_PARSE", "parse" },
  { G_MARKUP_ERROR_UNKNOWN_ELEMENT, "G_MARKUP_ERROR_UNKNOWN_ELEMENT", "unknown-element" },
  { G_MARKUP_ERROR_UNKNOWN_ATTRIBUTE, "G_MARKUP_ERROR_UNKNOWN_ATTRIBUTE", "unknown-attribute" },
  { G_MARKUP_ERROR_INVALID_CONTENT, "G_MARKUP_ERROR_INVALID_CONTENT", "invalid-content" },
  { 0, NULL, NULL }
};

GType
gperl_g_markup_error_get_type (void)
{
  static GType type = 0;

  if (!type)
    type = g_enum_register_static ("GMarkupError", _gperl_g_markup_error_values);

  return type;
}

#define GPERL_TYPE_MARKUP_ERROR gperl_g_markup_error_get_type()
GType gperl_g_markup_error_get_type (void);



static const GEnumValue _gperl_g_shell_error_values[] = {
  { G_SHELL_ERROR_BAD_QUOTING, "G_SHELL_ERROR_BAD_QUOTING", "bad-quoting" },
  { G_SHELL_ERROR_EMPTY_STRING, "G_SHELL_ERROR_EMPTY_STRING", "empty-string" },
  { G_SHELL_ERROR_FAILED, "G_SHELL_ERROR_FAILED", "failed" },
  { 0, NULL, NULL }
};

GType
gperl_g_shell_error_get_type (void)
{
  static GType type = 0;

  if (!type)
    type = g_enum_register_static ("GShellError", _gperl_g_shell_error_values);

  return type;
}

#define GPERL_TYPE_SHELL_ERROR gperl_g_shell_error_get_type()
GType gperl_g_shell_error_get_type (void);


static const GEnumValue _gperl_g_spawn_error_values[] = {
  { G_SPAWN_ERROR_FORK, "G_SPAWN_ERROR_FORK", "fork" },
  { G_SPAWN_ERROR_READ, "G_SPAWN_ERROR_READ", "read" },
  { G_SPAWN_ERROR_CHDIR, "G_SPAWN_ERROR_CHDIR", "chdir" },
  { G_SPAWN_ERROR_ACCES, "G_SPAWN_ERROR_ACCES", "acces" },
  { G_SPAWN_ERROR_PERM, "G_SPAWN_ERROR_PERM", "perm" },
  { G_SPAWN_ERROR_2BIG, "G_SPAWN_ERROR_2BIG", "2big" },
  { G_SPAWN_ERROR_NOEXEC, "G_SPAWN_ERROR_NOEXEC", "noexec" },
  { G_SPAWN_ERROR_NAMETOOLONG, "G_SPAWN_ERROR_NAMETOOLONG", "nametoolong" },
  { G_SPAWN_ERROR_NOENT, "G_SPAWN_ERROR_NOENT", "noent" },
  { G_SPAWN_ERROR_NOMEM, "G_SPAWN_ERROR_NOMEM", "nomem" },
  { G_SPAWN_ERROR_NOTDIR, "G_SPAWN_ERROR_NOTDIR", "notdir" },
  { G_SPAWN_ERROR_LOOP, "G_SPAWN_ERROR_LOOP", "loop" },
  { G_SPAWN_ERROR_TXTBUSY, "G_SPAWN_ERROR_TXTBUSY", "txtbusy" },
  { G_SPAWN_ERROR_IO, "G_SPAWN_ERROR_IO", "io" },
  { G_SPAWN_ERROR_NFILE, "G_SPAWN_ERROR_NFILE", "nfile" },
  { G_SPAWN_ERROR_MFILE, "G_SPAWN_ERROR_MFILE", "mfile" },
  { G_SPAWN_ERROR_INVAL, "G_SPAWN_ERROR_INVAL", "inval" },
  { G_SPAWN_ERROR_ISDIR, "G_SPAWN_ERROR_ISDIR", "isdir" },
  { G_SPAWN_ERROR_LIBBAD, "G_SPAWN_ERROR_LIBBAD", "libbad" },
  { G_SPAWN_ERROR_FAILED, "G_SPAWN_ERROR_FAILED", "failed" },
  { 0, NULL, NULL }
};

GType
gperl_g_spawn_error_get_type (void)
{
  static GType type = 0;

  if (!type)
    type = g_enum_register_static ("GSpawnError", _gperl_g_spawn_error_values);

  return type;
}

#define GPERL_TYPE_SPAWN_ERROR gperl_g_spawn_error_get_type()
GType gperl_g_spawn_error_get_type (void);



static const GEnumValue _gperl_g_thread_error_values[] = {
  { G_THREAD_ERROR_AGAIN, "G_THREAD_ERROR_AGAIN", "again" },
  { 0, NULL, NULL }
};

GType
gperl_g_thread_error_get_type (void)
{
  static GType type = 0;

  if (!type)
    type = g_enum_register_static ("GThreadError", _gperl_g_thread_error_values);

  return type;
}

#define GPERL_TYPE_THREAD_ERROR gperl_g_thread_error_get_type()
GType gperl_g_thread_error_get_type (void);


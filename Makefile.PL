#
# $Header$
#

use 5.008;
use ExtUtils::MakeMaker;
use Cwd;

# dependent modules will be able to 'use' these normally; for us, they
# aren't installed yet, so we have to cheat.
require 'PkgConfig.pm';

mkdir 'build', 0777;

%glibcfg = Glib::PkgConfig->find ('gobject-2.0');

# optional thread-safety
$nothreads = grep /disable[-_]threadsafe/i, @ARGV;
if (!$nothreads) {
	eval {
		%gthreadcfg = Glib::PkgConfig->find ('gthread-2.0');
	};
	$nothreads = 1 if $@;
}

if ($nothreads) {
	warn " *** \n";
	warn " *** configuring Glib to build without thread safety\n";
	warn " *** \n";
	%gthreadcfg = (
		cflags => ' -DGPERL_DISABLE_THREADSAFE ',
		libs => '',
	);
}



if ($glib = eval { require ExtUtils::Depends; ExtUtils::Depends->new ('Glib') }) {
   %pm_files = (
	'Glib.pm'      => '$(INST_LIBDIR)/Glib.pm',
	'PkgConfig.pm' => '$(INST_LIBDIR)/Glib/PkgConfig.pm',
	'Subclass.pm'  => '$(INST_LIBDIR)/Glib/Object/Subclass.pm',
   );
   %pod_files = (
	'Glib.pm'      => '$(INST_MAN3DIR)/Glib.3pm',
	'PkgConfig.pm' => '$(INST_MAN3DIR)/Glib::PkgConfig.3pm',
	'Subclass.pm'  => '$(INST_MAN3DIR)/Glib::Object::Subclass.3pm',
   );

   # add -I. and -I./build to the include path so we can find our own files.
   # this will be inherited by dependant modules, so they can find their
   # generated files.
   $glib->set_inc ($glibcfg{cflags} . $gthreadcfg{cflags} . ' -I. ');
   $glib->set_libs ($glibcfg{libs} . $gthreadcfg{libs});
   $glib->add_typemaps (cwd().'/typemap');
   $glib->add_headers ('"gperl.h"');
   $glib->install (qw(gperl.h));
   $glib->save_config ('build/IFiles.pm');
   $glib->add_pm (%pm_files);
   $glib->add_xs ('Glib.xs', 'GType.xs', 'GBoxed.xs', 'GObject.xs', 'GValue.xs',
                  'GClosure.xs', 'GSignal.xs', 'GMainLoop.xs', 'GParamSpec.xs');
}

WriteMakefile(
    NAME		=> 'Glib',
    VERSION_FROM	=> 'Glib.pm', # finds $VERSION
    PREREQ_FATAL	=> 1,
    PREREQ_PM		=> {
                             ExtUtils::Depends => 0.1,
                           },
    ABSTRACT_FROM	=> 'Glib.pm', # retrieve abstract from module
    XSPROTOARG		=> '-noprototypes',
    MAN3PODS		=> $glib ? \%pod_files : {},
    $glib ? $glib->get_makefile_vars : (),
);


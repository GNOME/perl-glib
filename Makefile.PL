#
# $Header$
#

use 5.008;
use ExtUtils::MakeMaker;
use Cwd;
use File::Spec;

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
   # this is the order in which we want the api docs from the XS files to
   # appear in Glib::xsapi
   @xs_files = qw(
	Glib.xs
	GType.xs
	GBoxed.xs
	GObject.xs
	GValue.xs
	GClosure.xs
	GSignal.xs
	GMainLoop.xs
	GIOChannel.xs
	GParamSpec.xs
   );
   %pm_files = (
	'Glib.pm'         => '$(INST_LIBDIR)/Glib.pm',
	'PkgConfig.pm'    => '$(INST_LIBDIR)/Glib/PkgConfig.pm',
	'Subclass.pm'     => '$(INST_LIBDIR)/Glib/Object/Subclass.pm',
	'devel.pod'       => '$(INST_LIBDIR)/Glib/devel.pod',
	'build/xsapi.pod' => '$(INST_LIBDIR)/Glib/xsapi.pod',
   );
   %pod_files = (
      'Glib.pm'         => '$(INST_MAN3DIR)/Glib.$(MAN3EXT)',
      'PkgConfig.pm'    => '$(INST_MAN3DIR)/Glib::PkgConfig.$(MAN3EXT)',
      'Subclass.pm'     => '$(INST_MAN3DIR)/Glib::Object::Subclass.$(MAN3EXT)',
      'devel.pod'       => '$(INST_MAN3DIR)/Glib::devel.$(MAN3EXT)',
      'build/xsapi.pod' => '$(INST_MAN3DIR)/Glib::xsapi.$(MAN3EXT)',
   );

   # add -I. and -I./build to the include path so we can find our own files.
   # this will be inherited by dependant modules, so they can find their
   # generated files.
   $glib->set_inc ($glibcfg{cflags} . $gthreadcfg{cflags} . ' -I. ');
   $glib->set_libs ($glibcfg{libs} . $gthreadcfg{libs});
   my $cwd = cwd();
   $glib->add_typemaps (map {File::Spec->catfile($cwd,$_)} 'typemap');
   $glib->add_headers ('"gperl.h"');
   $glib->install (qw(gperl.h));
   $glib->save_config ('build/IFiles.pm');
   $glib->add_pm (%pm_files);
   $glib->add_xs (@xs_files);
}

# exports list needed for win32, unused on others
require 'Glib.exports';

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
    FUNCLIST		=> \@exports,
    DL_FUNCS		=> { Glib => [] },
    $glib ? $glib->get_makefile_vars : (),
);

package MY;

# rule to build the documentation
sub postamble {
	return "
build/xsapi.pod: @main::xs_files xsapi.pod.head xsapi.pod.foot apidoc.pl
	$^X apidoc.pl xsapi.pod.head xsapi.pod.foot @main::xs_files > \$@

realclean ::
	-rm -Rf build
";
}

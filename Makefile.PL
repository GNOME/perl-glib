#
# $Header$
#

use 5.008;
use ExtUtils::MakeMaker;
use File::Spec;
use Cwd;

# minimum required version of dependancies we need to build
our %build_reqs = (
	'perl-ExtUtils-Depends'   => '0.1',
	'perl-ExtUtils-PkgConfig' => '1.00',
	'Glib'                    => '2.0.0',
);

# minimum required version of dependancies we need to run
our %runtime_reqs = (
	'Glib'	=> undef,
);

# Writing a fake Makefile ensures that CPAN will pick up the correct
# dependencies and install them.
unless (eval "use ExtUtils::Depends;"
           . "use ExtUtils::PkgConfig;"
           . "1") {
   warn "$@\n";
   WriteMakefile(
         PREREQ_FATAL => 1,
         PREREQ_PM    => {
            ExtUtils::Depends::   => $build_reqs{'perl-ExtUtils-Depends'},
            ExtUtils::PkgConfig:: => $build_reqs{'perl-ExtUtils-PkgConfig'},
         },
   );
   exit 1; # not reached
}

mkdir 'build', 0777;

%glibcfg = ExtUtils::PkgConfig->find ('gobject-2.0 >= '.$build_reqs{Glib});

$runtime_reqs{Glib} = $glibcfg{modversion};

# optional thread-safety
$nothreads = grep /disable[-_]threadsafe/i, @ARGV;
if (!$nothreads) {
	eval {
		%gthreadcfg = ExtUtils::PkgConfig->find ('gthread-2.0');
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


my $glib = ExtUtils::Depends->new ('Glib');
# this is the order in which we want the api docs from the XS files to
# appear in Glib::xsapi
@xs_files = qw(
	Glib.xs
	GLog.xs
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
     'Subclass.pm'     => '$(INST_LIBDIR)/Glib/Object/Subclass.pm',
     'devel.pod'       => '$(INST_LIBDIR)/Glib/devel.pod',
     'build/xsapi.pod' => '$(INST_LIBDIR)/Glib/xsapi.pod',
);
%pod_files = (
   'Glib.pm'         => '$(INST_MAN3DIR)/Glib.$(MAN3EXT)',
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

# exports list needed for win32, unused on others
require 'Glib.exports';

WriteMakefile(
    NAME		=> 'Glib',
    VERSION_FROM	=> 'Glib.pm', # finds $VERSION
    PREREQ_FATAL	=> 1,
    PREREQ_PM		=> {
        ExtUtils::Depends::   => $build_reqs{'perl-ExtUtils-Depends'},
        ExtUtils::PkgConfig:: => $build_reqs{'perl-ExtUtils-PkgConfig'},
    },
    ABSTRACT_FROM	=> 'Glib.pm', # retrieve abstract from module
    XSPROTOARG		=> '-noprototypes',
    MAN3PODS		=> $glib ? \%pod_files : {},
    FUNCLIST		=> \@exports,
    DL_FUNCS		=> { Glib => [] },
    $glib ? $glib->get_makefile_vars : (),
);

package MY;
use Cwd;

# rule to build the documentation
sub postamble {
	my @dirs = qw{rpms rpms/BUILD rpms/RPMS rpms/SOURCES
		      rpms/SPECS rpms/SRPMS};
	my $cwd = getcwd();

	my %subs = (
		'VERSION' => '$(VERSION)',
		'SOURCE' => '$(DISTNAME)-$(VERSION).tar.gz',
		'GLIB_RUN' => $runtime_reqs{'Glib'},
		'GLIB' => $build_reqs{'Glib'},
		'PERL_EXTUTILS_DEPENDS' => 
			$build_reqs{'perl-ExtUtils-Depends'},
		'PERL_EXTUTILS_PKGCONFIG' => 
			$build_reqs{'perl-ExtUtils-PkgConfig'},
	);
	
	my $substitute = '$(PERL) -npe \''.join('; ', map {
			"s/\\\@$_\\\@/$subs{$_}/g";
		} keys %subs).'\'';

	return "
build/xsapi.pod: @main::xs_files xsapi.pod.head xsapi.pod.foot apidoc.pl
	$^X apidoc.pl xsapi.pod.head xsapi.pod.foot @main::xs_files > \$@

realclean ::
	-\$(RM_RF) build perl-\$(DISTNAME).spec

rpms/:
	-mkdir @dirs

SUBSTITUTE=$substitute

perl-\$(DISTNAME).spec: perl-\$(DISTNAME).spec.in \$(VERSION_FROM) Makefile
	\$(SUBSTITUTE) \$+ > \$@

dist-rpms: Makefile dist perl-\$(DISTNAME).spec rpms/
	cp \$(DISTNAME)-\$(VERSION).tar.gz rpms/SOURCES/
	rpmbuild -ba --define \"_topdir $cwd/rpms\" perl-\$(DISTNAME).spec
";
}

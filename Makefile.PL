#
# $Header$
#

BEGIN { require 5.008; }

use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::Spec;
use Cwd;

# minimum required version of dependencies we need to build
our %build_reqs = (
	'perl-ExtUtils-Depends'   => '0.200',
	'perl-ExtUtils-PkgConfig' => '1.00',
	'Glib'                    => '2.0.0',
);
our %PREREQ_PM = (
	'ExtUtils::Depends'   => $build_reqs{'perl-ExtUtils-Depends'},
	'ExtUtils::PkgConfig' => $build_reqs{'perl-ExtUtils-PkgConfig'},
);

# Writing a fake Makefile ensures that CPAN will pick up the correct
# dependencies and install them.
unless (eval "use ExtUtils::Depends '$build_reqs{'perl-ExtUtils-Depends'}';"
           . "use ExtUtils::PkgConfig '$build_reqs{'perl-ExtUtils-PkgConfig'}';"
           . "1") {
   warn "$@\n";
   WriteMakefile(
         NAME         => 'Glib',
         PREREQ_FATAL => 1,
	 PREREQ_PM    => \%PREREQ_PM,
   );
   exit 1; # not reached
}

# client modules may use Glib::MakeHelper -- he's not installed at this
# point, so we have to require him directly.
require 'MakeHelper.pm';

mkdir 'build', 0777;

# this is the order in which we want the api docs from the XS files to
# appear in Glib::xsapi
our @xs_files = qw(
	Glib.xs
	GError.xs
	GUtils.xs
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

# Check version before including
if (ExtUtils::PkgConfig->atleast_version ('glib-2.0', '2.6.0')) {
	push @xs_files, 'GKeyFile.xs';
}

if (ExtUtils::PkgConfig->atleast_version ('glib-2.0', '2.12.0')) {
	push @xs_files, 'GBookmarkFile.xs';
}

our %pm_files = (
     'Glib.pm'         => '$(INST_LIBDIR)/Glib.pm',
     'Subclass.pm'     => '$(INST_LIBDIR)/Glib/Object/Subclass.pm',
     'ParseXSDoc.pm'   => '$(INST_LIBDIR)/Glib/ParseXSDoc.pm',
     'GenPod.pm'       => '$(INST_LIBDIR)/Glib/GenPod.pm',
     'CodeGen.pm'      => '$(INST_LIBDIR)/Glib/CodeGen.pm',
     'MakeHelper.pm'   => '$(INST_LIBDIR)/Glib/MakeHelper.pm',
     'devel.pod'       => '$(INST_LIBDIR)/Glib/devel.pod',
);
our %pod_files = (
   'Glib.pm'         => '$(INST_MAN3DIR)/Glib.$(MAN3EXT)',
   'Subclass.pm'     => '$(INST_MAN3DIR)/Glib::Object::Subclass.$(MAN3EXT)',
   'ParseXSDoc.pm'   => '$(INST_MAN3DIR)/Glib::ParseXSDoc.$(MAN3EXT)',
   'GenPod.pm'       => '$(INST_MAN3DIR)/Glib::GenPod.$(MAN3EXT)',
   'CodeGen.pm'      => '$(INST_MAN3DIR)/Glib::CodeGen.$(MAN3EXT)',
   'MakeHelper.pm'   => '$(INST_MAN3DIR)/Glib::MakeHelper.$(MAN3EXT)',
   'devel.pod'       => '$(INST_MAN3DIR)/Glib::devel.$(MAN3EXT)',
   '$(INST_LIB)/$(FULLEXT)/xsapi.pod' => '$(INST_MAN3DIR)/Glib::xsapi.$(MAN3EXT)',
   Glib::MakeHelper->do_pod_files (@xs_files),
);

my %glibcfg = ExtUtils::PkgConfig->find ('gobject-2.0 >= '.$build_reqs{Glib});

# optional thread-safety
my $nothreads;
if($Config::Config{usethreads}) {
	$nothreads = grep /disable[-_]threadsafe/i, @ARGV;
} else {
	$nothreads = 1;
}
my %gthreadcfg;
if (!$nothreads) {
	eval {
		%gthreadcfg = ExtUtils::PkgConfig->find ('gthread-2.0');
	};
	$nothreads = 1 if $@;
}
else
{
	warn " *** \n";
	warn " *** configuring Glib to build without thread safety\n";
	warn " *** \n";
	%gthreadcfg = (
		cflags => ' -DGPERL_DISABLE_THREADSAFE ',
		libs => '',
	);
}

our $glib = ExtUtils::Depends->new ('Glib');

# add -I. and -I./build to the include path so we can find our own files.
# this will be inherited by dependant modules, so they can find their
# generated files.
$glib->set_inc (' -I. ' . $glibcfg{cflags} . $gthreadcfg{cflags});
$glib->set_libs ($glibcfg{libs} . $gthreadcfg{libs});
my $cwd = cwd();
$glib->add_typemaps (map {File::Spec->catfile($cwd,$_)} 'typemap');
$glib->add_pm (%pm_files);
$glib->add_xs (@xs_files);
$glib->add_c (qw(gperl-gtypes.c));
$glib->install (qw(gperl.h gperl_marshal.h doctypes));
$glib->save_config ('build/IFiles.pm');

# exports list needed for win32, unused on others
our @exports;
require 'Glib.exports';

my $configure_requires =
  Glib::MakeHelper->get_configure_requires_yaml(%PREREQ_PM);

my $no_index_xs = "- " . join "\n  - ", @xs_files;

WriteMakefile(
    NAME		=> 'Glib',
    VERSION_FROM	=> 'Glib.pm', # finds $VERSION
    ABSTRACT_FROM	=> 'Glib.pm', # retrieve abstract from module
    PREREQ_PM		=> \%PREREQ_PM,
    XSPROTOARG		=> '-noprototypes',
    MAN3PODS		=> $glib ? \%pod_files : {},
    FUNCLIST		=> \@exports,
    DL_FUNCS		=> { Glib => [] },

    $glib ? $glib->get_makefile_vars : (),

    EXTRA_META    => qq/
$configure_requires
no_index:
    package:
    - MY
    file:
    - xsapi.pod.foot
    $no_index_xs
/,
);

#=unstable

print <<__EOW__;
WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING

   This is an unstable development release of Glib.  The API is not
   frozen and things are subject to change at any time.  Report any
   bugs to gtk-perl-list AT gnome DOT org as soon as possible.
   Please use the 1.16x series for important work.

WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING
__EOW__

#=cut

=frozen

print <<__EOW__;
WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING

   This is an unstable development release of Glib.  The API is frozen in
   accordance with the GNOME 2.16 schedule.  Report any bugs to gtk-perl-list
   AT gnome DOT org as soon as possible.

WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING
__EOW__

=cut

# rule to build the documentation
sub MY::postamble
{
	require 'MakeHelper.pm';
	return "
# these are special for Glib since it's providing the modules,
# it just has to make sure that they are ready before it can go
build/doc.pl :: \$(INST_LIB)/Glib/ParseXSDoc.pm

build/podindex :: \$(INST_LIB)/Glib/GenPod.pm

\$(INST_LIB)/\$(FULLEXT)/xsapi.pod :: build/doc.pl apidoc.pl xsapi.pod.head xsapi.pod.foot
	\$(NOECHO) \$(ECHO) Creating XS API documentation...
	\$(NOECHO) $^X apidoc.pl xsapi.pod.head xsapi.pod.foot build/doc.pl > \$@

"
	     . Glib::MakeHelper->postamble_clean ()
	     . Glib::MakeHelper->postamble_docs_full (
			DEPENDS => $glib,
			DOCTYPES => 'doctypes',
			COPYRIGHT_FROM => 'copyright.pod',
	       )
	     . Glib::MakeHelper->postamble_rpms (
			'GLIB' => $build_reqs{'Glib'},
			'PERL_EXTUTILS_DEPENDS' =>
				$build_reqs{'perl-ExtUtils-Depends'},
			'PERL_EXTUTILS_PKGCONFIG' =>
				$build_reqs{'perl-ExtUtils-PkgConfig'},
		);
}


__END__

Copyright (C) 2003-2007 by the gtk2-perl team (see the file AUTHORS for
the full list)

This library is free software; you can redistribute it and/or modify it under
the terms of the GNU Library General Public License as published by the Free
Software Foundation; either version 2.1 of the License, or (at your option) any
later version.

This library is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU Library General Public License for more
details.

You should have received a copy of the GNU Library General Public License along
with this library; if not, write to the Free Software Foundation, Inc., 59
Temple Place - Suite 330, Boston, MA  02111-1307  USA.

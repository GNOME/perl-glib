#
#
#

package MY;

sub const_cccmd {
	my $inherited = shift->SUPER::const_cccmd (@_);
	$inherited .= ' -o $@';
	$inherited;
}

package Glib::MakeHelper;

use strict;
use warnings;
use Exporter;
use Carp;
use Cwd;

our @ISA = qw/Exporter/;

our @EXPORT = qw/
		do_pod_files
		postamble_clean
		postamble_docs
		postamble_rpms
	       /;

our @gend_pods = ();
	
sub do_pod_files
{
	# try to get it from pwd first, then fall back to installed
	# this is so Glib will get associated copy, and everyone else
	# should use the installed glib copy
	eval { require 'ParseXSDoc.pm'; 1; } or require Glib::ParseXSDoc;
	$@ = undef;
	import Glib::ParseXSDoc;

	croak "\%main::pod_files is not available, should be our" 
		unless (%main::pod_files);

	open PARSE, '>build/Glib.doc.pl';
	select PARSE;
	my $pods = xsdocparse (@_);
	select STDOUT;
	@gend_pods = ();
	foreach (@$pods)
	{
		my $pod = $_;
		my $path = '$(INST_LIB)/$(NAME)';
		$pod =~ s/^[^\:]*:://;
		$path = "$path/$1" if ($pod =~ s/^(.*)::([^\:]+)/$2/);
		$path =~ s/::/\//g;
		$pod = "$path/$pod.pod";
		push @gend_pods, $pod;
		$main::pod_files{$pod} = '$(INST_MAN3DIR)/'.$_.'.$(MAN3EXT)';
	}
	$main::pod_files{'$(INST_LIB)/$(NAME)/index.pod'} = '$(INST_MAN3DIR)/$(NAME)::index.$(MAN3EXT)';
}

sub postamble_clean
{
"
realclean ::
	-\$(RM_RF) build perl-\$(DISTNAME).spec
";
}

sub postamble_docs
{
"
# documentation stuff
build/\$(NAME).doc.pl: Makefile @main::xs_files
	$^X -I \$(INST_LIB) -I \$(INST_ARCHLIB) -MGlib::ParseXSDoc \\
		-e 'xsdocparse (".join(", ",map {"\"$_\""} @main::xs_files).")' > \$@

build/xsapi.pod: build/\$(NAME).doc.pl apidoc.pl xsapi.pod.head xsapi.pod.foot
	$^X apidoc.pl xsapi.pod.head xsapi.pod.foot build/\$(NAME).doc.pl > \$@

@gend_pods build/podindex: Makefile build/\$(NAME).doc.pl
	$^X -I \$(INST_LIB) -I \$(INST_ARCHLIB) -MGlib::GenPod -M\$(NAME) \\
		-e \"xsdoc2pod('build/\$(NAME).doc.pl', '\$(INST_LIB)/\$(NAME)', 'build/podindex')\"

\$(INST_LIB)/\$(NAME)/index.pod: build/podindex
	$^X -e 'print \"\\n=head1 NAME\\n\\n\$(NAME) Pod Index\\n\\n=head1 PAGES\\n\\n\"' \\
		> \$(INST_LIB)/\$(NAME)/index.pod
	$^X -nae 'print \" \$\$F[1]\\n\";' < build/podindex >> \$(INST_LIB)/\$(NAME)/index.pod
"
}

sub postamble_rpms
{
	return '' if $^O eq 'MSWin32';
	
	my @dirs = qw{rpms rpms/BUILD rpms/RPMS rpms/SOURCES
		      rpms/SPECS rpms/SRPMS};
	my $cwd = getcwd();
	
	my %subs = (
		'VERSION' => '$(VERSION)',
		'SOURCE' => '$(DISTNAME)-$(VERSION).tar.gz',
		@_,
	);
	
	my $substitute = '$(PERL) -npe \''.join('; ', map {
			"s/\\\@$_\\\@/$subs{$_}/g";
		} keys %subs).'\'';

"
rpms/:
	-mkdir @dirs

SUBSTITUTE=$substitute

perl-\$(DISTNAME).spec: perl-\$(DISTNAME).spec.in \$(VERSION_FROM) Makefile
	\$(SUBSTITUTE) \$< > \$@

dist-rpms: Makefile dist perl-\$(DISTNAME).spec rpms/
	cp \$(DISTNAME)-\$(VERSION).tar.gz rpms/SOURCES/
	rpmbuild -ba --define \"_topdir $cwd/rpms\" perl-\$(DISTNAME).spec
";
}

1;

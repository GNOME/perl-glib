#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Getopt::Long;

our $VERSION = '1.00';

# defaults
our $verbose      = undef;
our $show_version = undef;
our $show_help    = undef;

GetOptions ('version'   => \$show_version,
            'verbose|v' => \$verbose,
            'help|h'    => \$show_help,);

# the rest are file names.
our @filenames = @ARGV;

die "$0: no input files.  (try --help)\n"
	unless @filenames;

die "$VERSION\n"
	if $show_version;

if ($show_help) {
		die <<EOH;
usage:   $0 [options] filenames...

Parse xs files for xsub signatures and pod.  Writes to standard output a
data structure suitable for eval'ing in another Perl script, describing
all the stuff found.  The output contains three variables:

  \$groups = ARRAYREF
      array of arrays structure containing the "package groups", as
	  determined by any =object directives found in the files.
	  These are listed in the order found.

  \$xspods = ARRAYREF
      array of pods found in the verbatim C portion of the XS file,
	  listed in the order found.  These are assumed to pertain to the
	  XS/C api, not the Perl api.  Any =for apidoc paragraphs following
	  an =object paragraphs in the verbatim sections are stripped (as
	  are the =object paragraphs), and will appear instead in
	  \$data->{\$package}{pods}.

  \$data = HASHREF
      big hash keyed by package name (as found in the MODULE line),
      containing under each key a hash with all the xsubs and pods
      in that package, in the order found.  Packages are consolidated
      across multiple files.

Options:

  -h
  -help
      show this message and exit.

  -v
  --verbose
      print the name of each file as we be parsing it; a simple form
	  of status report.

  --version
      show the version and exit.

(c) 2003 by muppet
EOH
}


# ===========================================================================

# some important state from the MODULE line:
our $module;   # the current MODULE.  defines the BOOT symbol, etc.
our $package;  # the current PACKAGE for any xsubs.  defaults to MODULE.
our $prefix;   # prefix to strip from xsub names.  defaults to nothing.

our @xspods = ();  # pods for the exported xs interface, e.g., the C stuff
our %data   = ();  # all the shizzle, by package name
our @groups = ();  # the various package groups, from =group lines.

#
#
#

our $filename = undef;
foreach $filename (@filenames) {
	# fem-BOTS!!!
	open IN, $filename or die "can't open $filename: $!\n";
	print STDERR "scanning $filename\n" if $verbose;

	# there was once a single state machine to parse an entire
	# file, but it turned into a bi-level state machine because
	# of the two-part nature of XS files.  that's silly, so i've
	# broken it into two loops: the part that scans up to the
	# first MODULE line, and the part that scans the rest of the
	# file.

	my $lastpod = undef;	# most recently-read pod (for next xsub)
	my @thesegroups = ();	# =for group lines detected in this file
	my @thesepackages = ();	# packages seen in this file

	# In the verbatim C portion of the file:
	# seek the first MODULE line *outside* comments.
	# collect any pod we encounter; only certain ones are 
	# precious to us...  my... preciousssss... ahem.
	$module = undef;
	$package = undef;
	$prefix = undef;
	while (<IN>) {
		chomp;
		# in the verbatim C section before the first MODULE line,
		# we need to be on the lookout for a few things...
		# we need the first MODULE line, of course...
		if (is_module_line ($_)) {
			last; # go to the next state machine.

		# mostly we want pods.
		} elsif (/^=/) {
			my $thispod = slurp_pod_paragraph ($_);
			# we're only interested in certain pod directives here.
			if (/^=for\s+(apidoc|object)\b/) {
				my $which = $1;
				warn "$filename:".($.-@{$thispod->{lines}}+1).":"
				   . " =for $which found before "
				   . "MODULE directive\n";
			}
			push @xspods, $thispod;

##		# we also need to track whether we're in a C comment, because
##		# MODULE directives are ignore in multiline comments.
##		} elsif (m{/\*}) {
##			# there was an open comment marker on this line.
##			# see if it's alone.
##			s{/\*.*\*/}{}g;
##			if (m{/\*}) {
##				# look for the end...
##				while (<IN>) {
##				}
##			}
		}
	}

	# preprocessor conditionals
	my @cond;

	$lastpod = undef;
	while (<IN>) {
		#
		# we're seeking xsubs and pods to document the Perl interface.
		#
		if (is_module_line ($_)) {
			# xsubs cannot steal pods across MODULE lines.
			$lastpod = undef;

		} elsif (/^\s*$/) {
			# ignore blank lines; but a blank line after a pod
			# means it can't be associated with an xsub.
			$lastpod = undef;

		} elsif (/^\s*#\s*(if|ifdef|ifndef)\s*(\s.*)$/) {
			#warn "conditional $1 $2\n";
			push @cond, $2;
			#print Dumper(\@cond);
		} elsif (/^\s*#\s*else\s*(\s.*)?$/) {
			#warn "else $cond[-1]\n";
		} elsif (/^\s*#\s*endif\s*(\s.*)?$/) {
			#warn "endif $cond[-1]\n";
			pop @cond;
		} elsif (/^\s*#/) {
			# ignore comments.  we've already determined that 
			# this isn't a preprocessor directive (or at least
			# not one in which we're interested).

		} elsif (/^(BOOT|PROTOTYPES)/) {
			# ignore keyword lines in which we aren't interested

		} elsif (/^=/) {
			# slurp in pod, up to and including the next =cut.
			# put it in $lastpod so that the next-discovered
			# xsub can claim it.
			$lastpod = slurp_pod_paragraph ($_);
			# store it for later, in case nobody claims it.
			# we're only interested in certain pod directives here.
			if (/^=for\s+object(?:\s+(.*))?/) {
				$package = $1;
			}
			push @{ $data{$package}{pods} }, $lastpod;

		} elsif (/^\w+/) {
			# there's something at the beginning of the line!
			# we've ruled out everything else, so this must be
			# an xsub.  slurp in everything up to the next
			# blank line (or end of file).   i know that's not
			# *really* an entire XSUB body, but we don't care
			# -- we only need the return value, name, arg types,
			# and body type, and there aren't supposed to be 
			# blank lines in all of that.
			my @thisxsub = ($_);
			while (<IN>) {
				chomp;
				last if /^\s*$/;
				push @thisxsub, $_;
			}
			my $xsub = parse_xsub (@thisxsub);
			if ($lastpod) {
				# aha! we'll lay claim to that...
				pop @{ $data{$package}{pods} };
				$xsub->{pod} = $lastpod;
				$lastpod = undef;
			}
			push @{ $data{$package}{xsubs} }, $xsub;

		} else {
			# this is probably xsub function body, comment, or
			# some other stuff we don't care about.
		}
	}

	# that's it for this file...
	close IN;
}


# 
# save the data
#

use POSIX qw(strftime);
print "# THIS FILE IS AUTOMATICALLY GENERATED - ANY CHANGES WILL BE LOST\n";
print "# generated by $0 ".strftime ('%a %b %e %H:%M:%S %Y', localtime)."\n";
print "# input files:\n";
map { print "#   $_\n" } @filenames;
print "#\n\n";
print Data::Dumper->Dump([\@groups, \@xspods, \%data],
                       [qw($groups   $xspods   $data)]);
print "\n1;\n";

# fin
exit;

# ===============================================================

=item bool = is_module_line ($line)

Analyze I<$line> to see if it contains an XS MODULE directive.  If so,
returns true after setting the globals I<$module>, I<$package>, and
I<$prefix> accordingly.

=cut
sub is_module_line {
	my $l = shift;
	if ($l =~ /^MODULE\s*=\s*([:\w]+)
	            (?:\s+PACKAGE\s*=\s*([:\w]+)
	            (?:\s+PREFIX\s*=\s*([:\w]+))?)?
	            /x) {
		$module  = $1;
		$package = $2 || $module;
		$prefix  = $3;
		return 1;
	} else {
		return 0;
	}
}


=item $pod = slurp_pod_paragraph ($firstline, $filehandle=\*IN, $term_regex=/^=cut\s*/)

Slurp up POD lines from I<$filehandle> from here to the next
I<$term_regex> or EOF.  Since you probably already read a
line to determine that we needed to start a pod, you can pass
that first line to be included.

=cut
sub slurp_pod_paragraph {
	my $firstline  = shift;
	my $filehandle = shift || \*IN;
	my $term_regex = shift || qr/^=cut\s*/o;

	my @lines = $firstline ? ($firstline) : ();
	while (my $line = <$filehandle>) {
		chomp $line;
		push @lines, $line;
		last if $line =~ m/$term_regex/;
	}

	return {
		filename => $filename,
		line => $. - @lines,
		lines => \@lines,
	};
}


=item $xsub = parse_xsub (@lines)

Parse an xsub header, in the form of a list of lines,
into a data structure describing the xsub.  That includes
pulling out the argument types, aliases, and code type.

Without artificial intelligence, we cannot reliably 
determine anything about the types or number of parameters
returned from xsubs with PPCODE bodies.

OUTLIST parameters are pulled from the args list and put
into an "outlist" key.

Data type names are not mangled at all.

=cut
sub parse_xsub {
	my @thisxsub = @_;
	map { s/#.*$// } @thisxsub;

$SIG{__WARN__} = sub {
		warn "$filename:$.:  "
		   . join(" / ", $module||"", $package||"")
		   . "\n    $_[0]\n   ".Dumper(\@thisxsub)
};

	my $lineno = $. - @thisxsub;
	my %xsub = (
		'filename' => $filename,
		'line' => ($.-@thisxsub),
		'module' => $module,
		'package' => ($package || $module),
	);
	my $args;

	#warn Dumper(\@thisxsub);

	if ($thisxsub[0] =~ /^([^(]+\s+\*?)\b([:\w]+)\s*\(\s*(.+)\s*\)\s*;?\s*$/) {
		# all on one line
		$xsub{return_type} = [$1]
			unless $1 eq 'void';
		$xsub{symname} = $2;
		$args = $3;
		shift @thisxsub; $lineno++;
	} elsif ($thisxsub[1] =~ /^(\S+)\s*\((.+)\);?\s*$/) {
		# multiple lines
		$xsub{symname} = $1;
		$args = $2;
		# return type is on line 0
		$thisxsub[0] =~ s/\s*$//;
		$xsub{return_type} = [$thisxsub[0]]
			unless $thisxsub[0] eq 'void';
		shift @thisxsub; $lineno++;
		shift @thisxsub; $lineno++;
	}

	warn "$filename:$lineno: WTF : args string is empty\n"
		if not defined $args;

	my %args = ();
	my @argstr = split /\s*,\s*/, $args;
	#print Dumper([$args, \@args]);
	for (my $i = 0 ; $i < @argstr ; $i++) {
		# the last one can be an ellipsis, let's handle that specially
		if ($i == $#argstr and $argstr[$i] eq '...') {
			$args{'...'} = { name => '...', };
			push @{ $xsub{args} }, $args{'...'};
			last;
		}
		$argstr[$i] =~ /^(OUTLIST\s+)?      # OUTLIST would be 1st
		                 ([^=]+(?:\b|\s))?  # arg type is optional, too
		                 (\w+)              # arg name
		                 (?:\s*=\s*(.+))?   # possibly a default value
		                 $/x;
		if (defined $1) {
			push @{ $xsub{outlist} }, {
				type => $2,
				name => $3,
			};
			
		} else {
			$args{$3} = {
				type => $2,
				name => $3,
			};
			$args{$3}{default} = $4 if defined $4;
			push @{ $xsub{args} }, $args{$3};
		}
	}

	

	my $xstate = 'args';
	while ($_ = shift @thisxsub) {
		if (/^\s*ALIAS:/) {
			$xstate = 'alias';
		} elsif (/\s*(PREINIT|CLEANUP|OUTPUT|C_ARGS):/) {
			$xstate = 'code';
		} elsif (/\s*(PPCODE|CODE):/) {
			$xsub{codetype} = $1;
			last;
		} elsif ($xstate eq 'alias') {
			/^\s*([:\w]+)\s*=\s*(\d+)\s*$/;
			if (defined $2) {
				$xsub{alias}{$1} = $2;
			} else {
				warn "$filename:$lineno: WTF : seeking alias on line $_\n";
			}
		} elsif ($xstate eq 'args') {
			if (/^\s*
			      (.+(?:\b|\s))      # datatype
			      (\w+)              # arg name
			      ;?                 # optional trailing semicolon
			      \s*$/x)
			{
				if (exists $args{$2}) {
					$args{$2}{type} = $1
				} else {
					warn "$filename:$lineno: unused arg $2\n";
					warn "  line was '$_'\n";
				}
			} elsif (/^\s*/) {
				# must've stripped a comment.
			} else {
				warn "$filename:$lineno: WTF : seeking args on line $_\n";
			}
		}
		$lineno++;
	}

	# mangle the symbol name from an xsub into its actual perl name.
	$xsub{original_name} = $xsub{symname};
	if (defined $prefix) {
		$xsub{symname} =~ s/^($prefix)?/$package\::/;
	} else {
		$xsub{symname} = ($package||$module)."::".$xsub{symname};
	}

	# sanitize all the C type declarations, which we have 
	# collected in the arguments, outlist, and return types.
	if ($xsub{args}) {
		foreach my $a (@{ $xsub{args} }) {
			$a->{type} = sanitize_type ($a->{type})
				if defined $a->{type};
		}
	}
	if ($xsub{outlist}) {
		foreach my $a (@{ $xsub{outlist} }) {
			$a->{type} = sanitize_type ($a->{type})
				if defined $a->{type};
		}
	}
	if ($xsub{return_type}) {
		for (my $i = 0 ; $i < @{ $xsub{return_type} } ; $i++) {
			$xsub{return_type}[$i] =
				sanitize_type ($xsub{return_type}[$i]);
		}
	}

delete $SIG{__WARN__};

	return \%xsub;
}



sub sanitize_type {
		local $_ = shift;
		s/\s+/ /g;        # squash all whitespace
		s/^\s//;          # zap leading space
		s/\s$//;          # zap trailing space
		s/(?<=\S)\*$/ */; # stars may not be glued to the name
		return $_;
}


__END__

Copyright (C) 2003 by muppet

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

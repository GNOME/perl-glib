package Glib::ParseXSDoc;

# vim: set ts=4 :

use strict;
use Data::Dumper;
use Exporter;
use Carp;

our @ISA = qw(Exporter);
our @EXPORT = qw(
	xsdocparse
);

our $VERSION = '1.002';

our $NOISY = $ENV{NOISYDOC};

=head1 NAME

Glib::ParseXSDoc - Parse POD and XSub declarations from XS files.

=head1 DESCRIPTION

This is the heart of an automatic API reference documentation system for
XS-based Perl modules.  FIXME more info here!!

FIXME document recognized POD directives and the output data structures

=head1 FUNCTIONS

=over

=item xsdocparse (@filenames)

Parse xs files for xsub signatures and pod.  Writes to standard output a
data structure suitable for eval'ing in another Perl script, describing
all the stuff found.  The output contains three variables:

=over

=item $xspods = ARRAYREF

array of pods found in the verbatim C portion of the XS file, listed in the
order found.  These are assumed to pertain to the XS/C api, not the Perl api.
Any C<=for apidoc> paragraphs following an C<=object> paragraphs in the
verbatim sections are stripped (as are the C<=object> paragraphs), and will
appear instead in C<< $data->{$package}{pods} >>.

=item $data = HASHREF

big hash keyed by package name (as found in the MODULE line), containing under
each key a hash with all the xsubs and pods in that package, in the order
found.  Packages are consolidated across multiple files.

=back

FYI, this creates a new parser and calls C<parse_file> on it for each
input filename; then calls C<swizzle_pods> to ensure that any
C<=for apidoc name> pods are matched up with their target xsubs; and
finally calls Data::Dumper to write the data to stdout.  So, if you want
to get finer control over how the output is created, or keep all the data
in-process, now you know how.  :-)

=cut

sub xsdocparse {
	my @filenames = @_;

	my $parser = Glib::ParseXSDoc->new;
	foreach my $filename (@filenames) {
		$parser->parse_file ($filename);
	}
	$parser->canonicalize_xsubs;
	$parser->swizzle_pods;
	$parser->preprocess_pods;
	$parser->clean_out_empty_pods;

	print "# THIS FILE IS AUTOMATICALLY GENERATED - ANY CHANGES WILL BE LOST\n";
	print "# generated by $0 ".scalar (localtime)."\n";
	print "# input files:\n";
	map { print "#   $_\n" } @filenames;
	print "#\n\n";
	$Data::Dumper::Purity = 1;
	print Data::Dumper->Dump([$parser->{xspods}, $parser->{data}],
	                       [qw($xspods            $data)]);
	print "\n1;\n";

	return [ keys %{$parser->{data}} ];
}


=back

=cut

# =========================================================================

=head1 METHODS

=over

=item $Glib::ParseXSDoc::verbose

If true, this causes the parser to be verbose.

=cut

our $verbose = undef;


=item $parser = Glib::ParseXSDoc->new

Create a new xsub parser.

=cut
sub new {
	my $class = shift;
	return bless {
		# state
		module => undef,
		package => undef,
		prefix => undef,
		# data
		xspods => [],	#pods for the exported xs interface, e.g. the C stuff
		data => {},	# all the shizzle, by package name
	}, $class;
}

=item string = $parser->package

Get the current package name.  Falls back to the module name.  Will be undef
if the parser hasn't reached the first MODULE line.

=cut
sub package {
		my $self = shift;
		return ($self->{package} || $self->{module})
}

=item HASHREF = $parser->pkgdata

The data hash corresponding to the current package, honoring the most recently
encounter C<=for object> directive.  Ensures that it exists.
Returns a reference to the member of the main data structure, so modifications
are permanent and useful.

=cut
sub pkgdata {
		my $self = shift;
		my $pkg = $self->{object} || $self->package;
		my $pkgdata = $self->{data}{$pkg};
		if (not defined $pkgdata) {
				$pkgdata = {};
				$self->{data}{$pkg} = $pkgdata;
		}
		return $pkgdata;
}


=item $parser->parse_file (filename)

Parse one xs file.  Stores all the collected data in I<$parser>'s internal
data structures.

=cut
sub parse_file {
	my $self = shift;
	my $filename = shift;

	local *IN;
	open IN, $filename or die "can't open $filename: $!\n";
	print STDERR "scanning $filename\n" if $verbose;
	$self->{filehandle} = \*IN;
	$self->{filename} = $filename;

	# there was once a single state machine to parse an entire
	# file, but it turned into a bi-level state machine because
	# of the two-part nature of XS files.  that's silly, so i've
	# broken it into two loops: the part that scans up to the
	# first MODULE line, and the part that scans the rest of the
	# file.

	my $lastpod = undef;	# most recently-read pod (for next xsub)
	my @thesepackages = ();	# packages seen in this file

	# In the verbatim C portion of the file:
	# seek the first MODULE line *outside* comments.
	# collect any pod we encounter; only certain ones are 
	# precious to us...  my... preciousssss... ahem.
	$self->{module}  = undef;
	$self->{package} = undef;
	$self->{prefix}  = undef;
	$self->{object}  = undef;
	while (<IN>) {
		chomp;
		# in the verbatim C section before the first MODULE line,
		# we need to be on the lookout for a few things...
		# we need the first MODULE line, of course...
		if ($self->is_module_line ($_)) {
			last; # go to the next state machine.

		# mostly we want pods.
		} elsif (/^=/) {
			my $thispod = $self->slurp_pod_paragraph ($_);
			# we're only interested in certain pod directives here.
			if (/^=for\s+(apidoc|object)\b/) {
				my $which = $1;
				warn "$filename:".($.-@{$thispod->{lines}}+1).":"
				   . " =for $which found before "
				   . "MODULE directive\n";
			}
			push @{ $self->{xspods} }, $thispod;

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
		if ($self->is_module_line ($_)) {
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
			$lastpod = $self->slurp_pod_paragraph ($_);

			# we're interested in certain pod directives at
			# this point...
			if (/^=for\s+object(?:\s+([\w\:]*))?(.*)/) {
				$self->{object} = $1;
				if ($2) {
					$self->pkgdata->{blurb} = $2;
					if ($self->pkgdata->{blurb} =~ s/\((.*)\)//)
					{
						print STDERR "Documenting object $1 in file "
									.$self->{object}."\n";
						$self->pkgdata->{object} = $1;
					}
					$self->pkgdata->{blurb} =~ s/^\s*-\s*//;
				}
			} elsif (/^=for\s+(enum|flags)\s+([\w:]+)/) {
				push @{ $self->pkgdata->{enums} }, {
					type => $1,
					name => $2,
					pod => $lastpod,
				};
				# claim this pod now!
				$lastpod = undef;
			} elsif (/^=for\s+see_also\s+(.+)$/) {
				push @{ $self->pkgdata->{see_alsos} }, $1;
				# claim this pod now!
				$lastpod = undef;
			}
			push @{ $self->pkgdata->{pods} }, $lastpod
				if defined $lastpod;

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
			my $xsub = $self->parse_xsub (@thisxsub);
			if ($lastpod) {
				# aha! we'll lay claim to that...
				pop @{ $self->pkgdata->{pods} };
				$xsub->{pod} = $lastpod;
				$lastpod = undef;
			}
			push @{ $self->pkgdata->{xsubs} }, $xsub;

		} else {
			# this is probably xsub function body, comment, or
			# some other stuff we don't care about.
		}
	}

	# that's it for this file...
	close IN;
	delete $self->{filehandle};
	delete $self->{filename};
}


=item $parser->swizzle_pods

Match C<=for apidoc> pods to xsubs.

=cut
sub swizzle_pods {
	my $self = shift;
	foreach my $package (keys %{$self->{data}}) {
		my $pkgdata = $self->{data}{$package};
		next unless $pkgdata->{pods};
		next unless $pkgdata->{xsubs};
		my $pods = $pkgdata->{pods};
		for (my $i = @$pods-1 ; $i >= 0 ; $i--) {
			my $firstline = $pods->[$i]{lines}[0];
			next unless $firstline =~ /=for\s+apidoc\s+([:\w]+)\s*/;
			my $name = $1;
			foreach my $xsub (@{ $pkgdata->{xsubs} }) {
				if ($name eq $xsub->{symname}) {
					$xsub->{pod} = $pods->[$i];
					splice @$pods, $i, 1;
					last;
				}
			}
		}
	}
}


=item $parser->preprocess_pods

Honor the C<__hide__> and C<__function__> directives in C<=for apidoc> lines.

We look for the strings anywhere, but you'll typically have it at the end of
the line, e.g.:

  =for apidoc symname __hide__        for detached blocks
  =for apidoc __hide__                for attached blocks

  =for apidoc symname __function__    for functions rather than methods
  =for apidoc __function__            for functions rather than methods

=cut
sub preprocess_pods {
	my $self = shift;
	foreach my $package (keys %{$self->{data}}) {
		my $pkgdata = $self->{data}{$package};

		foreach (@{$pkgdata->{pods}})
		{
			my $firstline = $_->{lines}[0];
			if ($firstline) {
				$_->{position} = $1 if ($firstline =~ /=for\s+position\s+(\w+)/);
			}
		}

		next unless $pkgdata->{xsubs};

		# look for magic keywords in the =for apidoc
		foreach (@{$pkgdata->{xsubs}})
		{
			my $firstline = $_->{pod}{lines}[0];
			if ($firstline) {
				$_->{function} = ($firstline =~ /__function__/);
				$_->{hidden} = ($firstline =~ /__hide__/);
				$_->{gerror} = ($firstline =~ /__gerror__/);
			}
		}
	}
}


# ===============================================================

=item bool = $parser->is_module_line ($line)

Analyze I<$line> to see if it contains an XS MODULE directive.  If so, returns
true after setting the I<$parser>'s I<module>, I<package>, and I<prefix>
accordingly.

=cut
sub is_module_line {
	my $self = shift;
	my $l = shift;
	if ($l =~ /^MODULE\s*=\s*([:\w]+)
	            (?:\s+PACKAGE\s*=\s*([:\w]+)
	            (?:\s+PREFIX\s*=\s*([:\w]+))?)?
	            /x) {
		$self->{module}  = $1;
		$self->{package} = $2 || $self->{module};
		$self->{prefix}  = $3;
		$self->{object}  = undef;
		return 1;
	} else {
		return 0;
	}
}


=item $pod = $parser->slurp_pod_paragraph ($firstline, $term_regex=/^=cut\s*/)

Slurp up POD lines from I<$filehandle> from here to the next
I<$term_regex> or EOF.  Since you probably already read a
line to determine that we needed to start a pod, you can pass
that first line to be included.

=cut
sub slurp_pod_paragraph {
	my $parser     = shift;
	my $firstline  = shift;
	my $term_regex = shift || qr/^=cut\s*/o;
	my $filehandle = $parser->{filehandle};

	# just in case.
	chomp $firstline;

	my @lines = $firstline ? ($firstline) : ();
	while (my $line = <$filehandle>) {
		chomp $line;
		push @lines, $line;
		last if $line =~ m/$term_regex/;
	}

	return {
		filename => $parser->{filename},
		line => $. - @lines,
		lines => \@lines,
	};
}


=item $xsub = $parser->parse_xsub (@lines)

Parse an xsub header, in the form of a list of lines,
into a data structure describing the xsub.  That includes
pulling out the argument types, aliases, and code type.

Without artificial intelligence, we cannot reliably 
determine anything about the types or number of parameters
returned from xsubs with PPCODE bodies.

OUTLIST parameters are pulled from the args list and put
into an "outlist" key.  IN_OUTLIST parameters are put into
both.

Data type names are not mangled at all.

=cut
sub parse_xsub {
	my ($self, @thisxsub) = @_;

	map { s/#.*$// } @thisxsub;

	my $filename = $self->{filename};
	my $oldwarn = $SIG{__WARN__};
#$SIG{__WARN__} = sub {
#		warn "$self->{filename}:$.:  "
#		   . join(" / ", $self->{module}||"", $self->{package}||"")
#		   . "\n    $_[0]\n   ".Dumper(\@thisxsub)
#};

	my $lineno = $. - @thisxsub;
	my %xsub = (
		'filename' => $filename,
		'line' => ($.-@thisxsub),
		'module' => $self->{module},
		'package' => $self->package, # to be overwritten as needed
	);
	my $args;

	#warn Dumper(\@thisxsub);

	# merge continuation lines.  xsubpp allows continuation lines in the
	# xsub arguments list and barfs on them in other spots, but with xsubpp
	# providing such validation, we'll just cheat and merge any that we find.
	# this will bork the line counting logic we have below, but i don't see
	# a fix for it without major tearup of the code here.
	my @foo = @thisxsub;
	@thisxsub = shift @foo;
	while (my $s = shift @foo) {
		if ($thisxsub[$#thisxsub] =~ s/\\$//) {
			$thisxsub[$#thisxsub] .= $s;
		} else {
			push @thisxsub, $s;
		}
	}

	if ($thisxsub[0] =~ /^([^(]+\s+\*?)   # return type, possibly with a *
						  \b([:\w]+)\s*   # symbol name
						  \(              # open paren
						    (.*)          # whatever's inside, if anything
						  \)              # close paren, maybe with space
						  \s*;?\s*$/x) {  # and maybe other junk at the end
		# all on one line
		$xsub{symname} = $2;
		$args = $3;
		my $r = $1;
		$xsub{return_type} = [$r]
			unless $r =~ /^void\s*$/;
		shift @thisxsub; $lineno++;

	} elsif ($thisxsub[1] =~ /^(\S+)\s*\((.*)\);?\s*$/) {
		# multiple lines
		$xsub{symname} = $1;
		$args = $2;
		# return type is on line 0
		$thisxsub[0] =~ s/\s*$//;
		$xsub{return_type} = [$thisxsub[0]]
			unless $thisxsub[0] =~ /^void\s*$/;
		shift @thisxsub; $lineno++;
		shift @thisxsub; $lineno++;
	}

	# eat padding spaces from the arg string.  i tried several ways of
	# building this into the regexen above, but found nothing that still
	# allowed the arg string to be empty, which we'll have for functions
	# (not methods) without resorting to extremely arcane negatory
	# lookbeside assertiveness operators.
	$args =~ s/^\s*//;
	$args =~ s/\s*$//;

	# we can get empty arg strings on non-methods.
	#warn "$filename:$lineno: WTF : args string is empty\n"
	#	if not defined $args;

	my %args = ();
	my @argstr = split /\s*,\s*/, $args;
	#warn Dumper([$args, \%args, \@argstr]);
	for (my $i = 0 ; $i < @argstr ; $i++) {
		# the last one can be an ellipsis, let's handle that specially
		if ($i == $#argstr and $argstr[$i] eq '...') {
			$args{'...'} = { name => '...', };
			push @{ $xsub{args} }, $args{'...'};
			last;
		}
		if ($argstr[$i] =~
		               /^(?:(IN_OUTLIST|OUTLIST)\s+)? # OUTLIST would be 1st
		                 ([^=]+(?:\b|\s))?  # arg type is optional, too
		                 (\w+)              # arg name
		                 (?:\s*=\s*(.+))?   # possibly a default value
		                 $/x) {
			if (defined $1) {
				push @{ $xsub{outlist} }, {
					type => $2,
					name => $3,
				};
				if ($1 eq 'IN_OUTLIST') {
					# also an arg
					$args{$3} = {
						type => $2,
						name => $3,
					};
					$args{$3}{default} = $4 if defined $4;
					push @{ $xsub{args} }, $args{$3};
				}
			
			} else {
				$args{$3} = {
					type => $2,
					name => $3,
				};
				$args{$3}{default} = $4 if defined $4;
				push @{ $xsub{args} }, $args{$3};
			}
		} elsif ($argstr[$i] =~ /^g?int\s+length\((\w+)\)$/) {
			#warn " ******* $i is string length of $1 *****\n";
		} else {
			warn "$filename:$lineno: ($xsub{symname}) don't know how to"
			   . " parse arg $i, '$argstr[$i]'\n";
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
	if (defined $self->{prefix}) {
		my $pkg = $self->package;
		$xsub{symname} =~ s/^($self->{prefix})?/$pkg\::/;
	} else {
		$xsub{symname} = ($self->package)."::".$xsub{symname};
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

	$SIG{__WARN__} = $oldwarn;

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


sub canonicalize_xsubs {
	my $self = shift;

	return undef unless 'HASH' eq ref $self->{data};

	# make sure that each package contains an xsub hash for each
	# xsub, whether an alias or not.
	foreach my $package (keys %{$self->{data}}) {
		my $pkgdata = $self->{data}{$package};
		next unless $pkgdata or $pkgdata->{xsubs};
		my $xsubs = $pkgdata->{xsubs};
		@$xsubs = map { split_aliases ($_) } @$xsubs;
	}
}

sub split_aliases {
	my $xsub = shift;
	return $xsub unless exists $xsub->{alias};
	return $xsub unless 'HASH' eq ref $xsub->{alias};
	my %aliases = %{ $xsub->{alias} };
	my @xsubs = ();
	my %seen = ();
	foreach my $a (sort { $aliases{$a} <=> $aliases{$b} } keys %aliases) {
		push @xsubs, {
			%$xsub,
			symname => $a,
			pod => undef,
			# we do a deep copy on the args, so that changes to one do not
			# affect another.  in particular, adding docs or hiding an arg
			# in one xsub shouldn't affect another.
			args => deep_copy_ref ($xsub->{args}),
		};
		$seen{ $aliases{$a} }++;
	}
	if (! $seen{0}) {
		unshift @xsubs, $xsub;
	}

	return @xsubs;
}


sub deep_copy_ref {
		my $ref = shift;
		return undef if not $ref;
		my $reftype = ref $ref;
		if ('ARRAY' eq $reftype) {
				my @newary = map { deep_copy_ref ($_) } @$ref;
				return \@newary;
		} elsif ('HASH' eq $reftype) {
				my %newhash = map { $_, deep_copy_ref ($ref->{$_}) } keys %$ref;
				return \%newhash;
		} else {
				return $ref;
		}
}

=item $parser->clean_out_empty_pods

Looks throught the data memeber of the parser and removes any keys (and
associated values) when no pod, enums, and xsubs exist for the package.

=cut

sub clean_out_empty_pods
{
	my $data = shift;
	return unless (exists ($data->{data}));
	$data = $data->{data};

	my $pod;
	my $xsub;
	foreach (keys %$data)	
	{
		$pod = $data->{$_};
		next if ((exists $pod->{pods} and scalar @{$pod->{pods}}) or
				 exists $pod->{enums} or 
				 scalar (grep (!/DESTROY/, 
								 map { $_->{hidden} 
								       ? ()
									   : $_->{symname} }
								 	@{$pod->{xsubs}})));
		print STDERR "Deleting $_ from doc.pl's \$data\n";
		delete $data->{$_}; 
	}
}


1;

__END__

=back

=head1 AUTHOR

muppet E<lt>scott at asofyet dot orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2003, 2004 by muppet

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

=cut

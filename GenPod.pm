package Glib::GenPod;

use Glib;

use base Exporter;

@EXPORT = qw(
	podify_properties
	podify_values
	podify_signals
	podify_ancestors
	podify_interfaces
	podify_methods
);

# more sensible names for the basic types
%basic_types = (
	# the perl wrappers for the GLib fundamentals
	'Glib::Scalar'  => '$scalar',
	'Glib::String'  => '$string',
	'Glib::Int'     => '$integer',
	'Glib::Uint'    => '$unsigned',
	'Glib::Double'  => '$double',
	'Glib::Boolean' => '$boolean',

	# other C names which may sneak through
	boolean => '$boolean',
	int     => '$integer',
	char    => '$integer',
	uint    => '$integer',
	float   => '$double',
	double  => '$double',
	char    => '$string',

	gboolean => '$boolean',
	gint     => '$integer',
	gint8    => '$integer',
	gint16   => '$integer',
	gint32   => '$integer',
	guint8   => '$integer',
	guint16  => '$integer',
	guint32  => '$integer',
	gchar    => '$integer',
	guint    => '$integer',
	gfloat   => '$double',
	gdouble  => '$double',
	gchar    => '$string',

	SV       => '$scalar',
	UV       => '$integer',
	IV       => '$integer',

	gchar_length => '$gchar_length',

# TODO/FIXME:
	GIOCondition	=> 'GIOCondition',
	GMainContext	=> 'GMainContext',
	GMainLoop	=> 'GMainLoop',
	GParamSpec	=> 'GParamSpec',
	GtkTargetList   => '$Gtk2::TargetList',
	GdkAtom         => '$Gtk2::Gdk::Atom',
	GdkBitmap       => '$Gtk2::Gdk::Bitmap',
	GdkNativeWindow => '$Gtk2::Gdk::NativeWindow',
);

sub podify_properties {
	my $package = shift;
	my @properties;
	eval { @properties = $package->list_properties; 1; };
# FIXME:	warn $@ unless ();
	return undef unless (@properties or not defined ($@));

	my $str = "=over\n\n";
	foreach my $p (sort { $a->{name} cmp $b->{name} } @properties) {
		next unless $p->{owner_type} eq $package;
		$stat = join " / ",  @{ $p->{flags} };
		$type = exists $basic_types{$p->{type}}
		      ? $basic_types{$p->{type}}
		      : $p->{type};
		$str .= "=item '$p->{name}' ($type : $stat)\n\n";
		$str .= "$p->{descr}\n\n" if (exists ($p->{descr}));
	}
	$str .= "=back\n\n";

	$str
}

sub podify_values {
	my $package = shift;
	my @values = Glib::Type->list_values ($package);
	return undef unless @values;

	return "=over\n\n"
	     . join ("\n\n", map { "=item $_->{nick} / $_->{name}" } @values)
	     . "\n\n=back\n\n";
}

sub podify_signals {
	my @sigs;
	eval { @sigs = Glib::Type->list_signals (shift); 1; };
# FIXME:	warn $@ unless ();
	return undef unless (@sigs or not defined ($@));
	my $str = "=over\n\n";
	foreach (@sigs) {
		$str .= '=item ';
		$str .= $_->{return_type}.' = '
			if exists $_->{return_type};
		$str .= $_->{signal_name}.' ('.$_->{itype}.', ';
		$str .= join ', ', @{$_->{param_types}};
		$str .= ', ' if scalar @{$_->{param_types}};
		$str .= "user_data)\n\n";
	}
	$str .= "=back\n\n";

	$str
}

sub podify_ancestors {
	my @anc;
	eval { @anc = Glib::Type->list_ancestors (shift); 1; };
# FIXME:	warn $@ unless ();
	return undef unless (@anc or not defined ($@));

	my $depth = 0;
	my $str = '  '.pop(@anc)."\n";
	foreach (reverse @anc) {
		$str .= "  " . "      "x$depth . "+----$_\n";
		$depth++;
	}
	$str .= "\n";

	$str
}

sub podify_interfaces {
	my @int;
	eval { @int = Glib::Type->list_interfaces (shift); 1; };
# FIXME:	warn $@ unless ();
	return undef unless (@int or not defined ($@));
	return '  '.join ("\n  ", @int)."\n\n";
}

sub convert_type {
	my $typestr = shift;

	$typestr =~ /^\s*					# leading space
	              (?:const\s+)?				# maybe a const
	              (\w+)					# the name
	              (\s*\*)?					# maybe a star
	              \s*$/x;					# trailing space
	my $ctype   = $1 || '!!';

	# variant type
	$ctype =~ s/(?:_(ornull|own|copy|own_ornull|noinc))$//;
	my $variant = $1 || "";

	my $perl_type;

#	if (exists $basic_types{$ctype}) {
#		$perl_type = $basic_types{$ctype};
#	} elsif (exists $packages_by_ctype{$ctype}) {
#		$perl_type = $packages_by_ctype{$ctype};
#	} else {
#		$perl_type = $ctype;
#	}
	if (exists $basic_types{$ctype})
	{
		$perl_type = $basic_types{$ctype};
	}
	else
	{
		eval
		{
			$perl_type = Glib::Type->package_from_cname ($ctype);
			1;
		};
		warn "$@" if ($@);
	}

	if ($variant && $variant =~ m/ornull/) {
		$perl_type .= " or undef";
	}

	#warn "typestr '$typestr'  ctype '$ctype'  variant '$variant'  perl_type '$perl_type'\n";

	$perl_type
}

sub podify_methods
{
	my $package = shift;
	my $xsubs = shift;
	return undef unless (scalar (@$xsubs));
	my $str = '';

	$str .= "=over\n\n";
	foreach (@$xsubs)
	{
		$str .= xsub_to_pod ($_);
	}
	$str .= "=back\n\n";

	$str;
}

sub xsub_to_pod {
	my $xsub = shift;
	my $alias = shift || $xsub->{symname};
	my $str;

	# ensure that if there's pod for this xsub, we have it now.
	# this should probably happen somewhere outside of this function,
	# but, eh...
	my @podlines = ();
	if (defined $xsub->{pod}) {
		@podlines = @{ $xsub->{pod}{lines} };
	} elsif ('ARRAY' eq ref $pods) {
		for (my $i = 0 ; $i < @$pods ; $i++) {
			if ($pods->[$i][0] =~ /^=for\s+apidoc\s+([:\w]+)\s*$/
			    and ($1 eq $alias))
			{
				$xsub->{pod} = $pods->[$i];
				@podlines = @{ $pods->[$i]{lines} };
				# don't look at him again.
				splice @$pods, $i, 1;
				last;
			}
		}
	}

	# look for annotations in the pod lines.
	# stuff in the pods overrides whatever we'd generate.
	my @signatures = ();
	if (@podlines) {
		# look for =signature lines in the pod; strip them if
		# found.  since we're modifying the list while traversing
		# it, go back to front.
		for (my $i = $#podlines ; $i >= 0 ; $i--) {
			if ($podlines[$i] =~ s/^=signature\s+//) {
				unshift @signatures, $podlines[$i];
				splice @podlines, $i, 1;
			} elsif ($podlines[$i] =~ /^=arg
			                           \s+
			                           (\$?[\w.]+)   # arg name
			                           (?:\s*\(([^)]*)\))? # type
			                           \s*
			                           (.*)$/x) { # desc
				#warn " =arg $1 $2 $3\n";
				$xsub->{args} = [] if not exists $xsub->{args};
				my ($a, undef) =
					grep { $_->{name} eq $1 }
				                  @{ $xsub->{args} };
				#warn Dumper($a);
				$a = {}, push @{$xsub->{args}}, $a
					if not defined $a;
				$a->{type} = $2 if $2;
				$a->{desc} = $3;
				splice @podlines, $i, 1;
				#warn Dumper($xsub->{args});
			}
		}
	}

	#
	# the call signature.
	#
	push @signatures, compile_signature ($alias, $xsub)
		unless @signatures;

	foreach (@signatures) {
		$str .= "=item $_\n\n";
	}

	#
	# list all the arg types.
	#
	my (undef, @args) = @{ $xsub->{args} };
	$str .= "=over\n\n";
	foreach my $a (@args) {
		#warn Dumper($a);
		if ($a->{name} eq '...') {
			$type = 'list';
		} else {
			if (not defined $a->{type}) {
				warn "$alias: no type defined for arg"
				   . " \$$a->{name}\n";
				$type = "(unknown)";
			} else {
				$type = convert_arg_type ($a->{type});
			}
		}
		$str .= "=item o "
		      . fixup_arg_name ($a->{name})
		      . " ($type) "
		      . ($a->{desc} ? $a->{desc} : "")
		      . "\n\n";
	}
	$str .= "=back\n\n";

	if (@podlines) {
		shift @lines;
		pop @lines;
		$str .= join("\n", @podlines)."\n\n";
	}

	$str
}

sub compile_signature {
	my ($method, $xsub) = @_;

	if (not defined $xsub->{args}) {
		warn Dumper($xsub);
	}
	my ($instance, @args) = @{ $xsub->{args} };

	# find the method's short name
	$method =~ s/^(.*):://;
	my $package = $1 || $xsub->{package};
	if (defined $instance->{type}) {
		$obj = lc $package;
		$obj =~ s/^(.*)::/\$/;
	} else {
		$obj = $package;
	}

	# compile the arg list string
	my $argstr = join ", ", map { fixup_arg_name ($_->{name}) } @args;

	# compile the return list string
	my @outlist = map { $_->{name} } @{ $xsub->{outlist} };
	if (defined $xsub->{return_type}) {
		my @retnames = map { convert_return_type_to_name ($_) }
				@{ $xsub->{return_type} };
		unshift @outlist, @retnames;
	}
	my $retstr = @outlist
	           ? (@outlist > 1
		      ? "(".join (", ", @outlist).")"
		      : $outlist[0]
		     )." = "
		   : (defined $xsub->{codetype} and
		      $xsub->{codetype} eq 'PPCODE'
		      ? 'list = '
		      : ''
		     );

	"$retstr$obj\->$method ".($argstr ? "($argstr)" : "");
}

sub fixup_arg_name {
	my $name = shift;
	my $sigil = $name eq '...' ? '' : '$';
	return $sigil.$name;
}

sub convert_arg_type { Glib::GenPod::convert_type (@_) }

sub convert_return_type_to_name {
	my $type = Glib::GenPod::convert_type (@_);
	if ($type =~ s/^.*:://) {
		$type = '$' . lc $type;
	}
	return $type;
}
1;

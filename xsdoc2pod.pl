#!/usr/bin/perl -w

use strict;
use Glib::GenPod;
use Gtk2;

my $datafile = shift @ARGV;
my $outdir   = shift @ARGV || 'pod.dir';

our ($xspods, $data);
require $datafile;

my $pkgdata;
my $ret;
foreach my $package (sort keys %$data)
{
	$pkgdata = $data->{$package};

	my $pod = "$outdir/$package.pod";
	open POD, ">$pod" or die "unabled to open ($pod) for output";
	select POD;

	print "=head1 NAME\n\n$package";
	print ' - '.$pkgdata->{blurb} if (exists ($pkgdata->{blurb}));
	print "\n\n";

	print "=head1 DESCRIPTION\n\n".$pkgdata->{desc}."\n\n"
		if (exists ($pkgdata->{desc}));

	$ret = podify_ancestors ($package);
	if ($ret)
	{
		print "=head1 HEIRARCHY\n\n$ret";
	}
	
	$ret = podify_interfaces ($package);
	if ($ret)
	{
		print "=head1 INTERFACES\n\n$ret";
	}

	$ret = podify_methods ($package, $data->{$package}{xsubs});
	if ($ret)
	{
		print "=head1 METHODS\n\n$ret";
	}
	
	$ret = podify_properties ($package);	
	if ($ret)
	{
		print "=head1 PROPERTIES\n\n$ret";
	}

	$ret = podify_signals ($package);	
	if ($ret)
	{
		print "=head1 SIGNALS\n\n$ret";
	}

	close POD;
}

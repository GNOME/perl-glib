package Glib::PkgConfig;

use Carp;

sub find {
	my $class = shift;
	my $pkg = shift;
	my %data = ();

	foreach my $what (qw/modversion cflags libs/) {
		$data{$what} = `pkg-config $pkg --$what`;
		chomp $data{$what};
		croak "*** can't find $what for $pkg\n"
		    . "*** is it properly installed and available in PKG_CONFIG_PATH?\n"
			unless $data{$what};
	}
	return %data;
}

1;

# Copyright (c) 2003 by the gtk2-perl team (see the file AUTHORS)
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the 
# Free Software Foundation, Inc., 59 Temple Place - Suite 330, 
# Boston, MA  02111-1307  USA.


package Glib::PkgConfig;

use Carp;

sub find {
	my $class = shift;
	my $pkg = shift;
	my %data = ();
	my @pkgs;

	# try as many pkg paramters are there are arguments left on stack
	while( $pkg and 
	       system "pkg-config $pkg --exists --silence-errors" )
	{
		push @pkgs, $pkg;
		$pkg = shift;
	}
	
	unless( $pkg )
	{
		if( @pkgs > 1 )
		{
			croak '*** can not find package for any of ('.join(', ',@pkgs).")\n"
			    . "*** check that one of them is properly installed and available in PKG_CONFIG_PATH\n";
		}
		else
		{
			croak "*** can not find package $pkgs[0]\n"
			    . "*** check that it is properly installed and available in PKG_CONFIG_PATH\n";
		}
	}
	else
	{
		print "found package $pkg, using it\n";
	}

	foreach my $what (qw/modversion cflags libs/) {
		$data{$what} = `pkg-config $pkg --$what`;
                $data{$what} =~ s/[\015\012]+$//;
		croak "*** can't find $what for $pkg\n"
		    . "*** is it properly installed and available in PKG_CONFIG_PATH?\n"
			unless $data{$what};
	}
	return %data;
}

1;

=head1 NAME

Glib::PkgConfig - simplistic interface to pkg-config

=head1 SYNOPSIS

 use Glib::PkgConfig;

 $package = 'gtk+-2.0';

 %pkg_info = Glib::PkgConfig->find ($package);
 print "modversion:  $pkg_info{modversion}\n";
 print "cflags:      $pkg_info{cflags}\n";
 print "libs:        $pkg_info{libs}\n";

=head1 DESCRIPTION

The pkg-config program retrieves information about installed libraries,
usually for the purposes of compiling against and linking to them.

Glib::PkgConfig is a very simplistic interface to this utility, intended
for use in the Makefile.PL of perl extensions which bind libraries that
pkg-config knows.  It is really just boilerplate code that you would've
written yourself.

=head2 USAGE

The module contains one function:

=over

=item HASH = Glib::PkgConfig->find (STRING, [STRING, ...])

Call pkg-config on the library specified by I<STRING> (you'll have to know what
to use here).  The returned I<HASH> contains the modversion, cflags, and libs
values under keys with those names. If multiple STRINGS are passed they are
attempted in the order they are given till a working package is found.

If pkg-config fails to find a working I<STRING>, this function croaks with a
message intended to be helpful to whomever is attempting to compile your
package.

For example:

  *** can not find package bad1                                   
  *** check that it is properly installed and available 
  *** in PKG_CONFIG_PATH 

or

  *** can't find cflags for gtk+-2.0
  *** is it properly installed and available in PKG_CONFIG_PATH?

=back

=head1 SEE ALSO

Glib::PkgConfig was designed to work with ExtUtils::Depends for compiling
the various modules of the gtk2-perl project.

  ExtUtils::Depends

  Glib

  http://gtk2-perl.sourceforge.net/

=head1 AUTHOR

muppet E<lt>scott at asofyet dot orgE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by muppet and the gtk2-perl team

This library is free software; you can redistribute it and/or modify
it under the terms of the Lesser General Public License (LGPL).  For 
more information, see http://www.fsf.org/licenses/lgpl.txt

=cut

#!env perl -w

use strict;
use warnings;

use Test::More
	tests => 20;

BEGIN { use_ok 'Glib'; }

package MyClass;

use Glib::Object::Subclass
   Glib::Object::,
   signals    =>
      {
          first => {
             flags       => [qw(run-first)],
             return_type => undef,
             param_types => [],
          },
          second => {
             flags       => [qw(run-first)],
             return_type => undef,
             param_types => [],
          },
      },
   ;

sub do_first  { print " # do_first\n"; }
sub do_second { print " # do_second\n"; }

sub first  { $_[0]->signal_emit ('first'); }
sub second { $_[0]->signal_emit ('second'); }

############
package main;

# keep stderr quiet, redirect it to stdout...
$SIG{__WARN__} = sub { print $_[0]; };

my $tag = Glib->install_exception_handler (sub {
		$_[0] =~ s/\n/\\n/g;
		ok (1, "trapped exception '$_[0]'");
		# this should be ignored, too, and should NOT create an
		# infinite loop.
		die "oh crap, another exception!\nthis one has multiple lines!\nappend something";
		1 });

ok( $tag, 'installed exception handler' );

ok( Glib->install_exception_handler (sub {
		if ($_[0] =~ /ouch/) {
			ok (1, 'saw ouch, uninstalling');
			return 0;
		} else {
			ok (0, 'additional handler still installed');
			return 1;
		}
		}),
    'installed an additional handler' );

{
   my $my = new MyClass;
   $my->signal_connect (first => sub { 
			ok (1, 'in first handler, calling second');
			$_[0]->second;
			ok (1, "handler may die, but we shouldn't");
		});
   $my->signal_connect (second => sub {
			ok (1, "in second handler, dying with 'ouch\\n'");
			die "ouch\n";
			ok (0, "should NEVER get here");
		});

   ok (1, 'calling second');
   $my->second;
   ok (1, "handler may die, but we shouldn't be affected");

   # expect identical behavior in eval context 
   eval {
   	ok (1, 'calling second in eval');
	$my->second;
	ok (1, "handler may die, but we shouldn't be affected");
   };
   is ($@, "", "exception should be cleared already");

   # super double gonzo...
   ok (1, "calling first");
   $my->first;
   ok (1, "after eval");
   print " # calling first out of eval, expect this to kill the program";
   $my->first;
}


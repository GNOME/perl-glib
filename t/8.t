#!env perl -w

use Test::More
	tests => 12,
	todo => 3;

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

ok(1);

$TODO = "exception handling is b0rken";

{
   my $my = new MyClass;
   $my->signal_connect (first => sub { 
			ok (1, 'in first handler, calling second');
			$_[0]->second;
			TODO: { ok (0, "shouldn't get here, either"); }
		});
   $my->signal_connect (second => sub {
			ok (1, "in second handler, dying with 'ouch\\n'");
			die "ouch\n";
			TODO: { ok (0, "should NEVER get here"); }
		});

   eval {
   	ok (1, 'calling second in eval');
	$my->second;
	TODO: { ok (0, "after second in eval --- shouldn't get here"); }
   };
   is ($@, "ouch\n", "should catch the exception from second out here");

   # super double gonzo...
   eval {
   	ok (1, "calling first in eval");
	$my->first;
	TODO: { ok (0, "after first in eval --- shouldn't get here"); }
   };
   ok (1, "after eval");
#   print " # calling first out of eval, expect this to kill the program";
#   $my->first;
}


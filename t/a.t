#!env perl -w

use strict;
use warnings;
use Test::More tests => 8;
use Glib;

use Data::Dumper;

package Foo;

use Glib::Object::Subclass
    'Glib::Object';

package main;

$SIG{__WARN__} = sub { ok(1, "in __WARN__: $_[0]"); };
#$SIG{__DIE__} = sub { ok(1, 'in __DIE__'); };

Glib->message (undef, 'whee message');
eval {
Glib->critical (undef, 'whee critical');
Glib->warning (undef, 'whee warning');
};

my $id = 
Glib::Log->set_handler (__PACKAGE__,
                        [qw/ error critical warning message info debug /],
			sub {
				ok(1, "in custom handler $_[1][0]");
			});

Glib->message (__PACKAGE__, 'whee message');
eval {
Glib->critical (__PACKAGE__, 'whee critical');
Glib->warning (__PACKAGE__, 'whee warning');

Glib::Log->remove_handler ($id);

Glib->warning (__PACKAGE__, 'whee warning');
};

# i would expect this to call croak, but it actually just aborts.  :-(
#eval { Glib->error (__PACKAGE__, 'error'); };



# when you try to connect to a non-existant signal, you get a CRITICAL
# log message...
my $object = Foo->new;
{
ok(1, 'attempting to connect a non-existant signal');
local $SIG{__WARN__} = sub { ok( $_[0] =~ /nonexistant/, 'should warn' ); };
$object->signal_connect (nonexistant => sub { ok(0, "shouldn't get here") });
delete $SIG{__WARN__};
}

## try that again with a fatal mask
#Glib::Log->set_always_fatal (['critical', 'fatal-mask']);
#{
#local $SIG{__DIE__} = sub { ok(1, 'should die'); };
#eval {
#$object->signal_connect (nonexistant => sub { ok(0, "shouldn't get here") });
#};
#print "$@\n";
#}

#!/usr/bin/perl -w

$header = shift @ARGV;
$footer = shift @ARGV;
@xsfiles = @ARGV;

die "usage: $0 header footer xsfiles...\n"
	unless @xsfiles;

$/ = undef;

open IN, $header or die "can't open $header: $!\n";
$text = <IN>;
close IN;
print $text;

system "podselect @xsfiles";

open IN, $footer or die "can't open $footer: $!\n";
$text = <IN>;
close IN;
print $text;

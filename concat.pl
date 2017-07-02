#!/usr/bin/perl
$all = `cat *.sol`;
$all =~ s/\r//g;
$all =~ s/\n//g;
$all =~ s/\t/ /g;
$all =~ s/( )+/ /g;

print $all;

#!/usr/bin/perl
$all = `cat *.sol`;
$processed =~ s/\r/\n/g;
@lines = split(/\n/, $all);
$processed = "";
foreach (@lines) {
  if ($_ =~/\\\\/) {
    print "Cannot process - found double slash comment\n";
    exit(1);
  }
  if (substr($_, 0, 7) ne "import ") {
    $processed .= $_;
  }
}
$processed =~ s/\r//g;
print $processed;

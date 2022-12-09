#!/usr/bin/env perl
$re = shift(@ARGV);
while (<>) {
    chomp;
    if (m/^$re$/) {
	print "$_\n";
    }
}

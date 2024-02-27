#!/usr/bin/env perl

/* bgrep (backtracking grep).

This code is provided to let you compare your agrep against Perl's
built-in regular expression engine.

In CP4, you will implement bgrep yourself, but because this
implementation uses built-in regular expressions, it would not be
acceptable as a solution for CP4. */

$re = shift(@ARGV);
while (<>) {
    chomp;
    if (m/^$re$/) {
	print "$_\n";
    }
}

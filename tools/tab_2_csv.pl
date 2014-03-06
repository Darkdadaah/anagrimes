#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Std;
my %opt = ();

#################################################
# Message about this program and how to use it
sub usage
{
        print STDERR "[ $_[0] ]\n" if $_[0];
        print STDERR << "EOF";

        This script converts a tabulated table in a csv table.

        usage: $0 [-h] < tab.txt > tab.csv

        -h        : this (help) message
EOF
        exit;
}

##################################
# Command line options processing
sub init()
{
        getopts('h', \%opt) or usage();
        usage() if $opt{h};
}

###################################
# MAIN
init();
my $n = 0;
while(my $line = <>) {
	chomp($line);
	my @vals = split(/\t/, $line);
	for (my $i=0; $i < @vals; $i++) {
		$vals[$i] =~ s/"/\"/;
	}
	print STDOUT '"' . join('", "', @vals) . "'" . "\n";
	$n++;
}
print STDERR "$n lines converted\n";

__END__

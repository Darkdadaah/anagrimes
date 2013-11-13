#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;

our %opt;	# Getopt options

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0];
	print STDERR << "EOF";
	
	This script formats a list in a wiki list or table.
	
	usage: $0 [-h] -f file
	
	-h        : this (help) message
	-L        : wiki list
	-N        : wiki numbered list
	-T        : wiki table
	
	-l        : linkify list element (or the first element in a table)
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hLNTl', \%opt ) or usage();
	usage() if $opt{h};
	usage("Format needed (-L|N|T)") unless $opt{L} xor $opt{N} xor $opt{T};
}

##################################
# Format subroutines
sub wiki_list
{
	my $start_char = shift;
	my $link = shift;
	
	while(my $line = <STDIN>) {
		chomp($line);
		my $text = $link ? "[[$line]]" : $line;
			
		print STDOUT "$start_char $text\n";
	}
}

sub wiki_table
{
	my $link = shift;
	while(my $line = <STDIN>) {
		chomp($line);
		my @elts = split(/\t/, $line);
		$elts[0] = ($elts[0] and $link) ? "[[$elts[0]]]" : $elts[0];
		print STDOUT "|-\n| " . join(' || ', @elts) . "\n";
	}
}

##################################
# MAIN
init();

if ($opt{L}) {
	wiki_list('*', $opt{l});
} elsif ($opt{N}) {
	wiki_list('#', $opt{l});
} elsif ($opt{T}) {
	wiki_table($opt{l});
} else {
	print STDERR "No format given\n";
}


__END__

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
	-t        : extract_table.pl db table (change from tabs to true csv)
	
	-l        : linkify list element (or the first element in a table)
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hLNTlt', \%opt ) or usage();
	usage() if $opt{h};
	usage("Format needed (-L|N|T|t)") unless $opt{L} xor $opt{N} xor $opt{T} xor $opt{t};
}

##################################
# Format subroutines
sub wiki_list
{
	my $start_char = shift;
	my $link = shift;
	
	while(my $line = <STDIN>) {
		chomp($line);
		my @elts = split(/\t/, $line);
		$elts[0] = "[[$elts[0]]]" if $elts[0] and $link;
		print STDOUT "$start_char " . join("\t", @elts) . "\n";
	}
}

sub wiki_table
{
	my $link = shift;
	while(my $line = <STDIN>) {
		chomp($line);
		my @elts = split(/\t/, $line);
		$elts[0] = "[[$elts[0]]]" if $elts[0] and $link;
		print STDOUT "|-\n| " . join(' || ', @elts) . "\n";
	}
}

sub db_table_csv
{
	while(my $line = <STDIN>) {
		chomp($line);
		my @elts = split(/\t/, $line);
		for (my $i = 0; $i < @elts; $i++) {
			# Number? No need for apostrophe
			if (not $elts[$i] =~ /^[0-9]+$/) {
				$elts[$i] = '"' . $elts[$i] . '"';
			}
		}
		print STDOUT join(',', @elts) . "\n";
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
} elsif ($opt{t}) {
	db_table_csv($opt{l});
} else {
	print STDERR "No format given\n";
}


__END__

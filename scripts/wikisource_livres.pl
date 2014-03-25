#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;

# Need utf8 compatibility for input/outputs
use utf8;
use open ':encoding(utf8)';
binmode STDOUT, ":encoding(utf8)";
binmode STDERR, ":encoding(utf8)";

# Useful Anagrimes libraries
use lib '..';
use wiktio::basic;
use wiktio::basic		qw(to_utf8);
use wiktio::string_tools	qw(ascii ascii_strict anagramme);
use wiktio::parser		qw(parse_dump);

our %opt;	# Getopt options

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0];
	print STDERR << "EOF";
	
	This script extracts books informations from a Wikisource dump (for the date).
	
	usage: $0 [-h] -f file
	
	-h        : this (help) message
	
	INPUT
	-i <path> : dump path
	
	OUTPUT
	-o <path> : books data output path
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hi:o:', \%opt ) or usage();
	%opt = %{ to_utf8(\%opt) };
	usage() if $opt{h};
	usage( "Dump path needed (-i)" ) if not $opt{i};
	usage( "Output path needed (-o)" ) if not $opt{o};
	
	if ($opt{o}) {
		open(ARTICLES, "> $opt{o}") or die "Couldn't write $opt{o}: $!\n";
		close(ARTICLES);
	}
}

##################################
# SUBROUTINES

# Parse a dump
sub get_books
{
	my ($par) = @_;
	my %p = %$par;
	
	my %counts = (
		'books' => 0,
	);
	
	open(my $dump_fh, dump_input($p{'dump_path'})) or die "Couldn't open '$p{'dump_path'}': $!\n";
	
	$|=1;
	ARTICLE : while(my $article = parse_dump($dump_fh)) {
		next ARTICLE if (not defined($article->{'fulltitle'}));
		next ARTICLE if (defined($article->{'redirect'}));
		
		if ($article->{'namespace'} eq 'Livre') {
			$counts{'books'}++;
			parse_book($article, $par);
		}
	}
	$|=0;
	print STDERR "\n";
	close($dump_fh);
		
	# Print stats
	print_counts(\%counts);
}

sub parse_book
{
	my ($article, $par) = @_;
	my %book = ();
	
	# Get date
	foreach my $line (@{ $article->{'content'} }) {
		if ($line =~ /^ *\| *([^=]+) *= *(.+) *$/) {
			my $field = $1;
			my $val = $2;
			$book{$field} = $val;
		}
	}
	if ($book{'Annee'}) {
		if ($book{'Annee'} =~ /(1[0-9]{3})/) {
			$book{'Annee'} = $1;
		} elsif ($book{'Annee'} =~ /(-?[0-9]{1,4})/) {
			print STDERR "Annee: $book{'Annee'}\n";
		}
	} else {
		print STDERR "No Annee: $article->{'title'}\n";
		$book{'Annee'} = '';
	}
	
	my $opath = $par->{'output_path'};
	open(BOOKS, ">>$opath") or die("Couldn't write $opath: $!");
	my @line = ($article->{'title'}, $book{'Annee'});
	print BOOKS join("\t", @line) . "\n";
	close(BOOKS);
}

# Print the stats
sub print_counts
{
	my $counts = shift;
	foreach my $c (sort keys %$counts) {
		print_value("$c: %d", $counts->{$c});
	}
}

###################
# MAIN
init();

# Prepare lists
my %par = ();
$par{'dump_path'} = $opt{i};
$par{'output_path'} = $opt{o};

# Get data from dump
get_books(\%par);

__END__

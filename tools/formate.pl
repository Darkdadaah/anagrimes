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
	
	usage: $0 [-h] < file
	
	-h        : this (help) message
	-L        : wiki list
	-N        : wiki numbered list
	-T        : wiki table
	-t        : extract_table.pl db table (change from tabs to true csv)
	
	-l        : linkify list element (or the first element in a table)
	-I <lang> : linkify + interlanguage link as *
	-F        : add formatnum: to any lone number in a tab other than the first one

	-C        : Add div with columns style
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hLNTlI:tCF', \%opt ) or usage();
	usage() if $opt{h};
	usage("Format needed (-L|N|T|t|C)") unless ($opt{L} xor $opt{N} xor $opt{T} xor $opt{t}) or $opt{C};
}

##################################
# Format subroutines
sub wiki_link
{
	my ($article, $link, $lang) = @_;
	return '' if not $article;
	if ($link) {
		if ($lang) {
			return "[[$article]] [[:$lang:$article|*]]";
		} else {
			return "[[$article]]";
		}
	} else {
		return $article;
	}
}

# Add formatnum to any number greater than 999
sub formatnum
{
	my @list = @_;
	
	for (my $i=0; $i < @list; $i++) {
		if ($list[$i] =~ /^\d{4,}$/) {
			$list[$i] = "{{formatnum:$list[$i]}}";
		}
	}
	return @list;
}

sub wiki_list
{
	my ($start_char, $link, $lang, $formatnum) = @_;
	
	while(my $line = <STDIN>) {
		chomp($line);
		my @elts = split(/\t/, $line);
		$elts[0] = wiki_link($elts[0], $link, $lang);
		@elts = formatnum(@elts) if $formatnum;
		print STDOUT "$start_char " . join("\t", @elts) . "\n";
	}
}

sub wiki_table
{
	my ($link, $lang, $formatnum) = @_;

	while(my $line = <STDIN>) {
		chomp($line);
		my @elts = split(/\t/, $line);
		$elts[0] = wiki_link($elts[0], $link, $lang);
		@elts = formatnum(@elts) if $formatnum;
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
print STDOUT '<div style="-webkit-column-width: 15em; -moz-column-width: 15em; column-width: 15em;">' . "\n" if $opt{C};
if ($opt{L}) {
	wiki_list('*', $opt{l}, $opt{I}, $opt{F});
} elsif ($opt{N}) {
	wiki_list('#', $opt{l}, $opt{I}, $opt{F});
} elsif ($opt{T}) {
	wiki_table($opt{l}, $opt{I}, $opt{F});
} elsif ($opt{t}) {
	db_table_csv();
} elsif ($opt{C}) {
	while(my $line = <STDIN>) {
		print STDOUT $line;
	}
} else {
	print STDERR "No format given\n";
}
print STDOUT "</div>\n\n" if $opt{C};


__END__


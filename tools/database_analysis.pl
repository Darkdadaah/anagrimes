#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;
use DBI;

our %opt;	# Getopt options

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0];
	print STDERR << "EOF";
	
	This script performs various analysis on an anagrimes database.
	
	-h        : this (help) message
	-d <path> : database path
	-p <str>  : analyse pronunciations for the given language
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hd:p:', \%opt ) or usage();
	usage() if $opt{h};
	usage("Database needed (-d)") unless $opt{d};
}

sub get_articles
{
	my ($dbh, $lang) = @_;
	
	my $query = "SELECT a_title, p_pron FROM defentries WHERE l_lang=? AND NOT p_pron IS NULL";
	return $dbh->selectall_arrayref($query, { Slice => {} }, $lang);
}

sub pronunciations
{
	my ($dbh, $lang) = @_;
	
	# Get all articles with pronunciations
	my $articles = get_articles($dbh, $lang);
	my $n = @$articles;
	print STDERR "$n articles with pronunciations in lang $lang\n";

	# Compute expected pronunciation based on the language
	my $diff = expected_pronunciation($articles, $lang);
	my $ndiff = @$diff;
	print STDERR "$ndiff articles found where pronunciation is different from expected\n";

	# List all words where the pronunciation is different from expected
}

sub expected_pronunciation
{
	my ($articles, $lang) = @_;
	
	my @diff = ();
	foreach my $a (@$articles) {
		push @diff, $a if not check_pronunciation($a, $lang);
	}
	return \@diff;
}

sub check_pronunciation
{
	my ($art, $lang) = @_;

	# Check French
	if ($lang eq 'fr') {
		my $pron = pron_in_fr($art->{'a_title'});
		print STDOUT "$art->{'a_title'}\t$pron\t$art->{p_pron}\n";
		
		if (different($art->{p_pron}, $pron)) {
			return 0;
		} else {
			return 1;
		}
		return 1;
	}
	return 1;
}

sub different
{
	my ($p1, $p2) = @_;
	return 0;
}

sub pron_in_fr
{
	my ($w) = @_;

	my $p = lc($w);
	$p =~ s/e\b//g;
	$p =~ s/er\b/e/g;
	$p =~ s/s?ch/S/g;
	$p =~ s/([aeouiy])s([aeiouy])/$1z$2/g;
	$p =~ s/j|ge/Z/g;
	$p =~ s/qu([ei])/k$1/g;
	$p =~ s/euill?e?/œj/g;
	$p =~ s/ueill?e?/œj/g;
	$p =~ s/eu/2/g;
	$p =~ s/ill/ij/g;
	$p =~ s/ou?in/wE~/g;
	$p =~ s/in([^aeiouéèy])/E~$1/g;
	$p =~ s/ou/U/g;
	$p =~ s/à|â/A/g;
	$p =~ s/e?au|ô/o/g;
	$p =~ s/ail/Aj/gi;
	$p =~ s/e?oi/wa/g;
	$p =~ s/ai/E/g;
	$p =~ s/u/Y/g;
	$p =~ s/é/e/g;
	$p =~ s/ê|è/E/g;

	$p =~ s/i([EAOY])/j$1/g;
	
	return $p;
}

##################################
# MAIN
init();

my $dbh = DBI->connect("dbi:SQLite:dbname=$opt{d}","","");
if ($opt{p}) {
	pronunciations($dbh, $opt{p});
}

__END__

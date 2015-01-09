#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;
use DBI;
use Encode;

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
	
	Type of analysis
	-p <str>  : analyse pronunciations for the given language
	-c <str>  : count letters for the given language
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hd:p:c:', \%opt ) or usage();
	usage() if $opt{h};
	usage("Database needed (-d)") unless $opt{d};
	usage("Type of analysis needed") if not $opt{p} xor $opt{c};
}

sub get_articles
{
	my ($dbh, $lang) = @_;
	
	my $query = "SELECT DISTINCT(a_title) FROM articles JOIN lexemes ON a_artid=l_artid WHERE l_lang=?";
	return $dbh->selectcol_arrayref($query, undef, $lang);
}

sub get_articles_prons
{
	my ($dbh, $lang) = @_;
	
	my $query = "SELECT a_title, p_pron FROM defentries WHERE l_lang=? AND NOT p_pron IS NULL";
	return $dbh->selectall_arrayref($query, { Slice => {} }, $lang);
}

sub pronunciations
{
	my ($dbh, $lang) = @_;
	
	# Get all articles with pronunciations
	my $articles = get_articles_pron($dbh, $lang);
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

sub count_letters
{
	my ($dbh, $lang) = @_;
	
	# Get all articles titles
	my $articles = get_articles($dbh, $lang);
	my $n = @$articles;
	print STDERR "$n articles in lang $lang\n";

	# Count every letter (diacritics included)
	my $letters = letters($articles, $lang);
	my $nletters = keys %$letters;
	print STDERR "$nletters different letters found\n";

	# List all letters counts
	print_letters($letters);
}

sub letters
{
	my ($articles) = @_;
	my %letters = ();
	
	foreach my $word (@$articles) {
		$word = decode('utf8', $word);
		my @chars = split(//, $word);
		foreach my $c (@chars) {
			$letters{$c}++;
		}
	}
	return \%letters;
}

sub print_letters
{
	my ($letters) = @_;
	
	foreach my $char (sort { $letters->{$b} <=> $letters->{$a} } keys %$letters) {
		print STDOUT encode('utf8', $char) . "\t$letters->{$char}\n";
	}
}

##################################
# MAIN
init();

my $dbh = DBI->connect("dbi:SQLite:dbname=$opt{d}","","");
if ($opt{p}) {
	pronunciations($dbh, $opt{p});
} elsif ($opt{c}) {
	count_letters($dbh, $opt{c});
}

__END__


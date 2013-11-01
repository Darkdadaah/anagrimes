#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;

# Need utf8 compatibility for input/outputs
use utf8;
use open ':encoding(utf8)';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use Encode qw(decode);	# Needed?

use lib '..';
use wiktio::basic;
our %opt;	# Getopt options

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0];
	print STDERR << "EOF";
	
	This script parses a Wiktionary dump and analyzes interwiki usage.
	
	usage: $0 [-h] -f file
	
	-h        : this (help) message
	
	INPUT
	-i <path> : dump path
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hi:', \%opt ) or usage();
	usage() if $opt{h};
	usage( "Dump path needed (-i)" ) if not $opt{i};
}

sub interwiki_analyze
{
	my ($title, $lines, $count) = @_;
	
	# Extract interwikis
	my %iw = ();
	foreach (@$lines) {
		if (/^ *\[\[(.{2,3}):(.+)\]\] *$/) {
			$iw{$1} = $2;
		}
	}
	
	# Analyze the data
	if (keys %iw > 0) {
		foreach my $l (sort keys %iw) {
			my $t = $iw{$l};
			
			if ($t ne $title) {
				print STDOUT "$l\t$title\t$t\n";
				
				# apostrophe?
				my $t2 = $t;
				my $title2 = $title;
				$t2 =~ s/['ʼ’]/'/g;
				$title2 =~ s/['ʼ’]/'/g;
				
				# Majuscule?
				my $t3 = uc($t2);
				my $title3 = uc($title2);
				
				# Apostrophe?
				if ($t2 eq $title2) {
					$count->{interwiki_wrong_apostrophe}++;
				} elsif ($t3 eq $title3) {
					$count->{interwiki_wrong_capital}++;
				} else {
					$count->{interwiki_wrong_other}++;
				}
				delete $iw{$l};
			}
		}
		$count->{interwiki_correct}++ if keys %iw > 0;
		
	} else {
		$count->{interwiki_none}++;
	}
}

###################
# MAIN
init();

open(DUMP, dump_input($opt{i})) or die "Couldn't open '$opt{i}': $!\n";
my $title = '';
my ($n, $redirect) = (0,0);
my $complete_article = 0;
my %already = ();
my @article = ();
my $count = {};

$|=1;
while(<DUMP>) {
	if ( /<title>(.+?)<\/title>/ ) {
		$title = $1;
		$title = '' if $title =~ /[:\/]/;
		
	} elsif ( $title and /<text xml:space="preserve">(.*?)<\/text>/ ) {
		@article = ();
		push @article, "$1\n";
		$complete_article = 1;
		
		} elsif ( $title and  /<text xml:space="preserve">(.*?)$/ ) {
		@article = ();
		push @article, "$1\n";
		while ( <DUMP> ) {
			next if /^\s+$/;
			if ( /^(.*?)<\/text>/ ) {
				push @article, "$1\n";
				last;
			} else {
				push @article, $_;
			}
		}
		$complete_article = 1;
	}
	if ($complete_article) {
		if ($article[0] =~ /#redirect/i) {
			$count->{redirect}++;
		} else {
			######################################
			# Traiter les articles ici
			interwiki_analyze($title, \@article, $count);
			######################################
			$count->{articles}++;
			print STDERR "[$count->{articles}] $title                                         \r" if $count->{articles}%1000==0;
		}
		$complete_article = 0;
	}
}
$|=0;
print STDERR "\n";
close(DUMP);

foreach my $c (sort keys %$count) {
	print STDERR "$c:\t$count->{$c}\n";
}

__END__

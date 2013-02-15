#!/usr/bin/perl -w

# Test the functions ascii etc.
use strict ;
use warnings ;
use Getopt::Std ;

use lib '..' ;
use wiktio::basic		qw(step stepl) ;
use wiktio::parser		qw(parseArticle) ;
our %opt ;

my $languages = {
	'en' => {
		'de' => 'Deutsch',
		'en' => 'English',
		'fr' => 'French',
		'it' => 'Italian',
	}
} ;

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0] ;
	print STDERR << "EOF";
	
	This script make a diff of the articles from one same language in 2 Wiktionaries
	
	usage: $0 [-h] -l lang -1 wikt1 -2 wikt2
	
	-h        : this (help) message
	
	-c <code> : language code (2 or 3 letters)
	
	-l <code> : first dump language code
	-L <code> : second dump language code
	
	-i <path> : dump path of the first Wiktionary
	-I <path> : dump path of the second Wiktionary
	
	-o <path> : output path of the pages found only in the first Wiktionary
	-O <path> : output path of the pages found only in the second Wiktionary
	
	example: $0 -c en -l fr -L en -i frwikt.xml -I enwikt.xml -o en_frwikt-only.txt -O en_enwikt_only.txt
EOF
	exit ;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hc:l:L:i:I:o:O:', \%opt ) or usage() ;
	usage() if $opt{h} ;
	
	usage( "Language to compare needed (-c)" ) if not $opt{c} ;
	
	usage( "First dump language needed (-l)" ) if not $opt{l} ;
	usage( "Second dump language needed (-L)" ) if not $opt{L} ;
	usage( "First dump path needed (-i)" ) if not $opt{i} ;
	usage( "Second dump path needed (-I)" ) if not $opt{I} ;
	usage( "First or second output file path needed (-o)" ) if not $opt{o} and not $opt{O} ;
}

sub recherche
{
	my ($wiktlang, $lang) = @_ ;
	my $recherche = '' ;
	
	if ($wiktlang eq 'fr') {
		$recherche = '\{\{langue\|'.$lang.'\}\}' ;
	} elsif ($wiktlang eq 'en') {
		$recherche = "^== *$languages->{$wiktlang}->{$lang} *==" ;
	} else {
		$recherche = '\{\{-'.$lang.'-\}\}' ;
	}
	stepl "(cherche '$recherche') " ;
	return $recherche ;
}

sub getWiktionaryList
{
	my ($file, $recherche) = @_ ;
	my $list = {} ;
	
	open(DUMP, $file) or die "Couldn't open '$file': $!\n" ;
	
	my $title = '' ;
	while(my $line = <DUMP>) {
		if ($line =~ /<title>(.+?)<\/title>/) {
			$title = $1 ;
			# Exclut toutes les pages en dehors de l'espace principal
			$title = '' if $title =~ /[:\/]/ ;
			
		} elsif ($title and $line =~ /<text xml:space="preserve">(.*?)$/) {
			my $head = $1 ;
			if ($head =~ /$recherche/) {
# 				step "A = $title\t($line)" ;
				$list->{$title} = 1 ;
				$title = '' ;
				next ;
			} else {
				if ($line =~ /<\/text>/) {
					$title='' ;
					next ;
				}
				while (my $inline = <DUMP>) {
					if ($inline =~ /$recherche/) {
# 						step "B = $title\t($inline)" ;
						$list->{$title} = 1 ;
						$title='' ;
					}
					if ($inline =~ /<\/text>/) {
						$title='' ;
						last ;
					}
				}
			}
		}
	}
	close(DUMP) ;
	
# 	map { step "$_" ; } sort keys %$list ;
	
	return $list ;
}

sub diff_lists
{
	my ($first, $second) = @_ ;
	my $first_only = {} ;
	my $second_only = {} ;
	my $common = {} ;
	
	foreach my $one (keys %$first) {
		if ($second->{$one}) {
			$common->{$one} = 1 ;
			delete $first->{$one} ;
			delete $second->{$one} ;
		} else {
			$first_only->{$one} = 1 ;
			delete $first->{$one} ;
		}
	}
	
	foreach my $two (keys %$second) {
		$second_only->{$two} = 1 ;
		delete $second->{$two} ;
	}
	
	return ($first_only, $second_only, $common) ;
}

sub write_list
{
	my ($list, $file, $lang) = @_ ;
	open(LISTE, ">$file") or die "Couldn't write $file: $!" ;
	print LISTE '<div style="-moz-column-count:4">'."\n" ;
	foreach my $article (sort keys %$list) {
		next if not $article ;
		print LISTE "# [[$article]] [[:$lang:$article|*]]\n" ;
	}
	print LISTE '</div>'."\n" ;
	close(LISTE) ;
}

###################
# MAIN
init() ;

# First Wiktionary
stepl "Parse $opt{l} Wiktionary: " ;
my $first = getWiktionaryList($opt{i}, recherche($opt{l}, $opt{c})) ;
my $num_first = keys %$first ;
step "$num_first articles in $opt{c}" ;

# Second Wiktionary
stepl "Parse $opt{L} Wiktionary: " ;
my $second = getWiktionaryList($opt{I}, recherche($opt{L}, $opt{c})) ;
my $num_second = keys %$second ;
step "$num_second articles in $opt{c}" ;

# Compare
step "Compare:" ;
my ($first_only, $second_only, $common) = diff_lists($first, $second) ;
my $num_first_only = keys %$first_only ;
my $num_second_only = keys %$second_only ;
my $num_common = keys %$common ;
step "$num_first_only articles only in $opt{l}" ;
step "$num_second_only articles only in $opt{L}" ;
step "$num_common articles in common" ;

# Write lists
if ($opt{o}) {
	step "Write the $num_first_only of the $opt{l} Wiktionary" ;
	write_list($first_only, $opt{o}, $opt{l}) ;
}
if ($opt{O}) {
	step "Write the $num_second_only of the $opt{L} Wiktionary" ;
	write_list($second_only, $opt{O}, $opt{L}) ;
}

__END__

#!/usr/bin/perl -w

use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use strict ;
use warnings ;
use Getopt::Std ;

use lib '..' ;
use wiktio::string_tools	qw(ascii_strict transcription anagramme unicode_NFKD) ;
use wiktio::parser			qw( parseArticle printArticle parseLanguage printLanguage parseType printType is_gentile) ;
use wiktio::pron_tools		qw(cherche_prononciation simple_prononciation section_prononciation) ;
our %opt ;

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0] ;
	print STDERR << "EOF";
	
	Ce script extrait les mots du Wiktionnaire utilisés dans celui-ci sans pour autant avoir d'article existant.
	
	usage: $0 -i fr-wikt_fr.xml -o fr-wikt_fr.xml [-L fr]
	
	-h        : this (help) message
	-i <path> : dump path
	-o <path> : output path
	-L <code> : language code to extract alone (2 or 3 letters)
	
EOF
	exit ;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hi:o:L:', \%opt ) or usage() ;
	usage() if $opt{h} ;
	
	usage( "Dump path needed (-i)" ) if not $opt{i} ;
	usage( "Output file path needed (-o)" ) if not $opt{o} ;
	$opt{o} .= '.txt' if not $opt{o} =~ /\.[a-z0-9]+$/ ;
}

sub ajout_redirect
{
}

sub ajout_mot
{
	open(MOTS, ">>$opt{o}") or die("Impossible d'écrire $opt{o} : $!\n") ;
# 	print "Ajoute mot $_[0]\n" ;
	print MOTS '"'.$_[0].'"' ;
	for (my $i=1; $i<@_; $i++) {
		print MOTS ',"'.$_[$i].'"' ;
	}
	print MOTS "\n" ;
	close(MOTS) ;
}

sub ajout_langue
{
	my ($titre, $section, $langue) = @_ ;
	
}

###################################
# REDIRECTS
sub redirect
{
}

###################################
# ARTICLE
sub article
{
	my ($titre, $article, $mots) = @_ ;
	
	foreach my $line (@$article) {
		$line =~ s/\{\{.+?\}\}//g ;
		$line =~ s/\[\[.+?:.+?\]\]//g ;
		$line =~ s/\[\[.+?\|(.+?)\]\]/$1/g ;
		$line =~ s/\[\[(.+?)\]\]/$1/g ;
		$line =~ s/'''(.+)'''/$1/g ;
		$line =~ s/''(.+)''/$1/g ;
		while ($line =~ /[#:\*\.!\?]\s+([A-Z\x{00C0}\x{00C7}\x{00C8}\x{00C9}])/) {
			my $premier = $1 ;
			my $basdecasse = lc($premier) ;
			$line =~ s/[#:\*\.!\?]\s+$premier/$basdecasse/ ;
		}
		$line =~ s/[#=\*:,\.;!\?\(\)\[\]0-9\r\n]//g ;
		my @mots_ligne = split(/\s+/, $line) ;
		next if @mots_ligne == 0 ;
		#print "$titre: ". join(' ; ', @mots_ligne). "\n" ;
		foreach my $mot (@mots_ligne) {
			next if ($mot eq '' or $mot =~ /^\s+$/) ;
			if ($mots->{$mot}) {
				$mots->{$mot}++ ;
			} else {
				$mots->{$mot} = 1 ;
			}
		}
	}
	#die ;
	return $mots ;
}

sub filtre
{
	my ($dico, $mots) = @_ ;
	
	foreach my $mot (@$dico) {
		delete $mots->{$mot} ;
	}
	return $mots ;
}

sub sauve_liste
{
	my ($mots, $fichier) = @_ ;
	
	open(LISTE, ">$fichier") or die("Impossible d'écrire dans $fichier: $!") ;
	foreach my $mot (sort { $mots->{$b} <=> $mots->{$a} } keys %$mots) {
		print LISTE "* [[$mot]] ($mots->{$mot})" ;
	}
	close(LISTE) ;
}

###################
# MAIN
init() ;

my $past = time() ;

# Initialize the file
open(DICO, ">$opt{o}") or die("Couldn't write $opt{o}: $!") ;
close(DICO) ;

# Read dump
open(DUMP, $opt{i}) or die "Couldn't open '$opt{i}': $!\n" ;
my $title = '' ;
my ($n, $redirect) = (0,0) ;
my $complete_article = 0 ;
my @article = () ;

my $mots = {} ;
my @dico = () ;

while(<DUMP>) {
	if ( /<title>(.+?)<\/title>/ ) {
		$title = $1 ;
		# Exclut toutes les pages en dehors de l'espace principal
		$title = '' if $title =~ /[:\/]/ ;
		
		# Enregistre ce mot
		if ($title) {
			push @dico, $title ;
		}
	
	} elsif ( $title and /<text xml:space="preserve">(.*?)<\/text>/ ) {
		@article = () ;
		push @article, "$1\n" ;
		$complete_article = 1 ;
		
		} elsif ( $title and  /<text xml:space="preserve">(.*?)$/ ) {
		@article = () ;
		push @article, "$1\n" ;
		while ( <DUMP> ) {
			next if /^\s+$/ ;
			if ( /^(.*?)<\/text>/ ) {
				push @article, "$1\n" ;
				last ;
			} else {
				push @article, $_ ;
			}
		}
		$complete_article = 1 ;
	}
	if ($complete_article) {
		if ($article[0] =~ /#redirect/i) {
			######################################
			# Traiter les redirects ici
			#redirect($title, \@article) ;
			######################################
			$redirect++ ;
		} else {
			######################################
			# Traiter les articles ici
			article($title, \@article, $mots) ;
			######################################
			$n++ ;
			print "[$n] $title\n" if $n%10000==0 ;
		}
		$complete_article = 0 ;
	}
}
close(DUMP) ;

print "Total = $n\n" ;
print "Total_redirects = $redirect\n" ;

my $num_dico = @dico ;
my $num_mots = keys(%$mots) ;
print "Articles dico: $num_dico" ;
print "Nombre de mots: $num_mots" ;

print "Filtre les mots existants dans le dico..." ;
filtre(\@dico, $mots) ;

my $num_mots_restants = keys(%$mots) ;
print "$num_mots_restants mots restants\n" ;

print "Sauve..." ;
sauve_liste($mots, $opt{o}) ;

my $diff = time() - $past;
my $mDiff = int($diff / 60);
my $sDiff = sprintf("%02d", $diff - 60 * $mDiff);
print "diff = $diff -> $mDiff\:$sDiff\n";

__END__


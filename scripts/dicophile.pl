#!/usr/bin/perl -w

use strict ;
use warnings ;
use Getopt::Std ;

use utf8 ;
use Encode qw(decode encode) ;
use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

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
	-I <path> : word list path
	-L <code> : language code to extract alone (2 or 3 letters)
	-H        : history file (special case, only use last version of each page)
	
	-P        : use non-mainspace pages
	
EOF
	exit ;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hi:I:o:L:PH', \%opt ) or usage() ;
	usage() if $opt{h} ;
	
	usage( "Dump path needed (-i)" ) if not $opt{i} ;
	usage( "Word list path needed (-I)" ) if not $opt{I} ;
	usage( "Output file path needed (-o)" ) if not $opt{o} ;
	$opt{o} .= '.txt' if not $opt{o} =~ /\.[a-z0-9]+$/ ;
}

sub get_dico
{
	my ($file) = @_ ;
	my %list = () ;
	
	open(DICO, $file) or die("$file: $!") ;
	while(<DICO>) {
		chomp ;
		$_ =~ s/\.$// ;
		my @sousmots = split(/[ '\x{2019}]/) ;
		foreach my $mot (@sousmots) {
			$list{$mot} = 1 ;
		}
	}
	close(DICO) ;
	return \%list ;
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
#~ sub article
#~ {
	#~ my ($titre, $article, $dico, $num_mots, $sql) = @_ ;
	#~ 
	#~ my $line = join(' ', @$article) ;
	#~ my $mots_article = {} ;
	#~ 
	#~ $line =~ s/([\s\|]).+?\s*=\s.+\}/$1\}/g ;
	#~ $line =~ s/\*\*? ?\{\{[^\}\{]+?\}\} ?:.+$/ /g ;
	#~ $line =~ s/\{\{[^\}\{]+?\}\}/ /g ;
	#~ $line =~ s/<[^<>]+?>/ /g ;
	#~ $line =~ s/\{\|.+?\|\}/ /g ;
	#~ $line =~ s/\[\[.+?:.+?\]\]/ /g ;
	#~ $line =~ s/\[\[.+?\|(.+?)\]\]/$1/g ;
	#~ $line =~ s/\[\[(.+?)\]\]/$1/g ;
	#~ $line =~ s/'''''([^']+?)'''''/$1/g ;
	#~ $line =~ s/''''([^']+?)''''/$1/g ;
	#~ $line =~ s/'''([^']+?)'''/$1/g ;
	#~ $line =~ s/''([^']+?)''/$1/g ;
	#~ $line =~ s/''//g ;
	#~ #$line =~ s/ ([tsdlmcnj ]|qu)['\x{2019}]/ /gi ;
	#~ $line =~ s/['\x{2019}]/ /gi ;
	#~ $line =~ s/['\x{2019}](\s|$)/ /g ;
	#~ $line =~ s/[«»]/ /g ;
	#~ $line =~ s/[#:*]/ /g ;
	#~ $line =~ s/[#\*:,\x{2026}\x{2014};!\?\(\)\[\]0-9\r\n]/ /g ;
	#~ $line =~ s/\. //g ;
	#~ $line =~ s/\s+/ /g ;
	#~ $line =~ s/^\s+$// ;
	#~ $line =~ s/^entr['\x{2019}]// ;
	#~ my @mots_ligne = split(/\s+/, $line) ;
	#~ return if @mots_ligne == 0 ;
	#~ #print "$titre: ". join(' ; ', @mots_ligne). "\n" ;
	#~ foreach my $mot (@mots_ligne) {
		#~ next if (
			#~ $mot eq ''
			#~ or $mot =~ /^\s+$/
			#~ or $mot eq '«'
			#~ or $mot eq '»'
			#~ or $mot eq '|'
			#~ or $mot =~ /margin-|background-color/
			#~ or $mot =~ /http|www|=|\./
			#~ or $mot =~ /[A-Z\x{00C0}\x{00C7}\x{00C8}\x{00C9}\x{00CE}\x{0152}\x{00D4}]/
			#~ or $mot =~ /^-/
			#~ or $mot =~ /-$/
			#~ or $mot =~ /&/
			#~ or $mot =~ /^.$/
			#~ or $mot =~ /[\[\]\{\}\|\\\/_]/
			#~ or $mot =~ /\x{2018}/
			#~ or $mot =~ /t-(il|elle|on|ils|elles)$|-(je|moi|lui|tu|nous|vous|leur|là|ci|ce|le|la|les|y)$/
		#~ ) ;
		#~ 
		#~ # Keep only if unknown
		#~ if (not $dico->{$mot}) {
			#~ if ($mots_article->{$mot}) {
				#~ $mots_article->{$mot}++ ;
			#~ } else {
				#~ $mots_article->{$mot} = 1 ;
			#~ }
		#~ }
	#~ }
	#~ 
	#~ # Save mots_article in the sqlfile
	#~ foreach my $m (keys %$mots_article) {
		#~ print $sql "$m\t$titre\t$mots_article->{$m}\n" ;
		#~ $num_mots++ ;
	#~ }
	#~ 
	#~ return $num_mots ;
#~ }

sub article
{
	my ($titre, $article, $dico, $sql) = @_ ;
	
	# Précorrection
	
	foreach my $line (@$article) {
		# Ligne de traduction ou prononciation
		$line =~ s/\*\*? ?\{\{[^\}\{]+?\}\} ?:.+$/ /g ;
	}
	
	my $line = join(' ', @$article) ;
	my $mots_article = {} ;
	my $num_mots = 0 ;
	
	# Nettoyage
	# Balises HTML
	
	$line =~ s/<[^<]+?>/ /g ;
	# Lien wiki
	$line =~ s/\[\[[^\[]+?\]\]\p{Ll}*/ /g ;
	# Lien externe
	$line =~ s/\[http.+?\]/ /g ;
	$line =~ s/http.+?\s/ /g ;
	# Modèle
	$line =~ s/\{\{[^\{]+?\}\}/ /g ;
	$line =~ s/\{\{[^\{]+?\}\}/ /g ;
	$line =~ s/\{\{[^\{]+?\}\}/ /g ;
	# Tables
	$line =~ s/\{\|.+?\|\}/ /g ;
	$line =~ s/\{\|.+?\|\}/ /g ;
	# Apostrophe, tirets quadratins
	$line =~ s/[\x{2019}\x{2013}]/ /g ;
	
	# Separation
	my @mots_ligne = split(/\s+/, $line) ;
	
	# Evaluation
	foreach my $mot (@mots_ligne) {
		if ($mot =~ /=/) {
			next ;
		}
		# Pas de majuscule
		next if $mot =~ /\p{Uppercase_letter}/ ;
		# Pas de nombre ni de signe de ponctuation ni de symbole ou d'autre truc bizarre
		next if $mot =~ /[\p{Number}\p{Other_Punctuation}\p{Symbol}\p{Other}]/ ;
		# Nettoyage
		$mot =~ s/[«»]//g ;
		$mot =~ s/\((.+?)\)/$1/g ;
		$mot =~ s/^[\.,;:!\?\)\(\{\}\[\]'“]+//g ;
		$mot =~  s/[\.,;:!\?\)\(\{\}\[\]'”]+$//g ;
		next if $mot =~ /_/ ;
		next if $mot =~ /^[\s\*#]*$/ ;
		next if $mot =~ /^\P{Letter}*$/ ;
		next if $mot =~ /^\p{Letter}$/ ;
		next if $mot =~ /-(je|tu|il|elle|on|nous|vous|ils|elles|moi|toi|lui|leur|là|ci|ce|le|la|les|y)?$/ ;
		
		# Keep only if unknown
		if (not $dico->{$mot}) {
			if ($mots_article->{$mot}) {
				$mots_article->{$mot}++ ;
			} else {
				$mots_article->{$mot} = 1 ;
			}
		}
	}
	
	# Save mots_article in the sqlfile
	foreach my $m (keys %$mots_article) {
		print $sql "$m\t$titre\t$mots_article->{$m}\n" ;
		$num_mots++ ;
	}
	
	return $num_mots ;
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
		print LISTE "* [[$mot]] ($mots->{$mot})\n" ;
	}
	close(LISTE) ;
}

###################
# MAIN
init() ;

my $past = time() ;

# Initialize the file
#open(DICO, ">$opt{o}") or die("Couldn't write $opt{o}: $!") ;
#close(DICO) ;

# Read dump
open(DUMP, $opt{i}) or die "Couldn't open '$opt{i}': $!\n" ;
my $title = '' ;
my $n = 0 ;
my $complete_article = 0 ;
my @article = () ;

my $num_mots = 0 ;
my $dico = get_dico($opt{I}) ;
my $sqlfile = $opt{o} ;
open(my $sql, ">$sqlfile") or die("$sqlfile: $!") ;

while(<DUMP>) {
	if ( /<title>(.+?)<\/title>/ ) {
		$title = $1 ;
		# Exclut toutes les pages en dehors de l'espace principal
		if ($opt{P}) {
			$title = '' unless $title =~ /[:\/]/ ;
		} else {
			$title = '' if $title =~ /[:\/]/ ;
		}
		
		# Si avec historique : vérifier s'il y a une version plus récente (=après)
		if ($opt{H}) {
			my $mark = tell(DUMP) ;
			my $found = 0 ;
			HISTORY : while(<DUMP>) {
				if ( /<title>(.+?)<\/title>/ ) {
					my $this_title = $1 ;
					# Nouvelle version !
					if ($this_title eq $title) {
						$mark = tell(DUMP) ;
					} else {
						# Autre article : on revient à la dernière version...
						seek(DUMP, $mark, 0) ;
						$found = 1 ;
						last HISTORY ;
					}
				}
			}
			# Rien trouvé : fin de fichier ?
			if (not $found) {
				seek(DUMP, $mark, 0) ;
			}
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
				chomp ;
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
			#$redirect++ ;
		} else {
			######################################
			# Traiter les articles ici
			my $mots_en_plus = article($title, \@article, $dico, $sql) ;
			$num_mots += $mots_en_plus if $mots_en_plus ;
			######################################
			$n++ ;
			print "[$n] $title\n" if $n%10000==0 ;
		}
		$complete_article = 0 ;
	}
}
close(DUMP) ;
close($sql) ;

print "Total = $n\n" ;

my $num_dico = keys %$dico ;
print "Articles dico: $num_dico\n" ;
print "Nombre de mots restants: $num_mots\n" ;

my $diff = time() - $past;
my $mDiff = int($diff / 60);
my $sDiff = sprintf("%02d", $diff - 60 * $mDiff);
print "diff = $diff -> $mDiff\:$sDiff\n";

__END__


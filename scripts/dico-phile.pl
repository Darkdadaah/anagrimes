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
	
	Ce script extrait les mots d'un dump Wikimedia utilisés qui sont absent d'une liste de mot donnée (issue du Wiktionnaire par exemple).
	
	usage: $0 -i fr-wikt_fr.xml -o fr-wikt_fr.xml [-L fr]
	
	-h        : aide
	-i <path> : chemin dump (entrée)
	-I <path> : chemin liste de mots (entrée)
	-o <path> : chemin fichier (sortie)
	-H        : history file (special case, only use last version of each page)
	
	-P        : Utiliser toutes les pages hors espace principal
	-p list,  : utiliser ces espaces de nommage
	-m        : Utiliser les pages de l'espace principal (en combinaison avec -P or -p)
	
EOF
	exit ;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hi:I:o:PHp:m', \%opt ) or usage() ;
	usage() if $opt{h} ;
	
	usage( "Chemin du dump (-i)" ) if not $opt{i} ;
	usage( "Chemin de la liste de mots (-I)" ) if not $opt{I} ;
	usage( "Chemin du fichier de sortie (-o)" ) if not $opt{o} ;
	$opt{o} .= '.txt' if not $opt{o} =~ /\.[a-z0-9]+$/ ;
	$opt{p} = '' if not $opt{p} ;
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
sub article
{
	my ($titre, $article, $dico, $sql) = @_ ;
	
	# Précorrection
	foreach my $line (@$article) {
		# Ligne de traduction ou prononciation
		$line =~ s/\*\*? ?\{\{[^\}\{]+?\}\} ?:.+$/ /g ;
	}
	
	# Wikisource qualité
# 	my $quality = 0 ;
# 	if ($article->[0] =~ /<pagequality level="([012345])"/) {
# 		$quality = $1 ;
# 	}
	
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
	$line =~ s/[\x{2018}\x{2019}\x{2013}\x{2014}]/ /g ;
	
	# Separation
	my @mots_ligne = split(/\s+/, $line) ;
	
	# Evaluation
	foreach my $mot (@mots_ligne) {
		# Pas de signe égal
		next if $mot =~ /=/ ;
		# Pas de majuscule
		next if $mot =~ /\p{Uppercase_letter}/ ;
		# Pas de nombre ni de signe de ponctuation ni de symbole ou d'autre truc bizarre
		next if $mot =~ /[\p{Number}\p{Other_Punctuation}\p{Symbol}\p{Other}]/ ;
		# Nettoyage
		$mot =~ s/[«»]//g ;
		$mot =~ s/\((.+?)\)/$1/g ;
		$mot =~ s/^[\.,;:!\?\)\(\{\}\[\]'“]+//g ;
		$mot =~  s/[\.,;:!\?\)\(\{\}\[\]'”]+$//g ;
		# Espace souligné = probable paramètre
		next if $mot =~ /_/ ;
		# Pas de suffixes/préfixes
		next if $mot =~ /^-|-$/ ;
		# Mot sans aucune lettre ou vide
		next if $mot =~ /^\P{Letter}*$/ ;
		# Une lettre unique
		next if $mot =~ /^\p{Letter}$/ ;
		# Terminaisons avec tiret en français
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
		my @cols = ($m, $titre, $mots_article->{$m}) ;
# 		push @cols, $quality ;
		my $cols = join("\t", @cols) ;
		print $sql "$cols\n" ;
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
my @namespaces = split(/\s*,\s*/, $opt{p}) ;
print STDERR "Allowed namespaces: ".join(", ", @namespaces)."\n" ;
open(my $sql, ">$sqlfile") or die("$sqlfile: $!") ;

while(<DUMP>) {
	if ( /<title>(.+?)<\/title>/ ) {
		$title = $1 ;
		
		# Other Namespace
		if ($title =~ /^([^:]+):/) {
			my $ns = $1 ;
			
			if (not ($opt{p} and $ns ~~ @namespaces) and not $opt{P}) {
				$title = '' ;
			}
		}
		
		# Main namespace
		elsif (($opt{P} or $opt{p}) and not $opt{m}) {
			$title = '' ;
		}
		
		# Si avec historique : vérifier s'il y a une version plus récente (=après)
		if ($opt{H}) {
			my $mark = tell(DUMP) ;
			HISTORY : while(<DUMP>) {
				if ( /<revision>/ ) {
					$mark = tell(DUMP) ;
				}
				# Woops, on est arrivé à la fin
				elsif (/<\/page>/) {
					last HISTORY ;
				}
			}
			# Retour au début de la dernière version
			seek(DUMP, $mark, 0) ;
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


#!/usr/bin/perl -w

use strict ;
use warnings ;
use Getopt::Std ;

use lib '..' ;
use wiktio::string_tools	qw(ascii ascii_strict anagramme) ;
use wiktio::parser			qw( parseArticle printArticle parseLanguage printLanguage parseType printType is_gentile) ;
use wiktio::pron_tools		qw(cherche_prononciation simple_prononciation section_prononciation) ;
our %opt ;
my $redirects = '' ;
my $articles = '' ;
my $mots = '' ;

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0] ;
	print STDERR << "EOF";
	
	Ce script extrait des articles du Wiktionnaire et créé des tables.
	
	usage: $0 -i fr-wikt.xml -o fr-wikt_table [-L fr]
	
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
	getopts( 'i:o:L:', \%opt ) or usage() ;
	usage() if $opt{h} ;
	
	usage( "Dump path needed (-i)" ) if not $opt{i} ;
	usage( "Output file path needed (-o)" ) if not $opt{o} ;
	$opt{o} .= '.csv' if not $opt{o} =~ /\.[a-z0-9]+$/ ;
	
	$redirects = $opt{o} ;
	$redirects =~ s/^(.+?)(\.[a-z0-9]+)$/$1_redirects$2/ ;
	
	$articles = $opt{o} ;
	$articles =~ s/^(.+?)(\.[a-z0-9]+)$/$1_articles$2/ ;
	
	$mots = $opt{o} ;
	$mots =~ s/^(.+?)(\.[a-z0-9]+)$/$1_mots$2/ ;
	
	 # Init redirect
	open(REDIRECTS, "> $redirects") or die "Couldn't write $redirects: $!\n" ;
	print REDIRECTS '"titre","cible"'."\n" ;
	close(REDIRECTS) ;
	
	 # Init articles
	open(ARTICLES, "> $articles") or die "Couldn't write $articles: $!\n" ;
	print ARTICLES '"titre","r_titre","titre_ascii","r_titre_ascii","anagramme_id"'."\n" ;
	close(ARTICLES) ;
	
	 # Init mots
	open(MOTS, "> $mots") or die "Couldn't write $mots: $!\n" ;
	print MOTS '"titre","langue","type","pron","pron_simple","r_pron_simple","num","flex","loc","gent"' . "\n" ;
	close(MOTS) ;
}

sub ajout_redirect
{
	open(REDIRECTS, ">> $redirects") or die "Impossible d'écrire $redirects: $!\n" ;
	print REDIRECTS '"'.$_[0].'"' ;
	for (my $i=1; $i<@_; $i++) {
		print REDIRECTS ',"'.$_[$i].'"' ;
	}
	print REDIRECTS "\n" ;
	close(REDIRECTS) ;
}

sub ajout_article
{
	open(ARTICLES, ">> $articles") or die "Impossible d'écrire $articles : $!\n" ;
	print ARTICLES '"'.$_[0].'"' ;
	for (my $i=1; $i<@_; $i++) {
		print ARTICLES ',"'.$_[$i].'"' ;
	}
	print ARTICLES "\n" ;
	close(ARTICLES) ;
}

sub ajout_mot
{
	open(MOTS, ">> $mots") or die "Impossible d'écrire $mots : $!\n" ;
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
	
	###############################################
	# Travail sur la section de langue
	my $lang_section = parseLanguage($section, $titre) ;
	
	# Section prononciation?
	my @prononciations = section_prononciation($lang_section->{'prononciation'}, $titre) ;
	
	my @sections = keys %{$lang_section} ;
	my @types = keys %{$lang_section->{'type'}} ;
	foreach my $type (@types) {
		next if $type eq 'erreur' ;
		my %type_pron = () ;
		my $gent = 0 ;
		foreach my $line (@{$lang_section->{'type'}->{$type}}) {
			my @pron = cherche_prononciation($line, $opt{'L'}, $titre) ;
			
			foreach my $p (@pron) {
				$type_pron{$p} = 1 ;
			}
		}
		
		# gentile?
		if ($type eq 'nom' or $type eq 'adj' or $type eq 'loc-nom' or $type eq 'loc-adj') {
			$gent = is_gentile($lang_section->{'type'}->{$type}) ;
# 			print "[[$titre]]\tgentilé (?)\n" if $gent ;
		}
		
		# Prononciations dispos?
		my @pron = () ;
		if (keys %type_pron == 0) {
			push @pron, @prononciations ;
		} else {
			@pron = keys(%type_pron) ;
		}
		
		# Si prononciations
		my $type_nom = $type ;
		my $num = 1 ;
		my ($flex,$loc) = (0,0) ;
		
		# Nombre?
		if ($type =~ /^(.+)-([0-9])$/) {
			$type_nom = $1 ;
			$num = $2 ;
		}
		# Flexion?
		if ($type_nom =~ /^flex-(.+)$/) {
			$type_nom = $1 ;
			$flex = 1 ;
		}
		# Locution?
		if ($type_nom =~ /^loc-(.+)$/) {
			$type_nom = $1 ;
			$loc = 1 ;
		}
		
		if (@pron) {
			# Ajoute autant de ligne qu'il y a de prononciation
			foreach my $p (@pron) {
				my $p_simple = simple_prononciation($p) ;
				my $r_p_simple = reverse($p_simple) ;
				ajout_mot($titre, $langue, $type_nom, $p, $p_simple, $r_p_simple, $num, $flex, $loc, $gent) ;
			}
		} else {
			my $p = '' ;
			my $p_simple = '' ;
			my $r_p_simple = '' ;
			my $num = 1 ;
			ajout_mot($titre, $langue, $type_nom, $p, $p_simple, $r_p_simple, $num, $flex, $loc, $gent) ;
		}
	}
}

###################################
# REDIRECTS
sub redirect
{
	my ($titre, $article) = @_ ;
	
	my $cible = '' ;
	my $special = '' ;
	
	if      ($article->[0] =~ /\# *REDIRECT *:? *\[\[(.+?)\]\]/i) {
		$cible = $1 ;
		$special = 'normal' ;
	} elsif ($article->[0] =~ /\# *REDIRECT *:? *\[\[(.+?)\]\]/i) {
		$cible = $1 ;
		$special = 'special' ;
	} else {
		print STDERR "[[$titre]] Pas trouvé de redirect ($special) : " ;
		map { chomp; STDERR print "'$_'\n" ; } @$article ;
	}
	
	ajout_redirect($titre, $cible) ;
}

###################################
# ARTICLE
sub article
{
	my ($titre, $article) = @_ ;
	my %mot = () ;
	$mot{'titre'} = $titre ;
	
	###########################
	# Travail sur le titre
	$mot{'anagramme_id'} = anagramme($titre) ;
	$mot{'titre_ascii'} = lc(ascii_strict($titre)) ;
	if ($mot{'titre_ascii'}) {
		my $r_titre = reverse($titre) ;
		my $r_titre_ascii = reverse($mot{'titre_ascii'}) ;
		ajout_article($titre, $r_titre, $mot{'titre_ascii'}, $r_titre_ascii, $mot{'anagramme_id'}) ;
		##########################
		# Sections
		my $article_section = parseArticle($article, $titre) ;
		
		if ($opt{L}) {
			my $langue = $opt{L} ;
			my $langue_section = $article_section->{language}->{$langue} ;
			if ($#{$langue_section}+1 > 0) {
				ajout_langue($titre, $langue_section, $langue) ;
			}
		} else {
			foreach my $langue (keys %{$article_section->{language}}) {
				my $langue_section = $article_section->{language}->{$langue} ;
				next if not $langue_section ;
				ajout_langue($titre, $langue_section, $langue) ;
			}
		}
	}
}

###################
# MAIN
init() ;

# Connect
open(DUMP, $opt{i}) or die "Couldn't open '$opt{i}': $!\n" ;
my $title = '' ;
my ($n, $redirect) = (0,0) ;
my $complete_article = 0 ;
my @article = () ;

while(<DUMP>) {
	if ( /<title>(.+?)<\/title>/ ) {
		$title = $1 ;
		# Exclut toutes les pages en dehors de l'espace principal
		$title = '' if $title =~ /[:\/]/ ;
	
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
			redirect($title, \@article) ;
			######################################
			$redirect++ ;
		} else {
			######################################
			# Traiter les articles ici
			article($title, \@article) ;
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

__END__

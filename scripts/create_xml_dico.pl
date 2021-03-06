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
use wiktio::string_tools	qw(ascii_strict transcription anagramme unicode_NFKD);
use wiktio::parser			qw( parseArticle printArticle parseLanguage printLanguage parseType printType is_gentile);
use wiktio::pron_tools		qw(cherche_prononciation simple_prononciation section_prononciation);
our %opt;
my $redirects = '';
my $articles = '';
my $transcrits = '';
my $mots = '';
my $langues = '';

my %langues_total = ();
my %langues_filtre = ();

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0];
	print STDERR << "EOF";
	
	Ce script extrait des articles du Wiktionnaire et créé un dico simple de type xml (INCOMPLET).
	
	usage: $0 -i fr-wikt_fr.xml -o fr-wikt_fr.xml [-L fr]
	
	-h        : this (help) message
	-i <path> : dump path
	-o <path> : output path
	-L <code> : language code to extract alone (2 or 3 letters)
	
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hi:o:L:', \%opt ) or usage();
	%opt = %{ to_utf8(\%opt) };
	usage() if $opt{h};
	
	usage( "Dump path needed (-i)" ) if not $opt{i};
	usage( "Output file path needed (-o)" ) if not $opt{o};
	$opt{o} .= '.xml' if not $opt{o} =~ /\.[a-z0-9]+$/;
}

sub ajout_redirect
{
	open(MOTS, ">>$opt{o}") or die("Impossible d'écrire $opt{o} : $!\n");
	my ($titre, $cible) = @_;
# 	print "Ajoute mot $_[0]\n";

	print MOTS "<mot>\n";
	print MOTS "\t<titre>$titre</titre>\n";
	print MOTS "\t<redirection>$cible</redirection>\n";
	print MOTS "</mot>\n";
	close(MOTS);
}

sub ajout_mot
{
	open(MOTS, ">>$opt{o}") or die("Impossible d'écrire $opt{o} : $!\n");
# 	print "Ajoute mot $_[0]\n";
	print MOTS '"'.$_[0].'"';
	for (my $i=1; $i<@_; $i++) {
		print MOTS ',"'.$_[$i].'"';
	}
	print MOTS "\n";
	close(MOTS);
}

sub ajout_langue
{
	my ($titre, $section, $langue) = @_;
	
	###############################################
	# Travail sur la section de langue
	my $lang_section = parseLanguage($section, $titre);
	
	# Section prononciation?
	my @prononciations = section_prononciation($lang_section->{'prononciation'}, $titre);
	
	my @sections = keys %{$lang_section};
	my @types = keys %{$lang_section->{'type'}};
	foreach my $type (@types) {
		next if $type eq 'erreur';
		my %type_pron = ();
		my $gent = 0;
		
		my $prons = cherche_prononciation($lang_section->{'type'}->{$type}, $langue, $titre);
		
		foreach my $p (@$prons) {
			$type_pron{$p} = 1;
		}
		
		# Prononciations dispos?
		my @pron = ();
		if (keys %type_pron == 0) {
			push @pron, @prononciations;
		} else {
			@pron = keys(%type_pron);
		}
		
		# Si prononciations
		my $type_nom = $type;
		my $num = 0;
		my ($flex,$loc) = (0,0);
		
		# Nombre?
		if ($type =~ /^(.+)-([0-9])$/) {
			$type_nom = $1;
			$num = $2;
		}
		# Flexion?
		if ($type_nom =~ /^flex-(.+)$/) {
			$type_nom = $1;
			$flex = 1;
		}
		# Locution?
		if ($type_nom =~ /^loc-(.+)$/) {
			$type_nom = $1;
			$loc = 1;
		}
		
		# gentile?
		if ($type_nom eq 'nom' or $type_nom eq 'adj' or $type_nom eq 'loc-nom' or $type_nom eq 'loc-adj') {
			$gent = is_gentile($lang_section->{'type'}->{$type});
# 			print "[[$titre]]\tgentilé (?)\n" if $gent;
		}
		
		if (@pron) {
			# Ajoute autant de ligne qu'il y a de prononciation
			foreach my $p (@pron) {
				my $p_simple = simple_prononciation($p);
				my $r_p_simple = reverse($p_simple);
				# Nombre de langue
				if ($langues_total{$langue}) { $langues_total{$langue}++; }
				else { $langues_total{$langue} = 1; }
				
				# Nombre dans la langue (filtré)
				my $rand = 0;
				if (not $gent and not $flex and $type ne 'nom-pr' and not $titre =~ /[0-9]/) {
					if ($langues_filtre{$langue}) { $langues_filtre{$langue}++; }
					else { $langues_filtre{$langue} = 1; }
					$rand = $langues_filtre{$langue};
				}
				ajout_mot($titre, $langue, $type_nom, $p, $p_simple, $r_p_simple, $num, $flex, $loc, $gent, $rand);
			}
		} else {
			my $p = '';
			my $p_simple = '';
			my $r_p_simple = '';
			my $num = 1;
			# Nombre dans la langue
			if ($langues_total{$langue}) { $langues_total{$langue}++; }
			else { $langues_total{$langue} = 1; }
			
			# Nombre dans la langue (filtré)
			my $rand = 0;
			if (not $gent and not $flex and $type ne 'nom-pr' and not $titre =~ /[0-9]/) {
				if ($langues_filtre{$langue}) { $langues_filtre{$langue}++; }
				else { $langues_filtre{$langue} = 1; }
				$rand = $langues_filtre{$langue};
			}
			ajout_mot($titre, $langue, $type_nom, $p, $p_simple, $r_p_simple, $num, $flex, $loc, $gent, $rand);
		}
	}
}

###################################
# REDIRECTS
sub redirect
{
	my ($titre, $article) = @_;
	
	my $cible = '';
	
	if ($article->[0] =~ /\# *REDIRECT[^\[]*\[\[(.+?)\]\]/i) {
		$cible = $1;
# 	elsif      ($article->[0] =~ /\# *REDIRECT(ION)? *:? *\[\[(.+?)\]\]/i) {
# 		$cible = $2;
# 	} elsif ($article->[0] =~ /\# *REDIRECT(ION)? *:? *\[\[(.+?)\]\]/i) {
# 		$cible = $2;
	} else {
		print STDERR "[[$titre]] Pas trouvé de redirect : ";
		map { chomp; print STDERR "'$_'\n"; } @$article;
	}
	
	ajout_redirect($titre, $cible);
}

###################################
# ARTICLE
sub article
{
	my ($titre, $article) = @_;
	my %mot = ();
	
	# Ni préfixe ni suffixe, ni accent
	return if $titre =~ /^-/ or $titre =~ /-$/ or $titre =~ /ـ/;
	$mot{'titre'} = $titre;
	
	###########################
	# Travail sur le titre
	$mot{'titre_plat'} = lc(ascii_strict($titre));
	$mot{'anagramme_id'} = anagramme($titre);
# 	delete $mot{'anagramme_id'} if length($mot{'anagramme_id'})==1;
	
	if ($mot{'titre_plat'}) {
		##########################
		# Sections
		my $article_section = parseArticle($article, $titre);
		
		if ($opt{L}) {
			my $langue = $opt{L};
			my $langue_section = $article_section->{language}->{$langue};
			if ($#{$langue_section}+1 > 0) {
				ajout_langue($titre, $langue_section, $langue);
			}
		} else {
			foreach my $langue (keys %{$article_section->{language}}) {
				my $langue_section = $article_section->{language}->{$langue};
				next if not $langue_section;
				ajout_langue($titre, $langue_section, $langue);
			}
		}
		
		##########################
		# Graphie
		$mot{'r_titre'} = reverse($titre);
		$mot{'r_titre_plat'} = reverse($mot{'titre_plat'});
		$mot{'transcrit_plat'} = '';
		$mot{'r_transcrit_plat'} = '';
		
		# Alphabet latin ?
		if (not unicode_NFKD($mot{'titre_plat'}) =~ /[a-z]/) {
			my @langues = keys %{$article_section->{language}};
			$mot{'transcrit_plat'} = transcription($mot{'titre_plat'}, \@langues);
			
			if (not $mot{'transcrit_plat'}) {
				return;
			} elsif (not unicode_NFKD($mot{'transcrit_plat'}) =~ /^[a-z ]+$/) {
				special_log('transcription', $titre, $mot{'transcrit_plat'});
				return;
			} else {
				$mot{'r_transcrit_plat'} = reverse($mot{'transcrit_plat'});
			}
		}
		ajout_article($titre, $mot{'r_titre'}, $mot{'titre_plat'}, $mot{'r_titre_plat'}, $mot{'transcrit_plat'}, $mot{'r_transcrit_plat'}, $mot{'anagramme_id'});
	}
}

###################
# MAIN
init();

my $past = time();

# Initialize the xml file
open(DICO, ">$opt{o}") or die("Couldn't write $opt{o}: $!");
print DICO "<wiktiodico>\n";
close(DICO);

# Read dump
open(DUMP, dump_input($opt{i})) or die "Couldn't open '$opt{i}': $!\n";
my $title = '';
my ($n, $redirect) = (0,0);
my $complete_article = 0;
my @article = ();

while(<DUMP>) {
	if ( /<title>(.+?)<\/title>/ ) {
		$title = $1;
		# Exclut toutes les pages en dehors de l'espace principal
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
			######################################
			# Traiter les redirects ici
			redirect($title, \@article);
			######################################
			$redirect++;
		} else {
			######################################
			# Traiter les articles ici
			#article($title, \@article);
			######################################
			$n++;
			print "[$n] $title\n" if $n%10000==0;
		}
		$complete_article = 0;
	}
}
close(DUMP);

# Close the xml file
open(DICO, ">>$opt{o}") or die("Couldn't write $opt{o}: $!");
print DICO "</wiktiodico>\n";
close(DICO);

print "Total = $n\n";
print "Total_redirects = $redirect\n";

my $diff = time() - $past;
my $mDiff = int($diff / 60);
my $sDiff = sprintf("%02d", $diff - 60 * $mDiff);
print "diff = $diff -> $mDiff\:$sDiff\n";

__END__


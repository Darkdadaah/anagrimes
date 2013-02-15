#!/usr/bin/perl -w

use strict ;
use warnings ;
use Getopt::Std ;

# Need utf8 compatibility for input/outputs
use utf8 ;
use open ':encoding(utf8)';
binmode STDOUT, ":encoding(utf8)";
binmode STDERR, ":encoding(utf8)";

# Useful Anagrimes libraries
use lib '..' ;
use wiktio::basic ;
use wiktio::string_tools	qw(ascii_strict transcription anagramme unicode_NFKD) ;
use wiktio::parser			qw( parseArticle printArticle parseLanguage printLanguage parseType printType is_gentile) ;
use wiktio::pron_tools		qw(cherche_prononciation cherche_transcription simple_prononciation extrait_rimes section_prononciation nombre_de_syllabes) ;

# Output files:
my %output_files = (
'redirects' => '',
'articles' => '',
'transcrits' => '',
'mots' => '',
'langues' => '',
);

my %langues_total = ();
my %langues_filtre = ();

our %opt ;	# Getopt options

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0] ;
	print STDERR << "EOF";
	
	This script extract data from a Wiktionary dump and create tables that can be imported in an SQL database.
	Right now the only version supported is the French Wiktionary (Wiktionnaire).
	
	usage: $0 -i fr-wikt.xml -o fr-wikt_table [-L fr]
	
	-h        : this (help) message
	-i <path> : input dump path (compressed or not)
	-o <path> : output path (this needs to be a path + prefix of the file names that will be created: path/filename)
	
	-L <code> : language code to extract alone (2 or 3 letters) [optional]
	-l <path> : special log_files (like -o path + prefix). Those files log specific errors defined in the parser.
EOF
	exit ;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'i:o:L:l:', \%opt ) or usage();
	usage() if $opt{h};
	
	$log = $opt{l} if $opt{l};
	
	usage( "Dump path needed (-i)" ) if not $opt{i};
	usage( "Output file path needed (-o)" ) if not $opt{o};
	
	# Prepare output file path
	$opt{o} .= '.csv' if not $opt{o} =~ /\.[a-z0-9]+$/;
	print STDERR "Files in $opt{o}\n";
	
	# Prepare output files
	foreach my $type (keys %output_files) {
		# Name of the file for this type
		$output_files{$type} = $opt{o};
		$output_files{$type} =~ s/^(.+?)(\.[a-z0-9]+)$/$1_$type$2/;
		
		# Init the file
		open(TYPE, "> $output_files{$type}") or die "Impossible d'initier $output_files{$type}: $!\n";
		close(TYPE);
	}
	
	# Print columns order so that the user know what is written where (should not be hard coded like that...)
	print STDERR 'REDIRECTS: titre, cible'."\n";
	print STDERR 'ARTICLES: titre, r_titre, titre_plat, r_titre_plat, transcrit_plat, r_transcrit_plat, anagramme_id'."\n";
	print STDERR 'TRANSCRITS: titre, transcrit, transcrit_plat, r_transcrit_plat'."\n";
	print STDERR 'MOTS: titre, langue, type, pron, pron_simple, r_pron_simple, rime_pauvre, rime_suffisante, rime_riche, rime_voyelle, num, flex, loc, gent, rand' . "\n";
	print STDERR 'LANGUES: langue, num, num_min'."\n";
}

# Write to the various output files
sub add_to_file
{
	my ($type, $line) = @_;
	
	open(TYPE, ">> $output_files{$type}") or die "Impossible d'écrire $output_files{$type} (type $type): $!\n";
	print TYPE '"' . join( '","' , @$line) . "\"\n";	# Print line in csv style: "A","B","C"\n
	close(TYPE);
}

sub add_to_file_langues
{
	my ($line) = @_;
	open(LANG, "> $output_files{langues}") or die "Can't write $output_files{langues}: $!\n";
	foreach my $l (sort keys(%langues_total)) {
		my $filtre = $langues_filtre{$l} ? $langues_filtre{$l} : 0 ;
		my @lang_line = ($l, $langues_total{$l}, $filtre);
		print LANG '"' . join( '","' , @lang_line) . "\"\n";	# Print line in csv style: "A","B","C"\n
	}
	close(LANG);
}

sub chronometer_end
{
	my ($past) = @_;
	my $diff = time() - $past;
	my $mDiff = int($diff / 60);
	my $sDiff = sprintf("%02d", $diff - 60 * $mDiff);
	
	print STDERR "diff = $diff -> $mDiff\:$sDiff\n";
}

sub ajout_langue
{
	my ($titre, $section, $langue) = @_ ;
	
	###############################################
	# Travail sur la section de langue
	# Extrait les sections de niveau 3 : étymo, types, pron...
	my $lang_section = parseLanguage($section, $titre, $langue) ;
	
	# Section prononciation?
	my @prononciations = section_prononciation($lang_section->{'prononciation'}->{lines}, $titre) ;
	my %transc = ();
	
	# Analyse de chaque section de type
	my @sections = keys %{$lang_section} ;
	my @types = keys %{$lang_section->{'type'}} ;
	foreach my $type (@types) {
		next if $type eq 'erreur' ;	# Pas prendre en compte les type erreurs
		my $gent = 0 ;
		
		# Récupère les différences prononciations de ce mot-type
		my $prons = cherche_prononciation($lang_section->{'type'}->{$type}->{lines}, $langue, $titre, $type) ;
		
		# Crée autant de lignes qu'il y a de prononciations distinctes (à améliorer)
		my %type_pron = () ;
		foreach my $p (@$prons) {
			$type_pron{$p} = 1 ;
		}
		
		# Tri des prononciations non redondantes
		my @pron = () ;
		if (keys %type_pron == 0) {
			push @pron, @prononciations ;
		} else {
			@pron = keys(%type_pron) ;
		}
		
		# Si prononciations : déterminer le type
		my $flex = $lang_section->{'type'}->{$type}->{flex} ;
		my $loc = $lang_section->{'type'}->{$type}->{loc} ;
		my $num = $lang_section->{'type'}->{$type}->{num} ;
		my $type_nom = $lang_section->{'type'}->{$type}->{type} ;
		
		# gentile?
		if ($type_nom eq 'nom' or $type_nom eq 'adj') {
			$gent = is_gentile($lang_section->{'type'}->{$type}->{lines}) ;
		}
		
		if (@pron) {
			# Ajoute autant de ligne qu'il y a de prononciation
			foreach my $p (@pron) {
				my $p_simple = simple_prononciation($p) ;
				my $r_p_simple = reverse($p_simple) ;
				my $rime = {pauvre=>'', suffisante=>'', riche=>'', voyelle=>''} ;
				$rime = extrait_rimes($p_simple) ;
				
				# Nombre de langue
				if ($langues_total{$langue}) { $langues_total{$langue}++ ; }
				else { $langues_total{$langue} = 1 ; }
				
				# Nombre dans la langue (filtré)
				my $rand = 0 ;
				if (not $gent and not $flex and $type ne 'nom-pr' and not $titre =~ /[0-9]/) {
					if ($langues_filtre{$langue}) { $langues_filtre{$langue}++ ; }
					else { $langues_filtre{$langue} = 1 ; }
					$rand = $langues_filtre{$langue} ;
				}
				my @word_line = ($titre, $langue, $type_nom, $p, $p_simple, $r_p_simple, $rime->{pauvre}, $rime->{suffisante}, $rime->{riche}, $rime->{voyelle}, nombre_de_syllabes($p), $num, $flex, $loc, $gent, $rand);
				add_to_file('mots', \@word_line);
			}
		} else {
			my $p = '' ;
			my $p_simple = '' ;
			my $r_p_simple = '' ;
			my $rime = {pauvre=>'', suffisante=>'', riche=>'', voyelle=>''} ;
			my $num = 1 ;
			# Nombre dans la langue
			if ($langues_total{$langue}) { $langues_total{$langue}++ ; }
			else { $langues_total{$langue} = 1 ; }
			
			# Nombre dans la langue (filtré)
			my $rand = 0 ;
			if (not $gent and not $flex and $type ne 'nom-pr' and not $titre =~ /[0-9]/) {
				if ($langues_filtre{$langue}) { $langues_filtre{$langue}++ ; }
				else { $langues_filtre{$langue} = 1 ; }
				$rand = $langues_filtre{$langue} ;
			}
			my @word_line = ($titre, $langue, $type_nom, $p, $p_simple, $r_p_simple, $rime->{pauvre}, $rime->{suffisante}, $rime->{riche}, $rime->{voyelle}, nombre_de_syllabes($p), $num, $flex, $loc, $gent, $rand);
			add_to_file('mots', \@word_line);
		}
		
		# Transcriptions éventuelles (jap seul pour tester)
		if ($langue eq 'ja') {
			my $transc_type = cherche_transcription($lang_section->{'type'}->{$type}->{lines}, $langue, $titre, $type);
			foreach my $t (@$transc_type) {
				$transc{$t}++;
			}
		}
	}
	
	# Calcul des transcriptions
	foreach my $t (sort keys %transc) {
		my $t_plat = lc(ascii_strict($t));
		my $rt_plat = reverse($t_plat);
		my @transcript_line = (($titre, $t, $t_plat, $rt_plat));
		add_to_file('transcrits', \@transcript_line);
	}
}

###################################
# REDIRECTS
sub redirect
{
	my ($titre, $article) = @_ ;
	
	my $cible = '' ;
	
	if ($article->[0] =~ /\# *REDIRECT[^\[]*\[\[(.+?)\]\]/i) {
		$cible = $1 ;
# 	elsif      ($article->[0] =~ /\# *REDIRECT(ION)? *:? *\[\[(.+?)\]\]/i) {
# 		$cible = $2 ;
# 	} elsif ($article->[0] =~ /\# *REDIRECT(ION)? *:? *\[\[(.+?)\]\]/i) {
# 		$cible = $2 ;
	} else {
		print STDERR "[[$titre]] Pas trouvé de redirect : " ;
		map { chomp; print STDERR "'$_'\n" ; } @$article ;
	}
	
	my @redirect_line = ($titre, $cible);
	add_to_file('redirects', \@redirect_line);
}

###################################
# ARTICLE
sub article
{
	my ($titre, $article) = @_ ;
	my %mot = () ;
	# Ni préfixe ni suffixe, ni accent
	return if $titre =~ /^-/ or $titre =~ /-$/ or $titre =~ /ـ/ ;
	$mot{'titre'} = $titre ;
	
	###########################
	# Travail sur le titre
	$mot{'titre_plat'} = lc(ascii_strict($titre)) ;
	$mot{'anagramme_id'} = anagramme($titre) ;
	
	if ($mot{'titre_plat'}) {
		##########################
		# Sections
		my $article_section = parseArticle($article, $titre) ;
		
		my $lang_ok = $false;
		if ($opt{L}) {
			my $langue = $opt{L} ;
			my $langue_section = $article_section->{language}->{$langue} ;
			if ($#{$langue_section}+1 > 0) {
				ajout_langue($titre, $langue_section, $langue) ;
				$lang_ok = $true;
			}
		} else {
			foreach my $langue (keys %{$article_section->{language}}) {
				my $langue_section = $article_section->{language}->{$langue} ;
				next if not $langue_section ;
				ajout_langue($titre, $langue_section, $langue) ;
			}
			$lang_ok = $true;
		}
		return if not $lang_ok;
		
		##########################
		# Graphie
		$mot{'r_titre'} = reverse($titre) ;
		$mot{'r_titre_plat'} = reverse($mot{'titre_plat'}) ;
		$mot{'transcrit_plat'} = '' ;
		$mot{'r_transcrit_plat'} = '' ;
		
		# Pas alphabet latin ? Transcrire
		if (not unicode_NFKD($mot{'titre_plat'}) =~ /[a-z]/) {
			my @langues = keys %{$article_section->{language}} ;
			$mot{'transcrit_plat'} = transcription($mot{'titre_plat'}, \@langues) ;
			
			# Pas de transcription au final : passer
			if (not $mot{'transcrit_plat'}) {
				return ;
			# Pas complètement transcrit : loguer
			} elsif (not unicode_NFKD($mot{'transcrit_plat'}) =~ /^[a-z ]+$/) {
				special_log('transcription', $titre, $mot{'transcrit_plat'}) ;
				
				return ;
			# Bien transcrit : continuer
			} else {
				$mot{'r_transcrit_plat'} = reverse($mot{'transcrit_plat'}) ;
			}
		}
		my @article_line = ($titre, $mot{'r_titre'}, $mot{'titre_plat'}, $mot{'r_titre_plat'}, $mot{'transcrit_plat'}, $mot{'r_transcrit_plat'}, $mot{'anagramme_id'});
		add_to_file('articles', \@article_line) ;
	}
}

###################
# MAIN
init() ;

my $past = time() ;	# Chronometer start

open(DUMP, dump_input($opt{i})) or die("Couldn't open '$opt{i}': $!\n");
my $title = '';
my ($n, $redirect) = (0,0);
my $complete_article = 0;
my @article = ();
$| = 1;
while(<DUMP>) {
	if ( /<title>(.+?)<\/title>/ ) {
		$title = $1;
		$title = '' if $title =~ /[:\/]/; # Exclude all articles outside of the main namespace
	
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
			# REDIRECTIONS are treated here
			redirect($title, \@article) unless $opt{L};
			######################################
			$redirect++;
		} else {
			######################################
			# ARTICLES are treated here
			article($title, \@article);
			######################################
			$n++ ;
			printf STDERR "%7d articles\r", $n if $n % 1000 == 0;
		}
		$complete_article = 0;
		$title = '';
		@article = ();
	}
}
$| = 0;
close(DUMP);

# Print the language list
add_to_file_language();

# Lastly, some stats
print "Total = $n\n";
print "Total_redirects = $redirect\n";
chronometer_end($past);


__END__

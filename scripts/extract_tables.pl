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
use wiktio::parser			qw( parse_dump parseArticle printArticle parseLanguage printLanguage parseType printType is_gentile);
use wiktio::pron_tools		qw(cherche_prononciation cherche_transcription simple_prononciation extrait_rimes section_prononciation nombre_de_syllabes);

# Output files:
my %output_files = (
'redirects' => {'file' => '', 'fields' => [ qw(title target) ] },
'articles' => {'file' => '', 'fields' => [ qw(titre r_titre titre_plat r_titre_plat transcrit_plat r_transcrit_plat anagramme_id) ] },
'transcrits' => {'file' => '', 'fields' => [ qw(titre transcrit transcrit_plat r_transcrit_plat) ] },
'mots' => {'file' => '', 'fields' => [ qw(titre langue type pron pron_simple r_pron_simple rime_pauvre rime_suffisante rime_riche rime_voyelle syllabes num flex loc gent rand) ] },
'langues' => {'file' => '', 'fields' => [ qw( langue num num_min ) ] },
);

my $max_col = 0;
my %lang_total = ();
my %lang_filter = ();

our %opt;	# Getopt options

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0];
	print STDERR << "EOF";
	
	This script extract data from a Wiktionary dump and create tables that can be imported in an SQL database.
	Right now the only version supported is the French Wiktionary (Wiktionnaire).
	
	usage: $0 -i fr-wikt.xml -o fr-wikt_table [-L fr]
	
	-h        : this (help) message
	-i <path> : input dump path (compressed or not)
	-o <path> : output path (this needs to be a path + prefix of the file names that will be created: path/filename)
	
	Optional:
	-l <path> : special log_files (like -o path + prefix). Those files log specific errors defined in the parser.
	-L <code> : language code to extract alone (2 or 3 letters) [optional]
	-c <num>  : length of crossword searchable columns
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'i:o:L:l:c:', \%opt ) or usage();
	%opt = %{ to_utf8(\%opt) };
	usage() if $opt{h};
	
	$log = $opt{l} ? $opt{l} : '';
	
	usage( "Dump path needed (-i)" ) if not $opt{i};
	usage( "Output file path needed (-o)" ) if not $opt{o};
	
	# Prepare output file path
	$opt{o} .= '.csv' if not $opt{o} =~ /\.[a-z0-9]+$/;
	print STDERR "Files in $opt{o}\n";
	
	# Prepare output files
	foreach my $type (keys %output_files) {
		# Name of the file for this type
		$output_files{$type}{file} = $opt{o};
		$output_files{$type}{file} =~ s/^(.+?)(\.[a-z0-9]+)$/$1_$type$2/;
		
		# Init the file
		open(TYPE, "> $output_files{$type}{file}") or die "Impossible d'initier $output_files{$type}{file}: $!\n";
		close(TYPE);
	}
	
	if ($opt{c}) {
		usage("Wrong number for the crossword columns (-c): $opt{c}") if not "$opt{c}" =~ /^[1-9][0-9]*$/;
		$max_col = $opt{c};
		init_columns();
	}
	
	# Print columns order so that the user know what is written where
	foreach my $outs (sort keys %output_files) {
		print STDERR "$outs: ", join(', ', @{ $output_files{$outs}{fields} }), "\n";
	}
}

sub init_columns
{
	return if not $max_col;
	
	# Add a column for the first $maxcol letters
	for (my $i=0; $i < $max_col; $i++) {
		my $col = 'p' . ($i+1);
		push @{ $output_files{'articles'}{'fields'} }, $col;
	}
}

# Write to the various output files
sub add_to_file
{
	my ($type, $values) = @_;
	
	open(TYPE, ">> $output_files{$type}{file}") or die "Impossible d'écrire $output_files{$type}{file} (type $type): $!\n";
	
	my @line = ();
	foreach my $f (@{ $output_files{$type}{fields} }) {
		if (defined($values->{$f})) {
			push @line, $values->{$f};
		} else {
			push @line, '';
		}
	}
	print TYPE '"' . join( '","' , @line) . "\"\n";	# Print line in csv style: "A","B","C"\n
	close(TYPE);
}

sub add_to_file_lang
{
	my ($line) = @_;
	open(LANG, "> $output_files{langues}{file}") or die "Can't write $output_files{langues}{file}: $!\n";
	foreach my $l (sort keys(%lang_total)) {
		my $filter = $lang_filter{$l} ? $lang_filter{$l} : 0;
		my @lang_line = ($l, $lang_total{$l}, $filter);
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

###################################
# PARSERS

sub parse_articles
{
	my ($dump_path) = @_;

	# Counting variables
	my ($n, $redirect) = (0,0);
	
	# Scan every line of the dump
	open(my $dump_fh, dump_input($dump_path)) or die "Couldn't open '$dump_path': $!\n";
	
	$| = 1;	 # This allows the counter to rewrite itself on a single line
	ARTICLE : while(my $article = parse_dump($dump_fh)) {
		$n++;
		#printf STDERR "[%7d] $article->{'fulltitle'}\r", $n if $n % 1000 == 0;	# Simple counter
		print STDERR "[$n] $article->{'fulltitle'}                                   \r" if $n % 100 == 0;	# Simple counter
		
		next ARTICLE if $article->{'ns'} != 0;
		
		if ($article->{'redirect'}) {
			# Only parse redirects if there is no specific target language (because redirects have no language)
			parse_redirect($article);
			$redirect++;
		} else {
			# Fully parse the article
			parse_article($article);
			
		}
	}
	print STDERR "\n";
	$| = 0;
	close($dump_fh);
	
	# Print the language list
	add_to_file_lang();
	
	# Lastly, some stats
	print_value("%d total articles", $n);
	print_value("%d total redirects", $redirect);
}

###################################
# REDIRECTS PARSER
sub parse_redirect
{
	my ($article) = @_;
	
	my $target = '';
	
	my %redirect_values = (
		'title' => $article->{'fulltitle'},
		'target' => $article->{'redirect'},
	);
	add_to_file('redirects', \%redirect_values);
}

###################################
# ARTICLES PARSER
sub parse_article
{
	my ($article) = @_;
	
	# This will stock the important values that will be put in the table
	my %mot = ();
	
	# Discard any *ffixes
	return if $article->{'title'} =~ /^-/ or $article->{'title'} =~ /-$/;
	$mot{'titre'} = $article->{'title'};
	
	###########################
	# From the title only we can get (-> table articles)
	$mot{'r_titre'} = reverse($mot{'titre'});					# Reverse title (for sql search)
	$mot{'titre_plat'} = lc(ascii_strict($mot{'titre'}));		# titre_plat (no hyphenation)
	$mot{'r_titre_plat'} = reverse($mot{'titre_plat'});			# Same, reversed
	$mot{'anagramme_id'} = anagramme($mot{'titre_plat'});		# anagramme_id (alphagram, key for anagrams)
	
	# Can't get a correct unhyphenated word (should only be symbols and such)
	if (not $mot{'titre_plat'}) {
		special_log('titre_plat', $mot{'titre'});	# Log just to be sure
		
	# Everything is ok thus far
	} else {
		# Let's parse the whole article and divide it into languages sections
		my $article_section = parseArticle($article->{'content'}, $article->{'title'});
		
		# If we are only interested in one language, only parse this one further
		my $lang_ok = $false;
		if ($opt{L}) {
			# Ok, so it there such a section?
			my $lang = $opt{L};
			my $lang_section = $article_section->{language}->{$lang};
			
			# Yes there is: let's parse it further (-> table mots)
			if ($#{$lang_section}+1 > 0) {
				parse_language_sections($mot{'titre'}, $lang_section, $lang);
				$lang_ok = $true;
				
			# No: then no need to stay here
			} else {
				return;
			}
		
		# We want all languages: parse everything
		} else {
			foreach my $lang (keys %{$article_section->{language}}) {
				my $lang_section = $article_section->{language}->{$lang};
				
				# No content? Something's not right
				if (not $lang_section) {
					special_log('empty_lang', $mot{'titre'}, $lang);	# Log just to be sure
					
				# Everything is here, let's part this section (-> table mots)
				} else {
					parse_language_sections($mot{'titre'}, $lang_section, $lang);
				}
			}
			$lang_ok = $true;
		}
		return if not $lang_ok;
		
		# If the script is not latin, let's try transcriptions (language-specific)
		# We will only keep unhyphenated transcripts here
		$mot{'transcrit_plat'} = '';	# unhyphenated transcript (non-latin words)
		$mot{'r_transcrit_plat'} = '';	# same, reversed for sql
		
		# Not latin script? Let's try to compute a transcript!
		if (not unicode_NFKD($mot{'titre_plat'}) =~ /[a-z]/) {
			my @langs = keys %{$article_section->{language}};
			$mot{'transcrit_plat'} = transcription($mot{'titre_plat'}, \@langs);
			
			# No transcription could be done (unsupported script)
			if (not $mot{'transcrit_plat'}) {
				$mot{'transcrit_plat'}='';
			
			# Uncomplete transcription (should be supported! -> log)
			} elsif (not unicode_NFKD($mot{'transcrit_plat'}) =~ /^[a-z0-9â ]+$/) {
				special_log('incomplete_transcription', $mot{'titre'}, $mot{'transcrit_plat'});
				$mot{'transcrit_plat'}='';
				
			# We have a correct transcript!
			} else {
				$mot{'r_transcrit_plat'} = reverse($mot{'transcrit_plat'});
			}
		}
		
		# Prepare letters fields
		if ($max_col) {
			my $mot_plat = $mot{'titre_plat'};
			$mot_plat =~ s/[ _,;-]//g;
			my @mot_letters = split(//, $mot_plat);
			
			# Add individual letters (if the "word" is shorter than the max allowed
			for (my $i=0; $i < $max_col; $i++) {
				if (@mot_letters <= $max_col and $mot_letters[$i]) {
					$mot{'p'.($i+1)} = $mot_letters[$i];
				}
				else {
					$mot{'p'.($i+1)} = '';
				}
			}
		}
		
		add_to_file('articles', \%mot);
	}
}

###################################
# LANGUAGE SECTION
sub parse_language_sections
{
	my ($title, $section, $lang) = @_;
	
	# First extract all level 3 sections, even the etymology, pron, ref, etc.
	my $lang_section = parseLanguage($section, $title, $lang);
	my @sections = keys %{$lang_section};
	my @types = keys %{$lang_section->{'type'}};
	
	# Can we get pronunciations from the dedicated section?
	my @prononciations = section_prononciation($lang_section->{'prononciation'}->{lines}, $title);
	my %transc = ();	# Prepare to store every transcription found in the text as well
	
	# Look into every word type section
	foreach my $type (@types) {
		
		# Additionnal informations for the word
		my $type_nom = $lang_section->{'type'}->{$type}->{type};
		my $flex = $lang_section->{'type'}->{$type}->{flex};
		my $loc = $lang_section->{'type'}->{$type}->{loc};
		my $num = $lang_section->{'type'}->{$type}->{num};
		next if $type eq 'erreur';	# Not interested in error sections
		
		#  Special, name of inhabitants should be marked to be avoidable in searches as there is *a lot*
		my $gent = 0;
		if ($type_nom eq 'nom' or $type_nom eq 'adj') {
			$gent = is_gentile($lang_section->{'type'}->{$type}->{lines});
		}
		
		# Get all pronunciations for this word that we an find in the text (marked with models usually)
		my $prons = cherche_prononciation($lang_section->{'type'}->{$type}->{lines}, $lang, $title, $type);
		
		# This should be improved: add an entry for every different entry
		my %type_pron = ();
		foreach my $p (@$prons) {
			$type_pron{$p} = 1;
		}
		
		# Sort non-redundant pronunciations
		my @pron = ();
		if (keys %type_pron == 0) {
			push @pron, @prononciations;
		} else {
			@pron = keys(%type_pron);
		}
		
		# Two cases: if there are several pronunciations, or no pronunciation at all
		
		my %word_values = (
			'titre' => $title,
			'langue' => $lang,
			'type' => $type_nom,
			'num' => $num,
			'flex' => $flex,
			'loc' => $loc,
			'gent' => $gent,
		);
		
		# >=1 prononciation? Add one entry for each one (not very good, but ok for now)
		if (@pron) {
			foreach my $pronunciation (@pron) {
				my %values = %word_values;	# clone
				add_entry(\%values, $pronunciation);
			}
		
		# No pronunciation: no need to compute pronunciation-related data -> a single entry is enough
		} else {
			my %values = %word_values;	# clone
			add_entry(\%values);
		}
		
		# Additional work: try to get language specific transcription in this section
		# Should not be hard coded like that (loop through available transcriptions dictionary)
		if ($lang eq 'ja') {
			my $transc_type = cherche_transcription($lang_section->{'type'}->{$type}->{lines}, $lang, $title, $type);
			foreach my $t (@$transc_type) {
				$transc{$t}++;
			}
		}
	}
	
	# Afterwork: Save all transcriptions found in the text of this article!
	foreach my $t (sort keys %transc) {
		my $t_plat = lc(ascii_strict($t));
		my %transcript_values = (
			'titre' => $title,
			'transcrit' => $t,
			'transcrit_plat' => $t_plat,				# Unhyphenated transcript
			'r_transcrit_plat' => reverse($t_plat),		# Same, reversed for sql
		);
		add_to_file('transcrits', \%transcript_values);
	}
}

sub add_entry
{
	my ($word_values, $p) = @_;
	# $p = pronunciation of this entry
	
	my %pron_values = ();
	if ($p) {
		my $p_simple = simple_prononciation($p);
		my $r_p_simple = reverse($p_simple);
		my $rime = {pauvre=>'', suffisante=>'', riche=>'', voyelle=>''};
		$rime = extrait_rimes($p_simple);
		
		%pron_values = (
			'pron' => $p,
			'pron_simple' => $p_simple,
			'r_pron_simple' => $r_p_simple,
			'rime_pauvre' => $rime->{pauvre},
			'rime_suffisante' => $rime->{suffisante},
			'rime_riche' => $rime->{riche},
			'rime_voyelle' => $rime->{voyelle},
			'syllabes' => nombre_de_syllabes($p),
		);
	}
	
	# Fuse all information from word and pronunciation
	my %values = (%$word_values, %pron_values);
	
	# Add a random number so that the entry may be chosen randomly
	$values{'rand'} = random_counter($word_values);
	
	# Save all the values as an entry in the table mots
	add_to_file('mots', \%values);
}

# Manage random number for the entry
sub random_counter
{
	my ($values) = @_;
	
	my $lang = $values->{'langue'};
	
	# Increase the random language counter
	if ($lang_total{$lang}) { $lang_total{$lang}++; }
	else { $lang_total{$lang} = 1; }
	
	# Ok to be a random word?
	if (not $values->{gent} 					# No inhabitant names/adjectives
		and not $values->{flex}					# No flexion
		and $values->{type} ne 'nom-pr'			# No proper nouns
		and not $values->{titre} =~ /[0-9]/)	# No number
		{
		# Increase the filtered language counter
		if ($lang_filter{$lang}) {$lang_filter{$lang}++; }
		else { $lang_filter{$lang} = 1; }
		
		# Save the number for the random search
		return $lang_filter{$lang};
	}
	
	# Default: random number=0
	return 0;
}

###################
# MAIN
init();

my $past = time();	# Chronometer start

parse_articles($opt{i});

chronometer_end($past);


__END__

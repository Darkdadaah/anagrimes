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
use wiktio::string_tools	qw(ascii_strict transcription anagramme unicode_NFKD);
use wiktio::parser			qw( parse_dump parseArticle printArticle parseLanguage printLanguage parseType printType is_gentile);
use wiktio::pron_tools		qw(cherche_prononciation cherche_transcription simple_prononciation extrait_rimes section_prononciation nombre_de_syllabes);

# Output files:
our %output_files = (
'langs' => {'file' => '', 'fields' => {
	'lg_lang' => 'text',
	'lg_num' => 'int',
	'lg_num_min' => 'int',
	}
},

# Articles are "strings"
'articles' => {'file' => '', 'fields' => {
	'a_artid' => 'int',
	'a_title' => 'text',
	'a_title_flat' => 'text',
	'a_title_r' => 'text',
	'a_title_flat_r' => 'text',
	'a_trans' => 'text',
	'a_trans_flat' => 'text',
	'a_trans_flat_r' => 'text',
	'a_alphagram' => 'text',
	}
},

# Lexemes are "words"
'lexemes' => {'file' => '', 'fields' => {
	'l_artid' => 'int',
	'l_lexid' => 'int',
	'l_lang' => 'text',
	'l_type' => 'text',
	'l_num' => 'int',
	'l_is_flexion' => 'int',
	'l_is_locution' => 'int',
	'l_is_gentile' => 'int',
	'l_rand' => 'int',
	}
},

# 1 lexeme can have several pronunciations,
# one pronunciation only match one lexeme
# pron is in IPA
'prons' => {'file' => '', 'fields' => {
	'p_pronid' => 'int',
	'p_lexid' => 'int',
	'p_pron' => 'text',
	'p_pron_flat' => 'text',
	'p_pron_flat_r' => 'text',
	'p_num' => 'int',
	}
},

# Rhymes to add?

# Keep?
'transc' => {'file' => '', 'fields' => {
	'tr_artid' => 'int',
	'tr_transc' => 'text',
	'tr_transc_flat' => 'text',
	'tr_transc_flat_r' => 'text',
	}
},

# Redirects are not connected to the other tables
'redirects' => {'file' => '', 'fields' => {
	'r_title' => 'text',
	'r_target' => 'text',
	}
},
);

my $max_col = 0;
my %lang_total = ();
my %lang_filter = ();
my %counter = ();

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
	-S <path> : print SQL commands to create the corresponding tables of every file created
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'i:o:L:l:c:S:', \%opt ) or usage();
	usage() if $opt{h};
	
	$log = $opt{l} ? $opt{l} : '';
	
	usage( "Dump path needed (-i)" ) if not $opt{i};
	usage( "Output file path needed (-o)" ) if not $opt{o};
	
	# Prepare output file path
	$opt{o} .= '.txt' if not $opt{o} =~ /\.[a-z0-9]+$/;
	
	# Prepare output files
	foreach my $type (keys %output_files) {
		# Name of the file for this type
		$output_files{$type}{file} = $opt{o};
		$output_files{$type}{file} =~ s/^(.+?)(\.[a-z0-9]+)$/$1_$type$2/;
		
		# Init the file
		open(TYPE, "> $output_files{$type}{file}") or die "Can't init file $output_files{$type}{file}: $!\n";
		close(TYPE);
	}
	
	if ($opt{c}) {
		usage("Wrong number for the crossword columns (-c): $opt{c}") if not "$opt{c}" =~ /^[1-9][0-9]*$/;
		$max_col = $opt{c};
		init_crossword_columns();
	}
}

sub init_crossword_columns
{
	return if not $max_col;
	
	# Add a column for the first $maxcol letters
	for (my $i=0; $i < $max_col; $i++) {
		my $col = 'p' . ($i+1);
		$output_files{'articles'}{'fields'}->{$col} = 'CHAR(1)';
	}
}

sub print_sql_tables
{
	my ($sql_path) = @_;
	return if not $sql_path;
	
	open(my $SQL, ">$sql_path") or die("Couldn't write $sql_path");
	
	foreach my $table (keys %output_files) {
		print_sql_table($SQL, $table, $output_files{$table}{fields});
	}
}

sub print_sql_table
{
	my ($SQL, $table, $fields) = @_;
	
	my $start = "CREATE TABLE $table (\n";
	my @line = ();
	foreach my $f (sort keys %$fields) {
		my $type = $fields->{$f};
		push @line, "\t$f $type";
	}
	print $SQL $start . join(",\n", @line) . "\n);\n\n";
}

# Write to the various output files
sub add_to_file
{
	my ($type, $values) = @_;
	
	open(TYPE, ">> $output_files{$type}{file}") or die "Can't write $output_files{$type}{file} (type $type): $!\n";
	
	my @line = ();
	foreach my $f (sort keys %{ $output_files{$type}{fields} }) {
		if (defined($values->{$f})) {
			my $val = $values->{$f};
			$val =~ s/"/\"/g;	# Obligatory escape
			$val =~ s/\t//g;	# No \t allowed!
			push @line, $val;
		} else {
			push @line, '';
		}
	}
	print TYPE join( "\t" , @line) . "\n";
	close(TYPE);
}

sub add_to_file_lang
{
	my ($line) = @_;
	open(LANG, "> $output_files{langs}{file}") or die "Can't write $output_files{langs}{file}: $!\n";
	foreach my $l (sort keys(%lang_total)) {
		my $filter = $lang_filter{$l} ? $lang_filter{$l} : 0;
		my @lang_line = ($l, $lang_total{$l}, $filter);
		print LANG join( "\t" , @lang_line) . "\n";
	}
	close(LANG);
}

###################################
# PARSERS

sub parse_articles
{
	my ($dump_path) = @_;
	
	# Scan every line of the dump
	open(my $dump_fh, dump_input($dump_path)) or die "Couldn't open '$dump_path': $!\n";
	
	ARTICLE : while(my $article = parse_dump($dump_fh)) {
		next ARTICLE if $article->{'ns'} != 0;	# Only main namespace
		
		if ($article->{'redirect'}) {
			# Only parse redirects if there is no specific target language (because redirects have no language)
			parse_redirect($article);
		} else {
			# Fully parse the article
			parse_article($article);
			
		}
	}
	close($dump_fh);
}

###################################
# REDIRECTS PARSER
sub parse_redirect
{
	my ($article) = @_;
	
	my $target = '';
	
	my %redirect_values = (
		'r_title' => $article->{'fulltitle'},
		'r_target' => $article->{'redirect'},
	);
	add_to_file('redirects', \%redirect_values);
}

sub title_format
{
	my ($article) = @_;
	my %title = ();
	
	$title{'a_title'} = $article->{'title'};
	$title{'a_artid'} = $article->{'id'};
	
	###########################
	# From the title only we can get (-> table articles)
	$title{'a_title_r'} = reverse($title{'a_title'});					# Reverse title (for sql search)
	$title{'a_title_flat'} = lc(ascii_strict($title{'a_title'}));		# titre_plat (no hyphenation)
	$title{'a_title_flat_r'} = reverse($title{'a_title_flat'});			# Same, reversed
	$title{'a_alphagram'} = anagramme($title{'a_title_flat'});		# anagramme_id (alphagram, key for anagrams)
	
	return \%title;
}

sub transc_format
{
	my ($title, $article, $article_section) = @_;
	my %transc = ();
	
	# If the script is not latin, let's try transcriptions (language-specific)
	# We will only keep unhyphenated transcripts here
	$transc{'a_trans_flat'} = '';	# unhyphenated transcript (non-latin words)
	$transc{'a_trans_flat_r'} = '';	# same, reversed for sql
	
	# Not latin script? Let's try to compute a transcript!
	if (not unicode_NFKD($title->{'a_title_flat'}) =~ /[a-z]/) {
		my @langs = keys %{$article_section->{language}};
		$transc{'a_trans_flat'} = transcription($title->{'a_title_flat'}, \@langs);
		
		# No transcription could be done (unsupported script)
		if (not $transc{'a_trans_flat'}) {
			$transc{'trans_flat'}='';
		
		# Uncomplete transcription (should be supported! -> log)
		} elsif (not unicode_NFKD($transc{'a_trans_flat'}) =~ /^[a-z0-9â ]+$/) {
			special_log('incomplete_transcription', $title->{'a_title'}, $transc{'a_trans_flat'});
			$transc{'a_trans_flat'} = '';
			
		# We have a correct transcript!
		} else {
			$transc{'a_trans_flat_r'} = reverse($transc{'a_trans_flat'});
		}
	}
	return \%transc;
}

sub prepare_crossword
{
	my ($title) = @_;
	my %cross = ();

	# Prepare letters fields for crossword
	if ($max_col) {
		my $title_plat = $title->{'a_title_flat'};
		$title_plat =~ s/[ _,;-]//g;
		my @word_letters = split(//, $title_plat);
		
		# Add individual letters (if the "word" is shorter than the max allowed
		for (my $i=0; $i < $max_col; $i++) {
			if (@word_letters <= $max_col and $word_letters[$i]) {
				$cross{'p'.($i+1)} = $word_letters[$i];
			}
			else {
				$cross{'p'.($i+1)} = '';
			}
		}
	}
		
	
	return \%cross;
}

###################################
# ARTICLES PARSER
sub parse_article
{
	my ($article) = @_;
	
	# Discard any *ffixes
	return if $article->{'title'} =~ /^-/ or $article->{'title'} =~ /-$/;
	
	# Retrieve the values for the title of this article
	my $title_val = title_format($article);
	my $crosswords = prepare_crossword($title_val);
	
	# Can't get a correct unhyphenated word (should only be symbols and such)
	if (not $title_val->{'a_title_flat'}) {
		special_log('a_title_flat', $title_val->{'a_title'});	# Log just to be sure
		
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
				parse_language_sections($article, $lang_section, $lang);
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
					special_log('empty_lang', $title_val->{'a_title'}, $lang);	# Log just to be sure
					
				# Everything is here, let's part this section (-> table mots)
				} else {
					parse_language_sections($article, $lang_section, $lang);
				}
			}
			$lang_ok = $true;
		}
		return if not $lang_ok;
		
		# Prepare transcriptions
		my $transc_val = transc_format($title_val, $article, $article_section);
		
		# Merge all article data
		my %article_vals = (%$title_val, %$crosswords, %$transc_val);
		add_to_file('articles', \%article_vals);
	}
}

###################################
# LANGUAGE SECTION
sub parse_language_sections
{
	my ($article, $section, $lang) = @_;
	my $title = $article->{'title'};
	
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
		
		# Get all pronunciations for this word that we can find in the text (marked with models usually)
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
			'l_artid' => $article->{'id'},
			'l_title' => $title,
			'l_lang' => $lang,
			'l_type' => $type_nom,
			'l_num' => $num,
			'l_is_flexion' => $flex,
			'l_is_locution' => $loc,
			'l_is_gentile' => $gent,
			'l_lexid' => counter('lexemes'),
		);
		
		# Add a random number so that the entry may be chosen randomly
		$word_values{'l_rand'} = random_counter(\%word_values);
			
		# Add this entry
		add_to_file('lexemes', \%word_values);
		
		# Then add each pron
		foreach my $pronunciation (@pron) {
			#die " @pron : $article->{title}\n";
			my %values = %word_values;	# clone
			add_pron(\%values, $pronunciation);
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
			'tr_aid' => $article->{id},
			'tr_transc' => $t,
			'tr_transc_flat' => $t_plat,				# Unhyphenated transcript
			'tr_transc_flat_r' => reverse($t_plat),		# Same, reversed for sql
		);
		add_to_file('transc', \%transcript_values);
	}
}

sub add_pron
{
	my ($word_values, $p) = @_;
	
	my $p_flat = simple_prononciation($p);
	my $p_flat_r = reverse($p_flat);
	#my $rime = {pauvre=>'', suffisante=>'', riche=>'', voyelle=>''};
	#$rime = extrait_rimes($p_simple);
	
	my %pron_values = (
		'p_pronid' => counter('pron'),
		'p_lexid' => $word_values->{'l_lexid'},
		'p_pron' => $p,
		'p_pron_flat' => $p_flat,
		'p_pron_flat_r' => $p_flat_r,
		#'rime_pauvre' => $rime->{pauvre},
		#'rime_suffisante' => $rime->{suffisante},
		#'rime_riche' => $rime->{riche},
		#'rime_voyelle' => $rime->{voyelle},
		#'syllabes' => nombre_de_syllabes($p),
	);
	
	# Save all the values in the table pron
	add_to_file('prons', \%pron_values);
}

# Manage random number for the entry
sub random_counter
{
	my ($values) = @_;
	
	my $lang = $values->{'l_lang'};
	
	# Increase the random language counter
	if ($lang_total{$lang}) { $lang_total{$lang}++; }
	else { $lang_total{$lang} = 1; }
	
	# Ok to be a random word?
	if (not $values->{'l_is_gentile'} 					# No inhabitant names/adjectives
		and not $values->{'l_is_flex'}					# No flexion
		and $values->{'l_type'} ne 'nom-pr'			# No proper nouns
		and not $values->{'l_title'} =~ /[0-9]/)	# No number
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

sub counter
{
	my $cname = shift;
	$counter{$cname}++;
	return $counter{$cname};
}

###################
# MAIN
init();

# Print the SQL schema
print_sql_tables($opt{S});

# Actual parsing of the dumps
parse_articles($opt{i});
	
# Lastly, print the language table
add_to_file_lang();


__END__

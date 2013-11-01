#!/usr/bin/perl -w

# Test the functions ascii etc.
use strict;
use warnings;
use Getopt::Std;

use lib '..';
use wiktio::basic		qw(step stepl print_value);
use wiktio::parser		qw(parseArticle);
our %opt;

# Special case of Wiktionaries that use full name or special codes for their langues
my $languages = {
	'en' => {
		'de' => 'Deutsch',
		'en' => 'English',
		'fr' => 'French',
		'it' => 'Italian',
		'ru' => 'Russian',
	},
	'de' => {
		'de' => 'Deutch',
		'en' => 'Englisch',
		'fr' => 'Franz.+sisch',
		'it' => 'Italienisch',
		'ru' => 'Russisch',
	},
	'vi' => {
		'fr' => 'fra',
		'en' => 'eng',
		'de' => 'deu',
		'it' => 'ita',
		'ru' => 'rus',
	},
};

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0];
	print STDERR << "EOF";
	
	This script makes a diff of the articles from one same language in 2 Wiktionaries.
	It outputs both a list of articles found only in the first, and a list found only in the second Wiktionary dump.
	
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
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hc:l:L:i:I:o:O:', \%opt ) or usage();
	usage() if $opt{h};
	
	usage( "Language to compare needed (-c)" ) if not $opt{c};
	
	usage( "First dump language needed (-l)" ) if not $opt{l};
	usage( "Second dump language needed (-L)" ) if not $opt{L};
	usage( "First dump path needed (-i)" ) if not $opt{i};
	usage( "Second dump path needed (-I)" ) if not $opt{I};
	usage( "First or second output file path needed (-o)" ) if not $opt{o} and not $opt{O};
}

##################################
# Subroutines

# Prepare the language_section text that we want to find in an article about a given language
sub prepare_language_section
{
	my ($wiktlang, $lang) = @_;
	my $lang_sec = '';
	
	# Language sections format specific to some Wiktionaries
	# French
	if ($wiktlang eq 'fr') {
		$lang_sec = '\{\{langue\|'.$lang.'\}\}';
	# English
	} elsif ($wiktlang eq 'en') {
		$lang_sec = "^== *$languages->{$wiktlang}->{$lang} *==";
	# German
	} elsif ($wiktlang eq 'de') {
		$lang_sec = '\{\{Sprache\|' . $languages->{$wiktlang}->{$lang} . '\}\}';
	# All other wiktionaries: supposed to use the old style "{{-xx-}}" where "xx" is a language code
	} else {
		# Special language codes? (e.g. "eng" instead of "en")
		if ($languages->{$wiktlang}) {
			my $code = $languages->{$wiktlang}->{$lang};
			$code = $lang if not $code;
			$lang_sec = '\{\{-'.$code.'-\}\}';
		} else {
			$lang_sec = '\{\{-'.$lang.'-\}\}';
		}
	}
	stepl "(search for '$lang_sec') ";	# Leave the line open to write the stats
	return $lang_sec;
}

# Parse a dump
sub get_articles_list
{
	my ($file, $recherche) = @_;
	my $list = {};

	if ($file =~ /\.bz2$/) {
		$file = "bzcat $file |";
	}
	
	open(DUMP, $file) or die "Couldn't open '$file': $!\n";
	
	my $title = '';
	while(my $line = <DUMP>) {
		# Get page title
		if ($line =~ /<title>(.+?)<\/title>/) {
			$title = $1;
			# Exclude pages outside of the main space
			$title = '' if $title =~ /[:\/]/;
		
		# Get page content
		} elsif ($title and $line =~ /<text xml:space="preserve">(.*?)$/) {
			my $head = $1;
			# Search for the language section already
			if ($head =~ /$recherche/) {
				$list->{$title} = 1;
				$title = '';
				next;
			} else {
				if ($line =~ /<\/text>/) {
					$title='';
					next;
				}
				while (my $inline = <DUMP>) {
					# Continue to search for the language section
					if ($inline =~ /$recherche/) {
						$list->{$title} = 1;
						$title='';
					}
					if ($inline =~ /<\/text>/) {
						$title='';
						last;
					}
				}
			}
		}
	}
	close(DUMP);
	
	return $list;
}

# Compare both lists and outputs items that are specific to each and common to both
sub diff_lists
{
	my ($first, $second) = @_;
	my $first_only = {};
	my $second_only = {};
	my $common = {};
	
	foreach my $one (keys %$first) {
		if ($second->{$one}) {
			$common->{$one} = 1;
			delete $first->{$one};
			delete $second->{$one};
		} else {
			$first_only->{$one} = 1;
			delete $first->{$one};
		}
	}
	
	foreach my $two (keys %$second) {
		$second_only->{$two} = 1;
		delete $second->{$two};
	}
	
	return ($first_only, $second_only, $common);
}

# Output a list of articles in wiki code with a link to the other wiktionary
sub write_list
{
	my ($list, $file, $lang) = @_;
	open(LISTE, ">$file") or die "Couldn't write $file: $!";
	print LISTE '<div style="-moz-column-count:4">'."\n";
	foreach my $article (sort keys %$list) {
		next if not $article;
		print LISTE "# [[$article]] [[:$lang:$article|*]]\n";
	}
	print LISTE '</div>'."\n";
	close(LISTE);
}

###################
# MAIN
init();

# Get list from the first Wiktionary
stepl "Parse $opt{l} Wiktionary: ";
my $lang_section_1 = prepare_language_section(find_words($opt{l}, $opt{c});
my $first = get_articles_list($opt{i}, $lang_section_1);
print_value("%d articles in $opt{c}", $first);

# Get list from the second Wiktionary
stepl "Parse $opt{L} Wiktionary: ";
my $lang_section_2 = prepare_language_section(find_words($opt{L}, $opt{c});
my $first = get_articles_list($opt{I}, $lang_section_2);
print_value("%d articles in $opt{c}", $second);

# Compare
step "Compare:";
my ($first_only, $second_only, $common) = diff_lists($first, $second);
print_value("%d articles only in $opt{l}", $first_only);
print_value("%d articles only in $opt{L}", $second_only);
print_value("%d articles in common", $common);

# Write lists
if ($opt{o}) {
	step "Write the articles found only in $opt{l} Wiktionary";
	write_list($first_only, $opt{o}, $opt{l});
}
if ($opt{O}) {
	step "Write the articles found only in $opt{L} Wiktionary";
	write_list($second_only, $opt{O}, $opt{L});
}

__END__

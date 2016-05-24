#!/usr/bin/perl -w

# Test the functions ascii etc.
use strict;
use warnings;
use Getopt::Std;

use lib '..';
use wiktio::basic;
use wiktio::basic qw(step stepl print_value);
use wiktio::dump_reader;
use wiktio::parser qw(parseArticle);
use wiktio::string_tools qw(unisort_key);
our %opt;
use utf8;
use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

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
    'zh' => {
        'fr' => '\{\{-fra?-[\|\}]',
    },
    'ja' => {
        'fr' => '(フランス語|\{\{fra?\}\})',
        'ja' => '(日本語|\{\{(ja|jpn)\}\})',
    },
    'vi' => {
        'fr' => '\{\{-fra-[\|\}]',
        'en' => '\{\{-eng-[\|\}]',
        'de' => '\{\{-deu-[\|\}]',
        'it' => '\{\{-ita-[\|\}]',
        'ru' => '\{\{-rus-[\|\}]',
    },
    'es' => {
        'fr' => '\{\{FR-ES\|',
        'es' => '\{\{ES\|',
    },
};
my @langs = qw( fr );
push @langs, keys %$languages;
my $supported_lang = join ', ', ( sort @langs );

#################################################
# Message about this program and how to use it
sub usage {
    print STDERR "[ $_[0] ]\n" if $_[0];
    print STDERR << "EOF";
	
	This script makes a diff of the articles from one same language in 2 Wiktionaries.
	It outputs both a list of articles found only in the first, and a list found only in the second Wiktionary dump.
	
	usage: $0 [-h] -l lang -1 wikt1 -2 wikt2
	
	-h        : this (help) message
	
	-c <code> : language code
	
	-l <code> : first dump language code
	-L <code> : second dump language code
	
	-i <path> : dump path of the first Wiktionary
	-I <path> : dump path of the second Wiktionary
	
	-o <path> : output path of the pages found only in the first Wiktionary
	-O <path> : output path of the pages found only in the second Wiktionary
	
	-R		  : disable redirect matching
	
	example: $0 -c en -l fr -L en -i frwikt.xml -I enwikt.xml -o en_frwikt-only.txt -O en_enwikt_only.txt

	Supported language codes: $supported_lang
EOF
    exit;
}

##################################
# Command line options processing
sub init() {
    getopts( 'hc:l:L:i:I:o:O:R', \%opt ) or usage();
    usage() if $opt{h};

    usage("Language to compare needed (-c)") if not $opt{c};

    usage("First dump language needed (-l)")  if not $opt{l};
    usage("Second dump language needed (-L)") if not $opt{L};
    usage("First dump path needed (-i)")      if not $opt{i};
    usage("Second dump path needed (-I)")     if not $opt{I};
    usage("First or second output file path needed (-o)")
      if not $opt{o} and not $opt{O};
}

##################################
# Subroutines

# Prepare the language_section text that we want to find in an article about a given language
sub prepare_language_section {
    my ( $wiktlang, $lang ) = @_;
    my $lang_sec = '';

    # Language sections format specific to some Wiktionaries
    # French
    if ( $wiktlang eq 'fr' ) {
        $lang_sec = '\{\{langue\|' . $lang . '\}\}';

        # English
    }
    elsif ( $wiktlang eq 'en' or $wiktlang eq 'ja' ) {
        $lang_sec = "^== *$languages->{$wiktlang}->{$lang} *==";

        # German
    }
    elsif ( $wiktlang eq 'de' ) {
        $lang_sec = '\{\{Sprache\|' . $languages->{$wiktlang}->{$lang} . '\}\}';

# All other wiktionaries: supposed to use the old style "{{-xx-}}" where "xx" is a language code
    }
    else {
        # Special language codes? (e.g. "eng" instead of "en")
        if ( $languages->{$wiktlang} ) {
            my $code = $languages->{$wiktlang}->{$lang};
            $code = $lang if not $code;
            $lang_sec = $code;
        }
        else {
            $lang_sec = '\{\{-' . $lang . '-\}\}';
        }
    }
    stepl "(search for '$lang_sec') ";  # Leave the line open to write the stats
    return $lang_sec;
}

# Parse a dump
sub get_articles_list {
    my ( $dump_path, $lang_section ) = @_;
    my $list     = {};
    my $redirect = {};

    my $dump_fh = dump_open($dump_path);

  ARTICLE: while ( my $article = parse_dump($dump_fh) ) {
        if ( not defined( $article->{'fulltitle'} ) ) {
            next ARTICLE;
        }

        if ( defined( $article->{'redirect'} ) ) {
            $redirect->{ $article->{'title'} }++;
        }

        if ( $article->{'ns'} != 0 ) {
            next ARTICLE;
        }

        # Search for the language section
        foreach my $line ( @{ $article->{'content'} } ) {
            if ( $line =~ /$lang_section/ ) {
                $list->{ $article->{'title'} }++;
                next ARTICLE;
            }
        }
    }
    close($dump_fh);
    return $list, $redirect;
}

# Compare both lists and outputs items that are specific to each and common to both
sub diff_lists {
    my ( $art1, $art2, $red1, $red2 ) = @_;
    my $art1_only = {};
    my $art2_only = {};
    my $common    = {};
    my $redscore  = 0;

    foreach my $title ( keys %$art1 ) {
        if ( $art2->{$title} ) {
            $common->{$title} = 1;
            delete $art1->{$title};
            delete $art2->{$title};
        }
        elsif ( $red2->{$title} ) {
            $common->{$title} = 1;
            delete $art1->{$title};
            delete $red2->{$title};
            $redscore++;
        }
        else {
            $art1_only->{$title} = unisort_key($title);
            delete $art1->{$title};
        }
    }

    foreach my $title ( keys %$art2 ) {
        if ( $red1->{$title} ) {
            $common->{$title} = 1;
            delete $art2->{$title};
            delete $red1->{$title};
            $redscore++;
        }
        else {
            $art2_only->{$title} = unisort_key($title);
            delete $art2->{$title};
        }
    }

    return ( $art1_only, $art2_only, $common, $redscore );
}

# Output a list of articles in wiki code with a link to the other wiktionary
sub write_list {
    my ( $list, $file, $lang ) = @_;
    open( LISTE, ">$file" ) or die "Couldn't write $file: $!";
    foreach my $article ( sort { $list->{$a} cmp $list->{$b} } keys %$list ) {
        next if not $article;
        print LISTE "$article\n";
    }
    close(LISTE);
}

###################
# MAIN
init();

# Get list from the first Wiktionary
step "Parse $opt{l} Wiktionary: ";
my $lang_section_1 = prepare_language_section( $opt{l}, $opt{c} );
my ( $articles_1, $redirect_1 ) = get_articles_list( $opt{i}, $lang_section_1 );
print_value( "\t%d articles in $opt{c}", $articles_1 );
print_value( "\t%d redirects",           $redirect_1 );

# Get list from the second Wiktionary
step "Parse $opt{L} Wiktionary: ";
my $lang_section_2 = prepare_language_section( $opt{L}, $opt{c} );
my ( $articles_2, $redirect_2 ) = get_articles_list( $opt{I}, $lang_section_2 );
print_value( "\t%d articles in $opt{c}", $articles_2 );
print_value( "\t%d redirects",           $redirect_2 );

# Disable redirect matching?
if ( $opt{R} ) {
    $redirect_1 = {};
    $redirect_2 = {};
}

# Compare
step "Compare:";
my ( $first_only, $second_only, $common, $redirect_count ) =
  diff_lists( $articles_1, $articles_2, $redirect_1, $redirect_2 );
print_value( "\t%d articles only in $opt{l}",      $first_only );
print_value( "\t%d articles only in $opt{L}",      $second_only );
print_value( "\t%d articles in common",            $common );
print_value( "\t%d articles matched to redirects", $redirect_count );

# Write lists
if ( $opt{o} ) {
    step "Write the articles found only in $opt{l} Wiktionary";
    write_list( $first_only, $opt{o}, $opt{l} );
}
if ( $opt{O} ) {
    step "Write the articles found only in $opt{L} Wiktionary";
    write_list( $second_only, $opt{O}, $opt{L} );
}

__END__

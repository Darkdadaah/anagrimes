#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;
use Data::Dumper;

# Need utf8 compatibility for input/outputs
use utf8;
use open ':encoding(utf8)';
binmode STDOUT, ":encoding(utf8)";
binmode STDERR, ":encoding(utf8)";

# Useful Anagrimes libraries
use FindBin;
use lib $FindBin::Bin . '/../lib';
use wiktio::basic;
use wiktio::string_tools qw(ascii ascii_strict anagramme);
use wiktio::dump_reader;
use wiktio::parser qw(parseArticle parseLanguage parseType);

# To filter the bots
# Hard-coded list for fr.wikt
our @bots_names =
  qw(Bot-Jagwar BotMoyogo BotdeSki ChuispastonBot Cjlabot Daahbot Fenkysbot GaAsBot GedawyBot JackBot KamikazeBot LmaltierBot Luckas-bot MalafayaBot MediaWiki MenasimBot MglovesfunBot VolkovBot WarddrBOT WikitanvirBot タチコマ);

our %opt;    # Getopt options

#################################################
# Message about this program and how to use it
sub usage {
    print STDERR "[ $_[0] ]\n" if $_[0];
    print STDERR << "EOF";
	
	This script parses a Wiktionary dump and extracts article names.
	
	usage: $0 [-h] -f file
	
	-h        : this (help) message
	
	INPUT
	-i <path> : dump path
	
	OUTPUT
	-o <path> : list of all the articles selected
	-O <path> : list of all articles with the pattern but excluded
	
	NB: if no output is defined, only the final count will be shown
	
	FILTER
	-p <str>  : regexp pattern to search
	-n <str>  : regexp pattern to exclude
	
	-S <str>  : use this namespace (default: main namespace)
	-s        : use all namespaces
	
	-A <str>  : only edited by (one or several separated by a comma): bot,IP,nouser,user
	-H        : search the whole history of the articles
	
	-L <str>  : language to include only
	-N <str>  : language to exclude
	
	example:
	# Search the section language templates {{=xxx=}} but exclude {{=fr=}}
	$0 -i data/frwikt.xml -p "\{\{=(.+)=\}\}" -n "\{\{=(.+)=\}\}"
EOF
    exit;
}

##################################
# Command line options processing
sub init() {
    getopts( 'hi:o:O:p:n:S:sA:HL:N:', \%opt ) or usage();
    %opt = %{ to_utf8( \%opt ) };
    usage() if $opt{h};
    usage("Dump path needed (-i)") if not $opt{i};
    if ( not $opt{F} ) {
        usage("Only 1 language option (-L|-N)") if $opt{L} and $opt{N};
    }

    if ( $opt{o} ) {
        open( ARTICLES, "> $opt{o}" ) or die "Couldn't write $opt{o}: $!\n";
        close(ARTICLES);
    }
    if ( $opt{O} ) {
        open( ARTICLES, "> $opt{O}" ) or die "Couldn't write $opt{O}: $!\n";
        close(ARTICLES);
    }
}

##################################
# SUBROUTINES

# Prepare author list as a hash
sub prepare_authors_list {
    my $auth_text = shift;
    my %auth      = ();
    if ($auth_text) {
        for ( split /,/, $auth_text ) {
            $auth{'nouser'} = 1 if /^nousers?$/;
        }
    }
    return \%auth;
}

# Correct the html to be able to match < > "
sub rewrite_html {
    my $p = shift;
    if ($p) {
        $p =~ s/&lt;/</g;
        $p =~ s/&gt;/>/g;
        $p =~ s/&quot;/"/g;
    }
    return $p;
}

# Parse a dump
sub get_articles_list {
    my ($par) = @_;
    my %p = %$par;

    my %counts = (
        'total articles'   => 0,
        'matched articles' => 0,
        'redirects'        => 0,
    );

    my $dump_fh = open_dump( $p{'dump_path'} );

    $| = 1;
  ARTICLE: while ( my $article = parse_dump( $dump_fh, $par ) ) {
        $counts{'total articles'}++;

        # No article title?
        next ARTICLE if ( not defined( $article->{'fulltitle'} ) );

        # Only for a given namespace? Default: main
        if ( defined( $p{'namespace'} ) ) {
            my $ns = $p{'namespace'};

            # Number? Number of namespace
            if ( $ns =~ /^[0-9]+$/ ) {
                if ( $article->{'ns'} != $ns ) {
                    next ARTICLE;
                }

                # String: name of a namespace
            }
            else {
                if ( $article->{'namespace'} ne $ns ) {
                    next ARTICLE;
                }
            }

            # No namespace given: skip if not in the main
        }
        elsif ( defined( $article->{'namespace'} )
            and not $p{'all_namespaces'} )
        {
            next ARTICLE;
        }
        print STDERR
"[$counts{'total articles'}] [$counts{'matched articles'}] $article->{'fulltitle'}                           \r"
          if $counts{'total articles'} % 1000 == 0;

        # TO IMPROVE
        # Selected authors?
        if ( $p{'authors'}->{'nouser'} ) {
            my %auth = %{ $p{'authors'} };
            foreach my $author ( keys %auth ) {

                # Check bots names
                delete $auth{$author} if $author ~~ @bots_names;

                # Check IPs
                delete $auth{$author} if $author =~ /:/;
            }

            # Continue only if there are users left
            if ( keys %auth == 0 ) {
                next ARTICLE;
            }
        }

        # Now look at the content

        # Redirect?
        if ( defined( $article->{'redirect'} ) ) {
            redirect($article);
            $counts{'redirects'}++;

            # or Article
        }
        else {
            $counts{'matched articles'} +=
              article_count_and_print( $article, $par );
        }
    }
    $| = 0;
    print STDERR "\n";
    close($dump_fh);

    # Print stats
    print_counts( \%counts );
}

#----------------------------------
# REDIRECTS in case there is something to do in a redirect page (by default: nothing)
sub redirect {
    my ($article) = @_;

}

#----------------------------------
# ARTICLE
# Search the given article with every provided pattern
sub article_count_and_print {
    my ( $article, $par ) = @_;

    my $count = 0;
    $count += read_article( $article, $par );

    return $count;
}

#----------------------------------
sub read_article {
    my ( $article, $par ) = @_;
    my %p = %$par;

    # We want to first retrieve the text to search
    my $art_text = ();

    # Search in a language section?
    if ( $p{'lang'} ) {
        my $lang_text =
          parseArticle( $article->{'content'}, $article->{'title'} );

        # Found the language section?
        if ( $lang_text->{'language'}->{ $p{'lang'} } ) {
            $art_text = $lang_text->{'language'}->{ $p{'lang'} };

            # No: skip this article
        }
        else {
            return 0;
        }
    }

    # Exclude a language section?
    elsif ( $p{'nolang'} ) {
        my $lang_text =
          parseArticle( $article->{'content'}, $article->{'title'} );

        # Found the language section? If so: exclude it from the search
        if ( $lang_text->{'language'}->{ $p{'nolang'} } ) {
            delete $lang_text->{'language'}->{ $p{'nolang'} };
        }

        # Any language section left to search?
      LANGSEC: foreach my $l ( keys %{ $lang_text->{'language'} } ) {
            if ( not ref( $lang_text->{'language'}->{$l} ) eq 'ARRAY' ) {
                print STDERR
                  "[[$article->{'title'}]]\tSection de langue vide : $l\n";
                next LANGSEC;
            }

            # Concat all lines from other sections
            push @$art_text, @{ $lang_text->{'language'}->{$l} };
        }

    }
    else {
        $art_text = $article->{'content'};
    }

    my ( $count,      $n )          = ( 0,  0 );
    my ( $ok,         $no )         = ( 0,  0 );
    my ( $ok_pattern, $no_pattern ) = ( '', '' );

    # Search for those patterns in the article
    if ( $p{'pat'} or $p{'nopat'} ) {
        foreach my $line (@$art_text) {
            $line = rewrite_html($line);
            $n++;

            # Skip article if found a forbidden pattern
            if ( $opt{n} and $line =~ /($opt{n})/ ) {
                $no_pattern = "<tt><nowiki>$1</nowiki></tt> ($n)";
                $no         = 1;
            }

            # Found pattern?
            if ( $p{'pat'} and $line =~ /($p{'pat'})/ ) {
                $count++ if not $no;
                $ok_pattern = "<tt><nowiki>$1</nowiki></tt> ($n)";
                $ok         = 1;
                $line =~ s/$p{'pat'}//;

                # Continue to see how much of this pattern we can find
                my $len = length($line);
                while ( $p{'pat'} and $line =~ /($p{'pat'})/ ) {
                    $count++ if not $no;
                    $ok_pattern .= " ; <tt><nowiki>$1</nowiki></tt> ($n)";
                    $line =~ s/$p{'pat'}//;

                    # Break if there is no replacement
                    my $len2 = length($line);
                    if ( $len == $len2 ) {
                        last;
                    }
                }
            }
        }

        # Print articles where the pattern was found
        if ( $ok and not $no and $p{'output_path'} ) {
            $ok_pattern =~ s/\n/\\n/g;
            $ok_pattern =~ s/\r/\\r/g;
            open( ARTICLES, ">> $p{'output_path'}" )
              or die "Couldn't write $p{'output_path'}: $!\n";
            my @line = ("[[$article->{'fulltitle'}]]");
            push @line, $ok_pattern;
            print ARTICLES join( "\t", @line ) . "\n";
            close(ARTICLES);
        }

        # Print articles where the anti-pattern was found
        if ( $ok and $no and $p{'output_rejected_path'} ) {
            $no_pattern =~ s/\n/\\n/g;
            $no_pattern =~ s/\r/\\r/g;
            open( ARTICLES, ">> $p{'output_rejected_path'}" )
              or die "Couldn't write $p{'output_rejected_path'}: $!\n";

            my @line = ("[[$article->{'fulltitle'}]]");
            push @line, $ok_pattern;
            push @line, $no_pattern;
            print ARTICLES join( "\t", @line ) . "\n";
            close(ARTICLES);
        }

        # No pattern: only count/list the article name
    }
    else {
        $count++ if not $no;

        # Print the list?
        if ( $p{'output_path'} ) {
            open( ARTICLES, ">> $p{'output_path'}" )
              or die "Couldn't write $p{'output_path'}: $!\n";

            my @line = ( $article->{'fulltitle'} );
            print ARTICLES join( "\t", @line ) . "\n";
            close(ARTICLES);
        }
    }

    return $count;
}

# Print the stats
sub print_counts {
    my $counts = shift;
    foreach my $c ( sort keys %$counts ) {
        print_value( "$c: %d", $counts->{$c} );
    }
}

###################
# MAIN
init();

# Prepare lists
my %par = ();
$par{'namespace'}            = $opt{S};
$par{'all_namespaces'}       = $opt{s};
$par{'dump_path'}            = $opt{i};
$par{'output_path'}          = $opt{o};
$par{'output_rejected_path'} = $opt{O};
$par{'authors'}              = prepare_authors_list( $opt{A} );
$par{'lang'}                 = $opt{L};
$par{'nolang'}               = $opt{N};
$par{'pat'}                  = $opt{p};
$par{'nopat'}                = $opt{n};
$par{'whole_history'}        = $opt{H};

# Get data from dump
my $art_count = get_articles_list( \%par );

__END__

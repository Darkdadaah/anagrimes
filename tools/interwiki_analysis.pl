#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;

# Need utf8 compatibility for input/outputs
use utf8;
use open ':encoding(utf8)';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use Encode qw(decode);    # Needed?

use lib '..';
use wiktio::basic;
use wiktio::string_tools qw( ascii );
use wiktio::dump_reader;
our %opt;                 # Getopt options

# Codes to skip (not language codes)
our %EXCEPT = map { $_ => 1 } qw( ws doi );

#################################################
# Message about this program and how to use it
sub usage {
    print STDERR "[ $_[0] ]\n" if $_[0];
    print STDERR << "EOF";

    This script parses a Wiktionary dump and analyzes interwiki usage.

    usage: $0 [-h] -f file

    -h        : this (help) message

    INPUT
    -i <path> : dump path
    -l <str>  : language code of the wiki

    OUTPUT
    STDOUT    : list of pages with differing interwiki link
EOF
    exit;
}

##################################
# Command line options processing
sub init() {
    getopts( 'hi:l:', \%opt ) or usage();
    usage() if $opt{h};
    usage("Dump path needed (-i)") if not $opt{i};

    if ( not $opt{l} ) {
        my $lang;
        if ( $opt{i} =~ /(?:\/|^)([a-z]{2,3})wikt/ ) {
            $lang = $1;
        }
        if ( defined $lang ) {
            $opt{l} = $lang;
        }
        else {
            usage("Wiki language code needed -l");
        }
    }
}

sub interwiki_analyze {
    my ( $title, $lines, $count, $dump_lang ) = @_;

    # Extract interwikis
    my %iw = ();
    foreach my $line (@$lines) {
        my $full_line = $line;
        $full_line =~ s/\]\]/]]\n/g;
        $full_line =~ s/\[\[/\n[[/g;
        my @elements = split /\n/, $full_line;

        foreach my $elt (@elements) {
            if ( $elt =~ /^ *\[\[ *([a-z]{2,3}) *: *(.+) *\]\] *$/ ) {
                $iw{$1} = $2;
            }
        }
    }

    # Analyze the data
    if ( keys %iw > 0 ) {
        foreach my $l ( sort keys %iw ) {

            # Skip some codes that are not language codes
            next if defined $EXCEPT{$l};

            my $t = $iw{$l};

            if ( $t ne $title ) {

                # Lots of wikis use PAGENAME to create the interwikis
                next if $t =~ /\{\{ *PAGENAME *\}\}/;

                # apostrophe?
                my $t2     = $t;
                my $title2 = $title;
                $t2 =~ s/['ʼ’]/'/g;
                $title2 =~ s/['ʼ’]/'/g;

                # Diacritics?
                my $title_dia = ascii($title);
                my $t_dia     = ascii($t);

                # Capital?
                my $t3     = uc($t);
                my $title3 = uc($title);

                # Apostrophe + Capital?
                my $t4     = uc($t2);
                my $title4 = uc($title2);

                # Hyphen
                my $th = $t;
                $th =~ s/[- ]+//g;
                my $titleh = $title;
                $titleh =~ s/[- ]+//g;

                # Punctuation
                my $tp = $t;
                $tp =~ s/\W+//g;
                my $titlep = $title;
                $titlep =~ s/\W+//g;

                # Category of difference?
                my $cat = '';
                if ( $t =~ /^\s*$/ ) {
                    $count->{interwiki_wrong_empty}++;
                    $cat = 'empty';
                }
                elsif ( $t2 eq $title2 ) {
                    $count->{interwiki_wrong_apostrophe}++;
                    $cat = 'apostrophe';
                }
                elsif ( $t3 eq $title3 ) {
                    $count->{interwiki_wrong_capital}++;
                    $cat = 'capital';
                }
                elsif ( $t4 eq $title4 ) {
                    $count->{interwiki_wrong_apostrophe_and_capital}++;
                    $cat = 'apostrophe_capital';
                }
                elsif ( index( $t, $title ) != -1 ) {
                    $count->{interwiki_wrong_partial_title}++;
                    $cat = 'partial_title';
                }
                elsif ( index( $title, $t ) != -1 ) {
                    $count->{interwiki_wrong_part_of_title}++;
                    $cat = 'part_of_title';
                }
                elsif ( $titleh eq $th ) {
                    $count->{interwiki_wrong_hyphen}++;
                    $cat = 'hyphen';
                }
                elsif ( $title eq $t . "." ) {
                    $count->{interwiki_wrong_endpoint}++;
                    $cat = 'endpoint';
                }
                elsif ( $t eq $title . "." ) {
                    $count->{interwiki_wrong_endpoint_of}++;
                    $cat = 'endpoint_of';
                }
                elsif ( $titlep eq $tp ) {
                    $count->{interwiki_wrong_notletter}++;
                    $cat = 'notletter';
                }
                elsif ( $t =~ /:/ ) {
                    $count->{interwiki_wrong_colon}++;
                    $cat = 'colon';
                }
                elsif ( $t_dia eq $title_dia ) {
                    $count->{interwiki_wrong_diacritics}++;
                    $cat = 'diacritics';
                }
                else {
                    $count->{interwiki_wrong_other}++;
                    $cat = 'other';
                }
                delete $iw{$l};
                print STDOUT "$dump_lang\t$l\t$title\t$t\t$cat\n";
            }
        }
        $count->{interwiki_correct}++ if keys %iw > 0;

    }
    else {
        $count->{interwiki_none}++;
    }
}

###################
# MAIN
init();

my $dump_fh = open_dump( $opt{i} );
my $title   = '';
my ( $n, $redirect ) = ( 0, 0 );
my $complete_article = 0;
my %already          = ();
my @article          = ();
my $count            = {};

$| = 1;
while (<$dump_fh>) {
    if (/<title>(.+?)<\/title>/) {
        $title = $1;
        $title = '' if $title =~ /[:\/]/;

    }
    elsif ( $title and /<text xml:space="preserve">(.*?)<\/text>/ ) {
        @article = ();
        push @article, "$1\n";
        $complete_article = 1;

    }
    elsif ( $title and /<text xml:space="preserve">(.*?)$/ ) {
        @article = ();
        push @article, "$1\n";
        while (<$dump_fh>) {
            next if /^\s+$/;
            if (/^(.*?)<\/text>/) {
                push @article, "$1\n";
                last;
            }
            else {
                push @article, $_;
            }
        }
        $complete_article = 1;
    }
    if ($complete_article) {
        if ( $article[0] =~ /#redirect/i ) {
            $count->{redirect}++;
        }
        else {
            ######################################
            # Traiter les articles ici
            interwiki_analyze( $title, \@article, $count, $opt{l} );
            ######################################
            $count->{articles}++;

#print STDERR "[$count->{articles}] $title                                         \r" if $count->{articles}%1000==0;
        }
        $complete_article = 0;
    }
}
$| = 0;
print STDERR "\n";
close($dump_fh);

foreach my $c ( sort keys %$count ) {
    printf STDERR "%9d  %s\n", $count->{$c}, $c;
}

__END__

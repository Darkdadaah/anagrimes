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
use lib $FindBin::Bin . '/../lib';
use wiktio::string_tools qw(ascii);
use wiktio::basic;
use wiktio::dump_reader;
our %opt;    # Getopt options

#################################################
# Message about this program and how to use it
sub usage {
    print STDERR "[ $_[0] ]\n" if $_[0];
    print STDERR << "EOF";

    This script extracts templates data (special context template for fr.wikt)

    -h        : this (help) message
    -i <path> : input dump path (compressed or not)
    -o <path> : list of templates (Lua format)
EOF
    exit;
}

##################################
# Command line options processing
sub init() {
    getopts( 'hi:o:', \%opt ) or usage();
    %opt = %{ to_utf8( \%opt ) };
    usage()                               if $opt{h};
    usage("Dump path needed (-i)")        if not $opt{i};
    usage("Output file path needed (-o)") if not $opt{o};
}

###################################
# PARSERS

sub parse_articles {
    my ( $dump_path, $outpath ) = @_;

    # Scan every line of the dump
    my $dump_fh = dump_open($dump_path);
    open( my $out_fh, ">" . $outpath ) or die "Couldn't write '$outpath': $!\n";

  ARTICLE: while ( my $article = parse_dump($dump_fh) ) {
        next if not defined( $article->{'ns'} );
        next ARTICLE if $article->{'ns'} != 10;    # Only templates
        print STDERR ".";

        if ( $article->{'redirect'} ) {

# Only parse redirects if there is no specific target language (because redirects have no language)
            next;
        }
        else {
            # Fully parse the article
            parse_template2( $article, $out_fh );
        }
    }
    print STDERR "\n";
    close($dump_fh);
}

###################################
# ARTICLES PARSER
sub parse_template1 {
    my ( $article, $out_fh ) = @_;

    # Extract data from the template
    my %data = (
        'type'      => '',
        'nom'       => '',
        'id'        => '',
        'cat'       => '',
        'lien'      => '',
        'glossaire' => ''
    );
    my $n = 0;
    foreach my $line ( @{ $article->{'content'} } ) {
        $n++;
        chomp($line);
        if ( $n == 1 and $line =~ /^\{\{ *(.+?) *\|([^\}]+?)\|?$/ ) {
            $data{'type'} = $1;
            $data{'nom'}  = $2;
            next;
        }
        elsif ( $n == 1 and $line =~ /^\{\{ *(.+?) *\|?$/ ) {
            $data{'type'} = $1;
            next;
        }
        elsif ( not $data{'type'} ) {
            return;
        }

        if ( $line =~ /^\| *1 *= *(.+?) *$/ ) {
            $data{'nom'} = $1;
        }
        elsif ( $line =~ /^\| *2 *= *(.+?) *$/ ) {
            $data{'glossaire'} = $1;
        }
        elsif ( $line =~ /^\| *id *= *(.+?) *$/ ) {
            $data{'id'} = $1;
        }
        elsif ( $line =~ /^\| *cat *= *(.+?) *$/ ) {
            $data{'cat'} = $1 . ' en %s';
        }
        elsif ( $line =~ /^\| *catfin *= *(.+?) *$/ ) {
            $data{'cat'} .= ' ' . $1;
        }
        else {
            #warn $line;
        }
    }

    print_data1( $article->{'title'}, \%data, $out_fh );
}

sub print_data1 {
    my ( $title, $data, $out_fh ) = @_;
    my @elts = qw(nom cat id lien glossaire);
    my @line = ();
    foreach my $e (@elts) {
        if ( $data->{$e} ) {
            push @line, "$e = '$data->{$e}'";
        }
    }
    print $out_fh "c['$title'] = { ";
    print $out_fh join( ', ', @line );
    print $out_fh " }\n";
}

sub parse_template2 {
    my ( $article, $out_fh ) = @_;

    # Extract data from the template
    my %data = (
        'type' => 'région',
        'nom'  => '',
        'id'   => '',
        'cat'  => '',
    );
    my $n = 0;
    foreach my $line ( @{ $article->{'content'} } ) {
        $n++;
        chomp($line);
        if ( $line =~
/\{\{ *région *\| *([^\}]+?) *\| *\{.+\} *\| *([^\}]+?) *\| *nocat.+/
          )
        {
            $data{'nom'} = $1;
            $data{'cat'} = "% " . $2;
        }
        elsif (
            $line =~ /\{\{ *région *\| *([^\}]+?) *\| *\{.+\} *\| *nocat.+/ )
        {
            $data{'nom'} = $1;
            $data{'cat'} = "% de " . $1;
        }
        elsif ( $line =~ /\{\{ *région *\| *([^\}]+?) *\}\}/ ) {
            $data{'nom'} = $1;
            $data{'cat'} = "% de " . $1;
        }
    }

    print_data2( $article->{'title'}, \%data, $out_fh );
}

sub print_data2 {
    my ( $title, $data, $out_fh ) = @_;
    my @elts = qw(nom cat);
    my @line = ();
    foreach my $e (@elts) {
        if ( $data->{$e} ) {
            push @line, "$e = '$data->{$e}'";
        }
    }
    print $out_fh "c['$title'] = { ";
    print $out_fh join( ', ', @line );
    print $out_fh " }\n";
}

###################
# MAIN
init();

# Actual parsing of the dumps
parse_articles( $opt{i}, $opt{o} );

__END__


#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;
use DBI;
use XML::Writer;
use Encode;
use Data::Dumper;

our %opt;    # Getopt options

my %lang_data = (
    'fr' => { '3' => 'FRE', 'full' => 'français' },
    'it' => { '3' => 'ITA', 'full' => 'italien' },
    'en' => { '3' => 'ENG', 'full' => 'anglais' },
);

my %abbrev = (
    'nom'     => 'nom commun',
    'adj'     => 'adjectif',
    'verb'    => 'verbe',
    'adverbe' => 'adverbe',

    'm'   => 'masculin',
    'f'   => 'féminin',
    'mf'  => 'masculin et féminin',
    'mf?' => "masculin et féminin, l'usage hésite",
    'n'   => 'neutre',
);

#################################################
# Message about this program and how to use it
sub usage {
    print STDERR "[ $_[0] ]\n" if $_[0];
    print STDERR << "EOF";
	
	This script exports a given language dictionary in xdxf format.
	
	-h        : this (help) message
	-d <path> : database path
	
	# Export one language
	-l <str>  : language code
	-o <path> : output file path
	
	OR
	
	# Export all languages (one file each)
	-L <num>  : minimum number of articles in the language [optional]
	-O <path> : output dir (many contain a lot of files!)
EOF
    exit;
}

##################################
# Command line options processing
sub init() {
    getopts( 'hd:l:o:L:O:', \%opt ) or usage();
    usage() if $opt{h};
    usage("Database needed (-d)") unless $opt{d};
    if ( $opt{o} or $opt{l} ) {
        usage("Language code needed (-l)") unless $opt{l};
        usage("Output path needed (-o)")   unless $opt{o};
    }
    elsif ( $opt{O} or $opt{L} ) {
        usage("Output dir path needed (-O)") unless $opt{O};
    }
    else {
        usage();
    }
}

sub get_langs {
    my ( $dbh, $max_lang ) = @_;
    my $conditions = "";
    $max_lang = 0 if not defined($max_lang);
    $conditions = "WHERE lg_num > ?";
    my $query = "SELECT lg_lang FROM langs $conditions";
    return $dbh->selectcol_arrayref( $query, undef, $max_lang );
}

sub get_definitions {
    my ( $dbh, $lang ) = @_;
    my $conditions = "l_lang=?";
    my $query =
"SELECT * FROM deflex WHERE $conditions ORDER BY a_title_flat, a_title, l_lexid, l_num, d_num";
    my $defs = $dbh->selectall_arrayref( $query, { Slice => {} }, $lang );

    return format_defs($defs);
}

sub format_defs {
    my ($defs) = @_;

    # Group together lines with the same lexid and fuse
    # all definitions for each lexid
    my %fused = ();
    foreach my $line (@$defs) {
        next if not $line->{'d_def'};
        my $lexid = $line->{'l_lexid'};
        if ( not defined( $fused{$lexid} ) ) {
            $fused{$lexid} = $line;
        }
        push @{ $fused{$lexid}{'defs'} }, $line->{'d_def'};
    }

    my @lexemes = ();
    foreach my $line (@$defs) {
        my $lexid = $line->{'l_lexid'};
        if ( $fused{$lexid} ) {
            delete $fused{$lexid}{'d_def'};
            push @lexemes, $fused{$lexid};
            delete $fused{$lexid};
        }
    }

    #print STDERR (0 + @lexemes) . " lexemes\n";

    return \@lexemes;
}

sub write_xdxf {
    my ( $outpath, $lexemes, $lang ) = @_;

    my $out = IO::File->new(">$outpath");
    my $dico =
      XML::Writer->new( OUTPUT => $out, DATA_MODE => 1, DATA_INDENT => "\t" );
    $dico->startTag(
        "xdxf",
        "lang_from" => trilang($lang),
        "lang_to"   => "FRE",
        "format"    => "logical",
        "version"   => "DD"
    );

    # Prepare meta
    my $langue = fullang($lang);
    my %meta   = (
        'title'      => "Wiktio_$lang" . "_fr",
        'full_title' => $lang eq 'fr' ? "Wiktionnaire du français"
        : "Wiktionnaire : $langue - français",
        'description' => $lang eq 'fr' ? "Wiktionnaire du français"
        : "Wiktionnaire de mots en $langue décrits en français.",
    );

    $dico->startTag("meta_info");
    foreach my $elt ( keys %meta ) {
        $dico->startTag($elt);
        $dico->characters( $meta{$elt} );
        $dico->endTag($elt);
    }

    # Abbrev
    $dico->startTag("abbreviations");
    foreach my $abbr ( keys %abbrev ) {
        $dico->startTag("abbr_def");
        $dico->startTag("abbr_k");
        $dico->characters($abbr);
        $dico->endTag("abbr_k");
        $dico->startTag("abbr_v");
        $dico->characters( $abbrev{$abbr} );
        $dico->endTag("abbr_v");
        $dico->endTag("abbr_def");
    }
    $dico->endTag("abbreviations");
    $dico->endTag("meta_info");

    # List of words
    $dico->startTag("lexicon");
    foreach my $lex (@$lexemes) {
        next if @{ $lex->{'defs'} } == 0;
        $dico->startTag("ar");

        # Keyword
        $dico->startTag("k");
        $dico->characters( $lex->{'a_title'} );
        $dico->endTag("k");

        # Grammar
        $dico->startTag("def");
        $dico->startTag("gr");

        # Word type
        $dico->startTag("abbr");
        $dico->characters( $lex->{'l_type'} );
        $dico->endTag("abbr");

        # grammar (if any)
        if ( $lex->{'l_genre'} ) {
            $dico->startTag("abbr");
            $dico->characters( $lex->{'l_genre'} );
            $dico->endTag("abbr");
        }
        $dico->endTag("gr");

        # Defs
        foreach my $def ( @{ $lex->{'defs'} } ) {
            $dico->startTag("def");
            $dico->characters($def);
            $dico->endTag("def");
        }
        $dico->endTag("def");
        $dico->endTag("ar");
    }
    $dico->endTag("lexicon");
    $dico->endTag("xdxf");
    $dico->end();
    $out->close();
}

sub trilang {
    my ($lang) = @_;
    if ( $lang_data{$lang} ) {
        return ${ $lang_data{$lang} }{3};
    }
    else {
        return $lang;
    }
}

sub fullang {
    my ($lang) = @_;
    if ( $lang_data{$lang} ) {
        return $lang_data{$lang}{'full'};
    }
    else {
        return $lang;
    }
}

sub export_xdxf {
    my ( $dbh, $lang, $outpath ) = @_;

    my $lexemes = get_definitions( $dbh, $lang );
    write_xdxf( $outpath, $lexemes, $lang );
}

##################################
# MAIN
init();

my $dbh = DBI->connect( "dbi:SQLite:dbname=$opt{d}", "", "" );
if ( $opt{o} and $opt{l} ) {
    export_xdxf( $dbh, $opt{l}, $opt{o} );
}
elsif ( $opt{O} ) {
    my $langs = get_langs( $dbh, $opt{L} );
    print STDERR ( 0 + @$langs ) . " languages\n";
    foreach my $l (@$langs) {
        my $outpath = "$opt{O}/$l.xdxf";
        print STDERR "$l ";
        export_xdxf( $dbh, $l, $outpath );
    }
    print STDERR "\n";
}
__END__


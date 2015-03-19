#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;
use DBI;
use XML::Writer;
use Encode;
use Data::Dumper;

our %opt;	# Getopt options

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0];
	print STDERR << "EOF";
	
	This script exports a given language dictionary in xdxf format.
	
	-h        : this (help) message
	-d <path> : database path
	
	-l <str>  : language code
	-o <path> : output file path
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hd:l:o:', \%opt ) or usage();
	usage() if $opt{h};
	usage("Database needed (-d)") unless $opt{d};
	usage("Language code needed -l") unless $opt{l};
	usage("Output path needed (-o)") unless $opt{o};
}

sub get_definitions
{
	my ($dbh, $lang) = @_;
	my $conditions = "l_lang=?";
	my $query = "SELECT * FROM deflex WHERE $conditions ORDER BY a_title_flat, a_title, l_lexid, l_num, d_num";
	my $defs = $dbh->selectall_arrayref($query, { Slice => {} }, $lang);

	return format_defs($defs);
}

sub format_defs
{
	my ($defs) = @_;

	# Group together lines with the same lexid and fuse
	# all definitions for each lexid
	my %fused = ();
	foreach my $line (@$defs) {
		next if not $line->{'d_def'};
		my $lexid = $line->{'l_lexid'};
		if (not defined($fused{ $lexid })) {
			$fused{ $lexid } = $line;
		}
		push @{ $fused{ $lexid }{ 'defs' } }, $line->{'d_def'};
	}
	
	print STDERR (0 + @$defs) . " lines\n";
	print STDERR (0 + keys(%fused)) . " lexids\n";

	my @lexemes = ();
	foreach my $line (@$defs) {
		my $lexid = $line->{'l_lexid'};
		if ($fused{ $lexid }) {
			delete $fused{ $lexid }{ 'd_def' };
			push @lexemes, $fused{ $lexid };
			delete $fused{ $lexid };
		}
	}
	print STDERR (0 + @lexemes) . " final lexemes\n";
	
	return \@lexemes;
}

sub write_xdxf
{
	my ($outpath, $lexemes, $lang) = @_;
	
	my $out = IO::File->new(">$outpath");
	my $dico = XML::Writer->new(OUTPUT => $out);#, DATA_MODE => 1, DATA_INDENT => "\t");
	$dico->startTag("xdxf",
		"lang_from" => trilang($lang),
		"lang_to" => "FRE",
		"format" => "logical",
		"version" => "DD"
	);
	# Prepare meta
	my $langue = fullang($lang);
	my %meta = (
		'title' => "Wiktio_$lang"."_fr",
		'full_title' => $lang eq 'fr' ?  "Wiktionnaire du français" : "Wiktionnaire : $langue - français",
		'description' => $lang eq 'fr' ?  "Wiktionnaire du français" : "Wiktionnaire de mots en $langue décrits en français.",
	);

	$dico->startTag("meta_info");
	foreach my $elt (keys %meta) {
		$dico->startTag($elt);
		$dico->characters($meta{$elt});
		$dico->endTag($elt);
	}
	$dico->endTag("meta_info");

	# List of words
	$dico->startTag("lexicon");
	foreach my $lex (@$lexemes) {
		next if @{ $lex->{'defs'} } == 0;
		$dico->startTag("ar");
		# Keyword
		$dico->startTag("k");
		$dico->characters($lex->{'a_title'});
		$dico->endTag("k");
		# Word type
		$dico->startTag("gr");
		$dico->characters($lex->{'l_type'});
		# grammar (if any)
		if ($lex->{'l_genre'}) {
			$dico->characters( " " . $lex->{'l_genre'});
		}
		$dico->endTag("gr");
		# Def
		$dico->startTag("def");
		foreach my $def (@{ $lex->{'defs'} }) {
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

my %lang_data = (
	'fr' => {'3' => 'FRE', 'full' => 'français'},
	'it' => {'3' => 'ITA', 'full' => 'italien'},
	'en' => {'3' => 'ENG', 'full' => 'anglais'},
);

sub trilang
{
	my ($lang) = @_;
	return ${$lang_data{$lang}}{3};
}
sub fullang
{
	my ($lang) = @_;
	return $lang_data{$lang}{'full'};
}

##################################
# MAIN
init();

my $dbh = DBI->connect("dbi:SQLite:dbname=$opt{d}","","");
my $lexemes = get_definitions($dbh, $opt{l});
write_xdxf($opt{o}, $lexemes, $opt{l});
__END__


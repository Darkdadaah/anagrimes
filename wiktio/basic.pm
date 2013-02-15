
# Wiktionnaire bases
# Author: Matthieu Barba
# This module contains basic data and functions for Wiktionary fr
package wiktio::basic ;

use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use Exporter ;
@ISA=('Exporter') ;

@EXPORT = qw(
	$log
	special_log
	dump_input
	$true $false
) ;

@EXPORT_OK = qw(
	$word_type
	$word_type_syn
	$level3
	$level4
	$langues_transcrites
	step
	stepl
) ;

use strict ;
use warnings ;

our $true = 1 ;
our $false = 0 ;

our $log = 'log.txt' ;

sub step { print STDERR $_[0] ? ($_[0] =~ /[\r\n]$/ ? "$_[0]" : "$_[0]\n") : "\n" } ;
sub stepl { print STDERR $_[0] ? "$_[0]" : "" } ;

# Log specific errors in separate files
sub special_log
{
	my ($nom, $titre, $texte, $other) = @_ ;
	
	my $logfile = $log.'_'.$nom ;
	
	open(LOG, ">>$logfile") or die("Couldn't write $logfile: $!") ;
	my $raw_texte = $texte ? $texte : '' ;
	$raw_texte =~ s/\[\[([^\]]+)\]\]/__((__$1__))__/g ;
	$raw_texte .= "\t($other)" if $other ;
	print LOG "* [[$titre]]\t$raw_texte\n" ;
	close(LOG) ;
}

# Change the input to automatically handle file compression
sub dump_input
{
	my $infile = shift;
	
	# Open file (compressed or not)
	my $input = '';
	if ($infile =~ /\.bz2$/) {
		$input = "bzcat $infile |";
	} elsif ($infile =~ /\.gz$/) {
		$input = "gunzip -c $infile |";
	} elsif ($infile =~ /\.xml$/) {
		$input = $infile;
	} else {
		print STDERR "Error: unsupported dump file format or compression: $infile\n";
		exit(1);
	}
	
	return $input;
}

our $level3 = {
	'étymologie' => 'etymologie',
		'étym' => 'etymologie',
		'etym' => 'etymologie',	# Beuh
		'éty' => 'etymologie',	# Beuh
		'étyl' => 'etymologie',	# Beuh
	'pron' => 'prononciation',
	'voir' => 'voir',
	'anagr'  => 'anagrammes',
	'références'  => 'references',
		'réf'  => 'references',
		'ref'  => 'references',
} ;

our $word_type = {
	
	# Noms
	'nom' => 1,
	'nom-sciences' => 1,
	'nom-propre' => 1,
		'nom-pr' => 1,
	'marque' => 1,
	'prénom' => 1,
	'nom-fam' => 1,
	
	'nom-ni' => 1,
	'nom-nu' => 1,
	'nom-nn' => 1,
	'nom-npl' => 1,
	
	# Adjectif qualificatif
	'adjectif' => 1,
		'adj' => 1,
	
	# Verbe
	'verbe' => 1,
		'verb' => 1,
	'verbe-pr' => 1,
		'verb-pr' => 1,
	'aux' => 1,
	
	# Adverbe
	'adverbe' => 1,
		'adv' => 1,
	'adv-pron' => 1,
	'adv-rel' => 1,
	'adv-int' => 1,
	
	# Conjonction
	'conj' => 1,
	'conj-coord' => 1,
	
	# Prépositions
	'prep' => 1,
	'prép' => 1,
	
	# Pronom
	'pronom' => 1,
	'pronom-déf' => 1,
		'pronom-def' => 1,
	'pronom-indéf' => 1,
		'pronom-indef' => 1,
	'pronom-int' => 1,
	'pronom-pers' => 1,
	'pronom-pos' => 1,
	'pronom-réfl' => 1,
		'pronom-refl' => 1,
	'pronom-rel' => 1,
	'pronom-dém' => 1,
		'pronom-dem' => 1,
	
	# Adjectifs déterminants
	'adj-dém' => 1,
		'adj-dem' => 1,
	'adj-excl' => 1,
	'adj-indéf' => 1,
		'adj-indef' => 1,
	'adj-int' => 1,
	'adj-num' => 1,
	'adj-pos' => 1,
	
	# Articles
	'art' => 1,
	'art-déf' => 1,
		'art-def' => 1,
	'art-indéf' => 1,
		'art-indef' => 1,
	'art-part' => 1,
	
	# Parties
	'aff' => 1,
	'suf' => 1,
	'préf' => 1,
		'pref' => 1,
	'post' => 1,
	'inf' => 1,
	'circonf' => 1,
	'particule' => 1,
		'part' => 1,
	'radical' => 1,
	'racine' => 1,
	'part-num' => 1,
	
	# Phrases et locutions
	'loc' => 1,
	'phr' => 1,	# loc-phr
		'phrase' => 1,
	'prov' => 1,
	
	# Exclamations
	'interjection' => 1,
		'interj' => 1,
	'onomatopée' => 1,
		'onom' => 1,
		'onoma' => 1,
	
	# Caractères
	'lettre' => 1,
	'symbole' => 1,
		'symb' => 1,
	'class' => 1,
	'numéral' => 1,
	'numér' => 1,
	'sinogramme' => 1,
	
	# Désuets
	'corrélatif' => 2,
	'abr' => 2,
	'cont' => 2,
	'sigle' => 2,
	
	# Beuh
	'erreur' => 2,
	'var-typo' => 2,
	#'drv' => 2,
} ;

our $word_type_syn = {
	'verbe' => 'verb',
	'verbe-pr' => 'verb-pr',
	'numér' => 'numéral',
	'part' => 'particule',
	'pref' => 'préf',
	'adj' => 'adjectif',
	'adverbe' => 'adv',
	'prep' => 'prép',
} ;

our $level4 = {
	'ortho-alt' => 1,
	'ortho-arch' => 1,
	'synonymes' => 1,
		'syn' => 1,
	'q-syn' => 1,
	'ant' => 1,
		'anto' => 1,
	'gent' => 1,
	'hyper' => 1,
	'hypo' => 1,
	'holo' => 1,
	'tropo' => 1,
	'méro' => 1,
	'mero' => 1,
	'drv' => 1,
		'dérivés' => 1,
	'drv-int' => 1,
	'apr' => 1,
		'app' => 1,
	'exp' => 1,
	'compos' => 1,
	'var' => 1,
	'var-ortho' => 1,
	'dimin' => 1,	# Diminutif -< prénom
	'nom-vern' => 1, # Nom vernaculaire
	'dial' => 1,
	'trad' => 1,
	'voc' => 1,
	'note' => 1,
		# alias rem
		# alias notes
	'homo' => 1,
		'homophones' => 1,
	'paronymes' => 1,
		'paro' => 1,
	'anagr' => 1,
		'anagrammes' => 1,
	'abrév' => 1,
		'abrev' => 1,
	'trans' => 1,	# For numbers only
	'hist' => 1,	# sub étymologie
	'faux-amis' => 1,
	'faux-prov' => 1,
} ;

our $langues_transcrites = {
	'cyrillique' => {'ru'=>1, 'bg'=>1, 'uk'=>1},
	'grec' => {'el'=>1, 'grc'=>1},
	'arabe' => {'ar'=>1, 'fa'=>1},
} ;

1 ;

__END__

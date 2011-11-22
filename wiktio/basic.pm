
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

our $level3 = {
	'étym' => 'etymologie',
	'étymologie' => 'etymologie',
	'etym' => 'etymologie',	# Beuh
	'éty' => 'etymologie',	# Beuh
	'étyl' => 'etymologie',	# Beuh
	'pron' => 'prononciation',
	'voir' => 'voir',
	'anagr'  => 'anagrammes',
	'réf'  => 'references',
} ;

our $word_type = {
	
	# Noms
	'nom' => 1,
	'loc-nom' => 1,
	'flex-nom' => 1,
	'flex-loc-nom' => 1,
	'nom-sciences' => 1,
	'nom-pr' => 1,
	'flex-nom-pr' => 1,
	'marque' => 1,
	'prénom' => 1,
	'flex-prénom' => 1,
	'nom-fam' => 1,
	'flex-nom-fam' => 1,
	
	'nom-ni' => 1,
	'nom-nu' => 1,
	'nom-nn' => 1,
	'nom-npl' => 1,
	
	# Adjectif qualificatif
	'adj' => 1,
	'adjectif' => 1,
	'loc-adj' => 1,
	'flex-adj' => 1,
	'flex-loc-adj' => 1,
	'flex-adjectif' => 1,
	
	# Verbe
	'verb' => 1,
	'verbe' => 1,
	'loc-verb' => 1,
	'loc-verbe' => 1,
	'flex-verb' => 1,
	'flex-verbe' => 1,
	'flex-loc-verb' => 1,
	'flex-loc-verbe' => 1,
	'verb-pr' => 1,
	'verbe-pr' => 1,
	'aux' => 1,
	'flex-aux' => 1,
	
	# Adverbe
	'adv' => 1,
	'adverbe' => 1,
	'loc-adv' => 1,
	'flex-adv' => 1,
	'flex-loc-adv' => 1,
	'adv-pron' => 1,
	'adv-rel' => 1,
	'adv-int' => 1,
	
	# Conjonction
	'conj' => 1,
	'loc-conj' => 1,
	'flex-conj' => 1,
	'conj-coord' => 1,
	
	# Prépositions
	'prep' => 1,
	'prép' => 1,
	'loc-prep' => 1,
	'loc-prép' => 1,
	'flex-prep' => 1,
	'flex-prép' => 1,
	
	# Pronom
	'pronom' => 1,
	'loc-pronom' => 1,
	'flex-pronom' => 1,
	'flex-loc-pronom' => 1,
	'pronom-def' => 1,
	'pronom-déf' => 1,
	'pronom-indef' => 1,
	'pronom-indéf' => 1,
	'flex-pronom-indéf' => 1,
	'pronom-int' => 1,
	'flex-pronom-int' => 1,
	'pronom-pers' => 1,
	'flex-pronom-pers' => 1,
	'pronom-pos' => 1,
	'flex-pronom-pos' => 1,
	'pronom-refl' => 1,
	'pronom-réfl' => 1,
	'pronom-rel' => 1,
	'flex-pronom-rel' => 1,
	'pronom-dem' => 1,
	'pronom-dém' => 1,
	'flex-pronom-dém' => 1,
	
	# Adjectifs déterminants
	'adj-dem' => 1,
	'adj-dém' => 1,
	'flex-adj-dém' => 1,
	'adj-excl' => 1,
	'adj-indef' => 1,
	'adj-indéf' => 1,
	'flex-adj-indéf' => 1,
	'adj-int' => 1,
	'flex-adj-int' => 1,
	'adj-num' => 1,
	'flex-adj-num' => 1,
	'adj-pos' => 1,
	'flex-adj-pos' => 1,
	
	# Articles
	'art' => 1,
	'art-def' => 1,
	'art-déf' => 1,
	'art-indef' => 1,
	'art-indéf' => 1,
	'art-part' => 1,
	'flex-art' => 1,
	'flex-art-def' => 1,
	'flex-art-déf' => 1,
	'flex-art-indef' => 1,
	'flex-art-indéf' => 1,
	'flex-art-part' => 1,
	
	# Parties
	'aff' => 1,
	'suf' => 1,
	'flex-suf' => 1,
	'pref' => 1,
	'préf' => 1,
	'post' => 1,
	'inf' => 1,
	'circonf' => 1,
	'part' => 1,
	'particule' => 1,
	'radical' => 1,
	'racine' => 1,
	'part-num' => 1,
	
	# Phrases et locutions
	'loc' => 1,
	'loc-phr' => 1,
	'prov' => 1,
	
	# Exclamations
	'interj' => 1,
	'interjection' => 1,
	'loc-interj' => 1,
	'flex-interj' => 1,
	'onoma' => 1,
	
	# Caractères
	'lettre' => 1,
	'flex-lettre' => 1,
	'symb' => 1,
	'symbole' => 1,
	'class' => 1,
	'numér' => 1,
	'numéral' => 1,
	
	# Désuets
	'corrélatif' => 2,
	'abr' => 2,
	'cont' => 2,
	
	# Beuh
	'erreur' => 2,
	'var-typo' => 2,
	#'drv' => 2,
} ;

our $word_type_syn = {
	'verbe' => 'verb',
	'loc-verbe' => 'loc-verb',
	'flex-verbe' => 'flex-verb',
	'flex-loc-verbe' => 'flex-loc-verb',
	'verbe-pr' => 'verb-pr',
	'numér' => 'numéral',
	'part' => 'particule',
	'pref' => 'préf',
	'adj' => 'adjectif',
	'loc-adjectif' => 'loc-adj',
	'flex-adjectif' => 'flex-adj',
	'flex-loc-adjectif' => 'flex-loc-adj',
	'adverbe' => 'adv',
	'loc-adverbe' => 'loc-adv',
	'flex-adverbe' => 'flex-adv',
	'flex-loc-adverbe' => 'flex-loc-adv',
	'prep' => 'prép',
	'loc-prep' => 'loc-prép',
	'flex-prep' => 'flex-prép',
} ;

our $level4 = {
	'ortho-alt' => 1,
	'syn' => 1,
	'q-syn' => 1,
	'ant' => 1,
	'gent' => 1,
	'hyper' => 1,
	'hypo' => 1,
	'holo' => 1,
	'tropo' => 1,
	'méro' => 1,
	'mero' => 1,
	'drv' => 1,
	'drv-int' => 1,
	'apr' => 1,
	'exp' => 1,
	'compos' => 1,
	'var' => 1,
	'var-ortho' => 1,
	'dial' => 1,
	'trad' => 1,
	'voc' => 1,
	'note' => 1,
	'homo' => 1,
	'paro' => 1,
	'anagr' => 1,
	'abrév' => 1,
} ;

our $langues_transcrites = {
	'cyrillique' => {'ru'=>1, 'bg'=>1, 'uk'=>1},
	'grec' => {'el'=>1, 'grc'=>1},
	'arabe' => {'ar'=>1, 'fa'=>1},
} ;

1 ;

__END__


# Wiktionnaire bases
# Author: Matthieu Barba
# This module contain basic data and functions for Wiktionary fr
package wiktio::basic ;

use Exporter ;
@ISA=('Exporter') ;
@EXPORT_OK = qw(
	$word_type
	$level3
	$level4
	step
	stepl
) ;

use strict ;
use warnings ;

sub step { print STDERR $_[0] ? ($_[0] =~ /[\r\n]$/ ? "$_[0]" : "$_[0]\n") : "\n" } ;
sub stepl { print STDERR $_[0] ? "$_[0]" : "" } ;

our $level3 = {
	'étym' => 'etymologie',
	'etym' => 'etymologie',	# Beuh
	'éty' => 'etymologie',	# Beuh
	'étyl' => 'etymologie',	# Beuh
	'pron' => 'prononciation',
	'voir' => 'voir',
	'anagr'  => 'anagrammes',
	'réf'  => 'references',
} ;

our $word_type = {

	'nom' => 1,
	'nom-sciences' => 1,
	'flex-nom' => 1,
	'nom-pr' => 1,
	'adj' => 1,
	'flex-adj' => 1,
	'adv' => 1,
	'adv-pron' => 1,
	'adv-rel' => 1,
	'adv-int' => 1,
	
	'loc' => 1,
	'loc-nom' => 1,
	'loc-adj' => 1,
	'loc-adv' => 1,
	'loc-conj' => 1,
	'loc-interj' => 1,
	'loc-phr' => 1,
	'loc-prep' => 1,
	'loc-pronom' => 1,
	'loc-prép' => 1,
	'prov' => 1,
	'adj-dem' => 1,
	'adj-dém' => 1,
	'adj-excl' => 1,
	'adj-indef' => 1,
	'adj-indéf' => 1,
	'flex-adj-indéf' => 1,
	'adj-int' => 1,
	'adj-num' => 1,
	'adj-pos' => 1,
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
	'pronom' => 1,
	'flex-pronom' => 1,
	'pronom-def' => 1,
	'pronom-déf' => 1,
	'pronom-indef' => 1,
	'pronom-indéf' => 1,
	'flex-pronom-indéf' => 1,
	'pronom-int' => 1,
	'pronom-pers' => 1,
	'pronom-pos' => 1,
	'pronom-refl' => 1,
	'pronom-réfl' => 1,
	'pronom-rel' => 1,
	'pronom-dem' => 1,
	'pronom-dém' => 1,
	'conj' => 1,
	'conj-coord' => 1,
	'aff' => 1,
	'suf' => 1,
	'pref' => 1,
	'préf' => 1,
	'post' => 1,
	'inf' => 1,
	'particule' => 1,
	'part' => 1,
	'interj' => 1,
	'marque' => 1,
	'onoma' => 1,
	'prénom' => 1,
	'nom-fam' => 1,
	'prep' => 1,
	'prép' => 1,
	'aux' => 1,
	'class' => 1,
	'lettre' => 1,
	'corrélatif' => 1,
	'abr' => 1,
	'symb' => 1,
	'cont' => 1,
	'flex-loc-nom' => 1,
	'flex-loc-adj' => 1,
	'flex-nom-pr' => 1,
	'flex-nom-fam' => 1,
	'flex-prep' => 1,
	'flex-prép' => 1,
	'flex-suf' => 1,
	'nom-ni' => 1,
	'nom-nu' => 1,
	'nom-nn' => 1,
	'nom-npl' => 1,
	'radical' => 1,
	# Verbe
	'verb' => 1,
	'flex-verb' => 1,
	'loc-verb' => 1,
	'flex-loc-verb' => 1,
	'verb-pr' => 1,
	
	# Beuh
	'erreur' => 2,
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
	'dial' => 1,
	'trad' => 1,
	'voc' => 1,
	'note' => 1,
	'homo' => 1,
	'paro' => 1,
	'anagr' => 1,
	'abrév' => 1,
} ;

1 ;

__END__


# Wiktionnaire bases
# Author: Matthieu Barba
# This module contains basic data and functions for Wiktionary fr
package wiktio::basic;

use Exporter;
@ISA=('Exporter');

@EXPORT = qw(
	$log
	special_log
	dump_input
	$true $false
	print_value
);

@EXPORT_OK = qw(
	$word_type
	$word_type_syn
	$level3
	$level4
	$langues_transcrites
	step
	stepl
	to_utf8
);

use strict;
use warnings;

use utf8;
use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use Encode qw(decode);

our $true = 1;
our $false = 0;

our $log = '';

sub step { print STDERR $_[0] ? ($_[0] =~ /[\r\n]$/ ? "$_[0]" : "$_[0]\n") : "\n" };
sub stepl { print STDERR $_[0] ? "$_[0]" : "" };

# Print a value for a given hash ref, array ref or text
sub print_value
{
	my ($text, $ref) = @_;
	
	# Get the number if the ref is a hash or an array
	my $val = '';
	if 	(ref($ref) eq 'ARRAY') {
		$val = $#{$ref} + 1;
	} elsif (ref($ref) eq 'HASH') {
		$val = keys %$ref;
	} else {
		$val = $ref;
	}
	
	# Print the value
	step(sprintf($text, $val));
}

# Log specific errors in separate files
sub special_log
{
	my ($nom, $titre, $texte, $other) = @_;
	return if not $log;
	
	my $logfile = $log.'_'.$nom;
	
	open(LOG, ">>$logfile") or die("Couldn't write $logfile: $!");
	my $raw_texte = $texte ? $texte : '';
	$raw_texte =~ s/\[\[([^\]]+)\]\]/__((__$1__))__/g;
	$raw_texte .= "\t($other)" if $other;
	print LOG "$titre\t$raw_texte\n";
	close(LOG);
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


sub to_utf8
{
	my $opts = shift;
	
	if (ref($opts) eq 'HASH') {
		foreach my $v (keys %$opts) {
			$opts->{$v} = Encode::decode('UTF-8', $opts->{$v});
		}
	} elsif (ref($opts) eq 'HASH') {
		map { Encode::decode('UTF-8', $_); } @$opts;
	} elsif (ref($opts) eq '') {
		$opts= Encode::decode('UTF-8', $opts);
	}
	return $opts;
}
1;

our $level3 = {
	'étymologie' => 'étymologie',
		'étym' => 'étymologie',
		'etym' => 'étymologie',
	'prononciation' => 'prononciation',
	'pron' => 'prononciation',
	'voir aussi' => 'voir aussi',
	'voir' => 'voir aussi',
	'anagrammes'  => 'anagrammes',
	'anagr'  => 'anagrammes',
	'références'  => 'réferences',
		'réf'  => 'réferences',
		'ref'  => 'réferences',
};

our $word_type = {
	'adjectif' => 	'adj',
	'adj' => 	'adj',
	'adjectif qualificatif' => 	'adj',
	'adverbe' => 	'adv',
	'adv' => 	'adv',
	'adverbe interrogatif' => 	'adv-int',
	'adv-int' => 	'adv-int',
	'adverbe int' => 	'adv-int',
	'adverbe pronominal' => 	'adv-pron',
	'adv-pron' => 	'adv-pron',
	'adverbe pro' => 	'adv-pron',
	'adverbe relatif' => 	'adv-rel',
	'adv-rel' => 	'adv-rel',
	'adverbe rel' => 	'adv-rel',
	'conjonction' => 	'conj',
	'conj' => 	'conj',
	'conjonction de coordination' => 	'conj-coord',
	'conj-coord' => 	'conj-coord',
	'conjonction coo' => 	'conj-coord',
	'copule' => 	'copule',
	'adjectif démonstratif' => 	'adj-dém',
	'adj-dém' => 	'adj-dém',
	'adjectif dém' => 	'adj-dém',
	'déterminant' => 	'det',
	'dét' => 	'det',
	'adjectif exclamatif' => 	'adj-excl',
	'adj-excl' => 	'adj-excl',
	'adjectif exc' => 	'adj-excl',
	'adjectif indéfini' => 	'adj-indéf',
	'adj-indéf' => 	'adj-indéf',
	'adjectif ind' => 	'adj-indéf',
	'adjectif interrogatif' => 	'adj-int',
	'adj-int' => 	'adj-int',
	'adjectif int' => 	'adj-int',
	'adjectif numéral' => 	'adj-num',
	'adj-num' => 	'adj-num',
	'adjectif num' => 	'adj-num',
	'adjectif possessif' => 	'adj-pos',
	'adj-pos' => 	'adj-pos',
	'adjectif pos' => 	'adj-pos',
	'article' => 	'art',
	'art' => 	'art',
	'article défini' => 	'art-déf',
	'art-déf' => 	'art-déf',
	'article déf' => 	'art-déf',
	'article indéfini' => 	'art-indéf',
	'art-indéf' => 	'art-indéf',
	'article ind' => 	'art-indéf',
	'article partitif' => 	'art-part',
	'art-part' => 	'art-part',
	'article par' => 	'art-part',
	'nom' => 	'nom',
	'substantif' => 	'nom',
	'nom commun' => 	'nom',
	'nom de famille' => 	'nom-fam',
	'nom-fam' => 	'nom-fam',
	'patronyme' => 	'patronyme',
	'nom propre' => 	'nom-pr',
	'nom-pr' => 	'nom-pr',
	'nom scientifique' => 	'nom-sciences',
	'nom-sciences' => 	'nom-sciences',
	'nom science' => 	'nom-sciences',
	'nom scient' => 	'nom-sciences',
	'prénom' => 	'prenom',
	'préposition' => 	'prep',
	'prép' => 	'prep',
	'pronom' => 	'pronom',
	'pronom-adjectif' => 	'pronom-adj',
	'pronom démonstratif' => 	'pronom-dém',
	'pronom-dém' => 	'pronom-dém',
	'pronom dém' => 	'pronom-dém',
	'pronom indéfini' => 	'pronom-indéf',
	'pronom-indéf' => 	'pronom-indéf',
	'pronom ind' => 	'pronom-indéf',
	'pronom interrogatif' => 	'pronom-int',
	'pronom-int' => 	'pronom-int',
	'pronom int' => 	'pronom-int',
	'pronom personnel' => 	'pronom-pers',
	'pronom-pers' => 	'pronom-pers',
	'pronom-per' => 	'pronom-pers',
	'pronom réf' => 	'pronom-pers',
	'pronom-réfl' => 	'pronom-pers',
	'pronom réfléchi' => 	'pronom-pers',
	'pronom possessif' => 	'pronom-pos',
	'pronom-pos' => 	'pronom-pos',
	'pronom pos' => 	'pronom-pos',
	'pronom relatif' => 	'pronom-rel',
	'pronom-rel' => 	'pronom-rel',
	'pronom rel' => 	'pronom-rel',
	'verbe' => 	'verb',
	'verb' => 	'verb',
	'verbe pronominal' => 	'verb',
	'verb-pr' => 	'verb',
	'verbe pr' => 	'verb',
	'interjection' => 	'interj',
	'interj' => 	'interj',
	'onomatopée' => 	'onoma',
	'onoma' => 	'onoma',
	'onom' => 	'onoma',
	'affixe' => 	'aff',
	'aff' => 	'aff',
	'circonfixe' => 	'circon',
	'circonf' => 	'circon',
	'circon' => 	'circon',
	'infixe' => 	'inf',
	'inf' => 	'inf',
	'interfixe' => 	'interf',
	'interf' => 	'interf',
	'particule' => 	'part',
	'part' => 	'part',
	'particule numérale' => 	'part-num',
	'part-num' => 	'part-num',
	'particule num' => 	'part-num',
	'postposition' => 	'post',
	'post' => 	'post',
	'postpos' => 	'post',
	'préfixe' => 	'pre',
	'préf' => 	'pre',
	'radical' => 	'radical',
	'rad' => 	'radical',
	'suffixe' => 	'suf',
	'suff' => 	'suf',
	'suf' => 	'suf',
	'pré-verbe' => 	'preverb',
	'pré-nom' => 	'pre-nom',
	'locution' => 	'loc',
	'loc' => 	'loc',
	'locution-phrase' => 	'phr',
	'loc-phr' => 	'phr',
	'locution-phrase' => 	'phr',
	'locution phrase' => 	'phr',
	'proverbe' => 	'prov',
	'prov' => 	'prov',
	'quantificateur' => 	'quantif',
	'quantif' => 	'quantif',
	'variante typographique' => 	'var-typo',
	'var-typo' => 	'var-typo',
	'variante typo' => 	'var-typo',
	'variante par contrainte typographique' => 	'var-typo',
	'lettre' => 	'lettre',
	'symbole' => 	'symb',
	'symb' => 	'symb',
	'classificateur' => 	'class',
	'class' => 	'class',
	'classif' => 	'class',
	'numéral' => 	'numeral',
	'numér' => 	'numeral',
	'num' => 	'numeral',
	'sinogramme' => 	'sinogramme',
	'sinog' => 	'sinogramme',
	'sino' => 	'sinogramme',
	'erreur' => 	'faute',
	'faute' => 	'faute',
	'faute d\'orthographe' => 	'faute',
	'faute d’orthographe' => 	'faute',
	'gismu' => 	'gismu',
	'rafsi' => 	'rafsi',
};

our $level4 = {
	'anagrammes' => 	'anagrammes',
	'anagramme' => 	'anagrammes',
	'anagr' => 	'anagrammes',
	'dico sinogrammes' => 	'dico sinogrammes',
	'sino-dico' => 	'dico sinogrammes',
	'dico-sino' => 	'dico sinogrammes',
	'écriture' => 	'écriture',
	'écrit' => 	'écriture',
	'étymologie' => 	'étymologie',
	'étym' => 	'étymologie',
	'etym' => 	'étymologie',
	'prononciation' => 	'prononciation',
	'pron' => 	'prononciation',
	'prononciations' => 	'prononciation',
	'références' => 	'références',
	'référence' => 	'références',
	'réf' => 	'références',
	'ref' => 	'références',
	'voir aussi' => 	'voir aussi',
	'voir' => 	'voir aussi',
	'abréviations' => 	'abréviations',
	'abrév' => 	'abréviations',
	'antonymes' => 	'antonymes',
	'ant' => 	'antonymes',
	'anto' => 	'antonymes',
	'apparentés' => 	'apparentés',
	'apr' => 	'apparentés',
	'app' => 	'apparentés',
	'apparentés étymologiques' => 	'apparentés',
	'augmentatifs' => 	'augmentatifs',
	'augm' => 	'augmentatifs',
	'citations' => 	'citations',
	'cit' => 	'citations',
	'composés' => 	'composés',
	'compos' => 	'composés',
	'diminutifs' => 	'diminutifs',
	'dimin' => 	'diminutifs',
	'dérivés' => 	'dérivés',
	'drv' => 	'dérivés',
	'dérivés autres langues' => 	'dérivés autres langues',
	'drv-int' => 	'dérivés autres langues',
	'dérivés int' => 	'dérivés autres langues',
	'expressions' => 	'expressions',
	'exp' => 	'expressions',
	'expr' => 	'expressions',
	'faux-amis' => 	'faux-amis',
	'gentilés' => 	'gentilés',
	'gent' => 	'gentilés',
	'holonymes' => 	'holonymes',
	'holo' => 	'holonymes',
	'hyponymes' => 	'hyponymes',
	'hypo' => 	'hyponymes',
	'hyperonymes' => 	'hyperonymes',
	'hyper' => 	'hyperonymes',
	'vidéos' => 	'vidéos',
	'méronymes' => 	'méronymes',
	'méro' => 	'méronymes',
	'noms vernaculaires' => 	'noms vernaculaires',
	'noms-vern' => 	'noms vernaculaires',
	'quasi-synonymes' => 	'quasi-synonymes',
	'q-syn' => 	'quasi-synonymes',
	'quasi-syn' => 	'quasi-synonymes',
	'synonymes' => 	'synonymes',
	'syn' => 	'synonymes',
	'traductions' => 	'traductions',
	'trad' => 	'traductions',
	'traductions à trier' => 	'traductions à trier',
	'trad-trier' => 	'traductions à trier',
	'trad trier' => 	'traductions à trier',
	'transcriptions' => 	'transcriptions',
	'trans' => 	'transcriptions',
	'tran' => 	'transcriptions',
	'translittérations' => 	'translittérations',
	'translit' => 	'translittérations',
	'troponymes' => 	'troponymes',
	'tropo' => 	'troponymes',
	'vocabulaire' => 	'vocabulaire',
	'voc' => 	'vocabulaire',
	'vocabulaire apparenté' => 	'vocabulaire',
	'vocabulaire proche' => 	'vocabulaire',
	'anciennes orthographes' => 	'anciennes orthographes',
	'ortho-arch' => 	'anciennes orthographes',
	'anciennes ortho' => 	'anciennes orthographes',
	'variantes' => 	'variantes',
	'var' => 	'variantes',
	'variantes dialectales' => 	'variantes dialectales',
	'dial' => 	'variantes dialectales',
	'var-dial' => 	'variantes dialectales',
	'variantes dial' => 	'variantes dialectales',
	'variantes dialectes' => 	'variantes dialectales',
	'dialectes' => 	'variantes dialectales',
	'variantes ortho' => 	'variantes ortho',
	'var-ortho' => 	'variantes ortho',
	'variantes orthographiques' => 	'variantes ortho',
	'conjugaison' => 	'conjugaison',
	'conjug' => 	'conjugaison',
	'déclinaison' => 	'déclinaison',
	'décl' => 	'déclinaison',
	'attestations' => 	'attestations',
	'attest' => 	'attestations',
	'hist' => 	'attestations',
	'homophones' => 	'homophones',
	'homo' => 	'homophones',
	'paronymes' => 	'paronymes',
	'paro' => 	'paronymes',
	'note' => 	'note',
	'notes' => 	'notes',

};

our $langues_transcrites = {
	'cyrillique' => {'ru'=>1, 'bg'=>1, 'uk'=>1},
	'grec' => {'el'=>1, 'grc'=>1},
	'arabe' => {'ar'=>1, 'fa'=>1},
};

1;

__END__

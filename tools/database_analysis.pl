#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;
use DBI;
use Encode;
use Data::Dumper;

our %opt;	# Getopt options

my $conditions = << "REQ";
	l_lang=? AND
	NOT p_pron IS NULL AND
	NOT l_type="symb" AND
	NOT l_type="lettre" AND
	NOT l_type="nom-sciences" AND
	NOT l_type="nom-pr" AND
	NOT l_type="nom-fam" AND
	NOT l_type="prenom" AND
	NOT l_is_gentile AND
	l_sigle=""
REQ

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0];
	print STDERR << "EOF";
	
	This script performs various analysis on an anagrimes database.
	
	-h        : this (help) message
	-d <path> : database path
	
	Type of analysis
	-p <str>  : analyse pronunciations for the given language
	-c <str>  : count letters for the given language
	-I        : case insensitive (for counts)
	
	-F        : exclude flexions
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hd:p:c:IF', \%opt ) or usage();
	usage() if $opt{h};
	usage("Database needed (-d)") unless $opt{d};
	usage("Type of analysis needed") if not $opt{p} xor $opt{c};
	$conditions .= ' AND NOT l_is_flexion' if $opt{F};
}

sub get_articles
{
	my ($dbh, $lang) = @_;
	
	my $query = "SELECT DISTINCT(a_title) FROM articles JOIN lexemes ON a_artid=l_artid WHERE $conditions";
	return $dbh->selectcol_arrayref($query, undef, $lang);
}

sub get_articles_prons
{
	my ($dbh, $lang) = @_;
	
	my $query = << "REQ";
	SELECT *
	FROM entries
	WHERE $conditions
	GROUP BY a_title, p_pron
REQ
	return $dbh->selectall_arrayref($query, { Slice => {} }, $lang);
}

sub pronunciations
{
	my ($dbh, $lang) = @_;
	
	# Get all articles with pronunciations
	my $articles = get_articles_prons($dbh, $lang);
	my $n = @$articles;
	print STDERR "$n articles with pronunciations in lang $lang\n";

	# Compute expected pronunciation based on the language
	my ($total, $same, $samer, $sameish) = expected_pronunciation($articles, $lang);
	my $nsame = $total - @$same;
	my $nsamer = $total - @$samer;
	my $nsameish = $total - @$sameish;
	print STDERR "$total\tarticles with usable pronunciations\n";
	print STDERR "$nsame\tdifferent " . sprintf("(%.2f %%)\n", $nsame/$total*100);
	print STDERR "$nsamer\tquite different " . sprintf("(%.2f %%)\n", $nsamer/$total*100);
	print STDERR "$nsameish\tcompletely different " . sprintf("(%.2f %%)\n", $nsameish/$total*100);
}

sub expected_pronunciation
{
	my ($articles, $lang) = @_;
	
	my $count = 0;
	my @same = ();
	my @samer = ();
	my @sameish = ();
	foreach my $a (@$articles) {
		my ($correct, $is_same, $is_samer, $is_sameish) = check_pronunciation($a, $lang);
		$count += $correct;
		push @same, $a if $is_same;
		push @samer, $a if $is_samer;
		push @sameish, $a if $is_sameish;
	}
	return $count, \@same, \@samer, \@sameish;
}

sub check_pronunciation
{
	my ($art, $lang) = @_;

	# Check French
	if ($lang eq 'fr') {
		my $pron = pron_in_fr($art);
		
		if ($pron) {
			my $same = not different($art->{p_pron}, $pron);
			my $samer = not quite_different($art->{p_pron}, $pron);
			my $sameish = not very_different($art->{p_pron}, $pron);
			my $diffs = '';
			if ($same) {
				$diffs = 'OK';
			} elsif ($samer) {
				$diffs = 'OK?';
			} elsif ($sameish) {
				$diffs = 'bof';
			} else {
				$diffs = 'nope!';
			}
			print STDOUT "$diffs\t$art->{'a_title'}\t'$pron'\t'".clean_pron($art->{p_pron})."'\n";
			return (1, $same, $samer, $sameish);
		} else {
			return 0, 0, 0, 0;
		}
	}
	return 0, 0, 0, 0;
}

sub different
{
	my ($p1, $p2) = @_;
	
	my $pron1 = simple($p1);
	my $pron2 = simple($p2);
	
	if ($pron1 eq $pron2) {
		return 0;
	} else {
		return 1;
	}
}

sub quite_different
{
	my ($p1, $p2) = @_;
	
	my $pron1 = simpler($p1);
	my $pron2 = simpler($p2);
	
	if ($pron1 eq $pron2) {
		return 0;
	} else {
		return 1;
	}
}

sub very_different
{
	my ($p1, $p2) = @_;
	
	my $pron1 = simplest($p1);
	my $pron2 = simplest($p2);
	
	if ($pron1 eq $pron2) {
		return 0;
	} else {
		return 1;
	}
}


sub simple
{
	my ($m) = @_;
	
	$m =~ s/([\s\. ]|‿|ː)+//g;
	$m =~ s/ə//g;
	$m =~ s/ʁ/r/g;
	$m =~ s/ɡ/g/g;
	$m =~ s/ɑ/a/g;
	return $m;
}

sub simpler
{
	my ($m) = @_;
	$m = simple($m);
	$m =~ s/ɔ/o/g;
	$m =~ s/ɛ/e/g;
	$m =~ s/ø/œ/g;
	$m =~ s/gn/nj/g;
	$m =~ s/ɲ/nj/g;
	
	return $m;
}

sub simplest
{
	my ($m) = @_;
	
	$m = simpler($m);
	$m =~ s/ǝ//g;
	$m =~ s/j/i/g;
	$m =~ s/ɥ/y/g;
	$m =~ s/w/u/g;
	$m =~ s/ʃ/k/g;
	$m =~ s/z/s/g;
	$m =~ s/b/p/g;
	$m =~ s/gz/ks/g;
	$m =~ s/[\(\)]//g;
	$m =~ s/(.)\1/$1/g;
	return $m;
}

sub clean_pron
{
	my ($pron) = @_;
	$pron =~ s/[\.,;:!\?]//g;
	$pron =~ s/'|’/ /g;
	$pron =~ s/-/ /g;
	$pron =~ s/Â/â/g;
	return $pron;
}

sub pron_in_fr
{
	my ($art) = @_;
	my $w = $art->{'a_title'};
	my $typ = $art->{'l_type'} ? $art->{'l_type'} : '';
	
	my $p = clean_pron($w);
	if ($p =~ /\b([A-Z\.,;!\(\)+\-]|−)+\b/ or
			$p =~ /[0-9]/ or
			$p =~ /[A-Z]{2,}/ or
			$p =~ /[&\(\)]/
		) {
		return '';
	}
	
	my $voy = "[aAiIeEJoOuUyY]";
	$voy .= "|" . "é|è|ê|ɛ|ɛ̃|É|È|œ|œ̃|Œ|ɑ|ɑ̃|ə|ɔ|ɔ̃|ø";
	$voy .= "|" . decode('utf8',"é|è|ê|ɛ|ɛ̃|É|È|œ|œ̃|i|Œ|ɑ|ɑ̃|ə|ɔ|ɔ̃|ø");
	my $cons = "[cbdfgjGklmMnNpqrRsStTvz]";
	$cons .= "|" . "ɡ|ʒ|ʁ|ʃ|ɲ";
	$cons .= "|" . decode('utf8', "ɡ|ʒ|ʁ|ʃ|ɲ");
	my $ei = decode("utf8", "i|É|ə|œ");
	$ei .= "|e|i|É|ə|œ";
	my $aou = "[aoUY]";
	$aou .= "|" . "ɔ|ɔ̃|ɑ|ɑ̃|ø";
	my $s = '(\s|^|-|‿)';
	my $e = '(\s|$|-|‿)';
	my $E = '(?:ə|e)';
	
	# Before lowercase
	$p =~ s/${s}Est$e/$1ɛST$2/g;
	$p = lc($p);
	
	# Single unambiguous letters
	$p =~ s/ù/u/g;
	
	# Mots
	$p =~ s/${s}et$e/$1É$2/g;
	$p =~ s/t ($voy)/tT‿$1/g;
	$p =~ s/n ($voy)/nN‿$1/g;
	$p =~ s/${s}([ldms])es ($voy)/$1$2ɛz$3/g;
	$p =~ s/${s}([ldms])es$e/$1$2ɛ$3/g;
	$p =~ s/${s}([cldmst])e$e/$1$2ə$3/g;
	$p =~ s/${s}un ($voy)/$1ŒŒN‿$2/g;
	$p =~ s/${s}uns?$e/$1ŒŒ$2/g;
	$p =~ s/${s}longs?$e/$1Lɔ̃$2/g;
	$p =~ s/^s /S/g;
	$p =~ s/α/ALFA/g;
	$p =~ s/β/BɛTA/g;
	$p =~ s/γ/GAMA/g;
	$p =~ s/δ/DɛLTA/g;
	$p =~ s/ε/ɛPSILɔN/g;
	$p =~ s/${s}ré($voy)/$1RÉ $2/g;
	$p =~ s/${s}sud$e/$1SYD$2/g;
	$p =~ s/${s}zut$e/$1ZYT$2/g;
	$p =~ s/${s}nez$e/$1NE$2/g;
	$p =~ s/${s}culs?$e/$1KY$2/g;
	$p =~ s/${s}temps$e/$1tɑ̃$2/g;
	$p =~ s/${s}ego$e/$1ÉGO$2/g;
	$p =~ s/${s}sang?s$e/$1sɑ̃$2/g;
	$p =~ s/orps$e/ɔR$1/g;
	$p =~ s/${s}clefs?$e/$1KLÉ$2/g;
	$p =~ s/${s}ne$e/$1Nə$2/g;
	#$p =~ s/${s}tous$e/$1TUS$2/g;
	$p =~ s/${s}est?${e}/$1ɛ$2/g;
	$p =~ s/${s}[cs] /$1S /g;
	#$p =~ s/${s}h/$1/g;
	
	# Terminaisons courantes
	if ($typ eq 'verb' and not $art->{'l_is_locution'}) {
		$p =~ s/ez$e/É$1/g;
		$p =~ s/ai$e/É$1/g;
		$p =~ s/($voy)se(?:nt|s)?$e/$1Z$2/g;
		$p =~ s/($voy)ce(?:nt|s)?$e/$1S$2/g;
		$p =~ s/($cons)(\1?)e(?:nt|s)?$e/\u$1\u$2$3/g;
		$p =~ s/iLL$e/ill$1/g;
		$p =~ s/e(?:nt|s)?$e/e$1/g;
		$p =~ s/ient$e/I$1/g;
		$p =~ s/ents?$e/$1/g;
		$p =~ s/ends?$e/ɑ̃$1/g;
		$p =~ s/tions?$e/TJɔ̃$1/g;
		$p =~ s/erds?$e/ɛR$1/g;
	} else {
		$p =~ s/($voy)tiens?$e/$1SJɛ̃$2/g;
		$p =~ s/tients?$e/SJɑ̃$1/g;
		$p =~ s/ients?$e/Jɑ̃$1/g;
	}
	$p =~ s/yx$e/IKS$1/g;
	$p =~ s/art$e/AR$1/g;
	$p =~ s/($cons)uns?$e/$1ŒŒ$2/g;
	$p =~ s/qu$E?s?$e/k$1/g;
	$p =~ s/[gG]${E}s?$e/ʒ$1/g;
	$p =~ s/doigts?/dwat/g;
	$p =~ s/deux($voy)/døz$1/g;
	$p =~ s/deux$e/dø$1/g;
	$p =~ s/dix($voy)/diz$1/g;
	$p =~ s/geanc${E}s?$e/ʒɑ̃S$1/g;
	$p =~ s/bourgs?$e/bour$1/g;
	$p =~ s/ances?$e/ɑ̃S$1/g;
	$p =~ s/stionn/STJɔN/g;
	$p =~ s/bapt/baT/g;
	$p =~ s/tionn/SJɔN/g;
	$p =~ s/stions?$e/STJon$1/g;
	$p =~ s/tions?$e/SJɔ̃$1/g;
	$p =~ s/motion/moSJon/g;
	$p =~ s/${s}([b])on ($voy)/$1$2ɔn$3/g;
	$p =~ s/ons?$e/ɔ̃$1/g;
	$p =~ s/er$e/É$1/g;
	$p =~ s/${s}ex($voy)/$1ɛgz$2/g;
	$p =~ s/ex$e/ɛkS$1/g;
	$p =~ s/ax$e/AkS$1/g;
	$p =~ s/ert$e/ɛʁ$1/g;
	$p =~ s/ing$e/iŋ$1/g;
	$p =~ s/eo$e/ÉO$1/g;
	$p =~ s/efs?$e/ɛF$1/g;
	$p =~ s/rand ($voy)/rɑ̃t$1/g;
	$p =~ s/and$e/ɑ̃$1/g;
	$p =~ s/(?:ots?|e?aux?)$e/O$1/g;
	$p =~ s/gemment?s?$e/ʒamɑ̃$1/g;
	$p =~ s/emment?s?$e/amɑ̃$1/g;
	$p =~ s/ement?s?$e/əmɑ̃$1/g;
	$p =~ s/ment?s?$e/mɑ̃$1/g;
	$p =~ s/an[tc]s?$e/ɑ̃$1/g;
	$p =~ s/antes?$e/ɑ̃T$1/g;
	$p =~ s/ient?s?$e/Jɛ̃$1/g;
	$p =~ s/éens?$e/Éɛ̃$1/g;
	$p =~ s/ets?$e/ɛ$1/g;
	$p =~ s/ettes?$e/ɛT$1/g;
	$p =~ s/${s}antis/$1ɑ̃TIS/g;
	$p =~ s/${s}anti/$1ɑ̃Ti/g;
	$p =~ s/stiel$e/STJɛl$1/g;
	$p =~ s/tiel$e/SJɛl$1/g;
	$p =~ s/stial/STJal/g;
	$p =~ s/tial/SJal/g;
	$p =~ s/craties?$e/KRASI$1/g;
	$p =~ s/els?$e/ɛl$1/g;
	$p =~ s/ès$e/ɛ$1/g;
	$p =~ s/iers?$e/JÉ$1/g;
	$p =~ s/ompt/ɔ̃t/g;
	$p =~ s/or[td]s?$e/ɔʁ$1/g;
	$p =~ s/amps/ɑ̃/g;
	$p =~ s/scr/Skʁ/g;
	$p =~ s/ons[sc]?/ɔ̃S/g;
	$p =~ s/on[dt]?s?$e/ɔ̃$1/g;
	$p =~ s/oses?$e/oz$1/g;
	$p =~ s/eux$e/ø$1/g;
	$p =~ s/ails?$e/ɑJ$1/g;
	$p =~ s/ards?$e/ɑʁ$1/g;
	$p =~ s/ault$e/o$1/g;
	$p =~ s/aims?$e/ɛ̃$1/g;
	$p =~ s/e[ck]s?$e/ɛk$1/g;
	$p =~ s/eds?$e/É$1/g;
	$p =~ s/([^oae])ums?$e/$1ɔm$2/g;
	$p =~ s/($cons)els?$e/$1ɛl$2/g;
	#$p =~ s/($cons)us$e/$1YS$2/g;	# latin?
	$p =~ s/tes$e/T$1/g;
	$p =~ s/qu /k/g;
	
	$p =~ s/${s}second/$1segond/g;
	$p =~ s/s?cenn/SSɛN/g;
	$p =~ s/s?cens($voy)/SSɑ̃S$1/g;
	$p =~ s/s?ce[nm]($cons)/SSɑ̃$1/g;
	$p =~ s/geoi/ʒwA/g;
	$p =~ s/gen([tcd])/ʒɑ̃$1/g;
	$p =~ s/geu([sz])/ʒø$1/g;
	$p =~ s/gi/ʒi/g;
	$p =~ s/gien/ʒJɛ̃/g;
	$p =~ s/ca/ka/g;
	$p =~ s/genoux?/ʒəNou/g;
	$p =~ s/nation/NA.SJon/g;
	$p =~ s/aiguill/ɛGɥIJ/g;
	$p =~ s/gu($ei)/G$1/g;
	$p =~ s/tech/tɛk/g;
	$p =~ s/ss?ex/Sɛks/g;
	$p =~ s/euse/øz/g;
	$p =~ s/vingt/vɛ̃t/g;
	$p =~ s/alcool/alkol/g;
	$p =~ s/ymph/inf/g;
	$p =~ s/(.)g[nN]/$1ɲ/g;
	$p =~ s/acqui/aki/g;
	$p =~ s/schn/ʃN/g;
	$p =~ s/chn/KN/g;
	$p =~ s/cqu(o?i)/kk$1/g;
	$p =~ s/qu(o?i)/k$1/g;
	$p =~ s/oyoi/wAJU/g;
	$p =~ s/oyo/oJo/g;
	$p =~ s/gay($voy)/GɛJ$1/g;
	$p =~ s/($cons)ay($voy)/$1ɛJ$2/g;
	
	# Préfixes courants
	$p =~ s/${s}chr/$1KR/g;
	$p =~ s/${s}renn/$1RɛN/g;
	$p =~ s/${s}re[nm]($cons)/$1rɑ̃$2/g;
	$p =~ s/${s}re($cons)/$1rə$2/g;
	$p =~ s/${s}er/$1ɛr/g;
	$p =~ s/${s}aqua/$1akwa/g;
	$p =~ s/${s}auto/$1OTO /g;
	$p =~ s/${s}hexa/$1exa/g;
	$p =~ s/${s}hyper/$1Ipɛʁ/g;
	$p =~ s/${s}super/$1sYpɛʁ/g;
	$p =~ s/${s}hyper/$1IPɛʁ/g;
	$p =~ s/${s}asthm/$1asm/g;
	$p =~ s/psycho/psiko/g;
	$p =~ s/bienn/bJɛn/g;
	$p =~ s/bien/bJɛ̃ /g;
	$p =~ s/ens/ɑ̃S/g;
	$p =~ s/aiguill/ɛGYIJ/g;
	$p =~ s/${s}enn(e|E|É)([^i])/$1ɛN$2$3/g;
	$p =~ s/${s}e(?:[nm])($cons)/$1ɑ̃$2/g;
	$p =~ s/${s}e((?:$cons)+)($voy)/$1ɛ$2$3/g;
	$p =~ s/${s}ex($voy)/$1ɛgz$2/g;
	$p =~ s/${s}voy($voy)/$1VWAJ$2/g;
	
	$p =~ s/esse?s?$e/ɛS$1/g;
	$p =~ s/sse?s?$e/S$1/g;
	$p =~ s/ette?s?$e/ɛT$1/g;
	$p =~ s/tte?s?$e/T$1/g;
	$p =~ s/[sx]$e/$1/g;
	$p =~ s/([aA])[d]$e/$1D$2/g;
	$p =~ s/($voy)[ptd]$e/$1$2/g;
	$p =~ s/ç/S/g;
	$p =~ s/ïn($cons)/ɛ̃$1/g;
	$p =~ s/eï/ɛJ/g;
	$p =~ s/ï/I/g;
	$p =~ s/î/i/g;
	$p =~ s/ô/O/g;
	$p =~ s/oû/U/g;
	$p =~ s/${s}oe/$1œ/g;
	$p =~ s/æ/É/g;
	$p =~ s/û/Y/g;
	$p =~ s/à|â/ɑ/g;
	$p =~ s/ê|è|ë/ɛ/g;
	$p =~ s/é/É/g;
	$p =~ s/[ʒg]ea([tds])/ʒa$1/g;
	$p =~ s/e[e]([tdn])/I$1/g;
	$p =~ s/ph/f/g;
	$p =~ s/cch/kk/g;
	$p =~ s/(sc|c|s)h/ʃ/g;

	# 1 Voyelles
	$p =~ s/ey($voy)/ɛJ$1/g;
	$p =~ s/($voy)s($voy)/$1z$2/g;	# se -> ze
	$p =~ s/oy($voy)/waJ$1/g;
	$p =~ s/y($voy)/J$1/g;
	$p =~ s/oine/wANe/g;
	$p =~ s/in($voy)/iN$1/g;
	$p =~ s/ou?in/wɛ̃/g;
	$p =~ s/oi/wa/g;
	$p =~ s/aill/ɑJ/g;
	$p =~ s/ou(ɑJ)/w$1/g;
	$p =~ s/euill?e?/ŒJ/g;
	$p =~ s/ueill?e?/ŒJ/g;
	$p =~ s/ouill/UJ/g;
	$p =~ s/(œ|oe)il+/ŒJ/g;
	$p =~ s/œu/Œ/g;
	$p =~ s/œ/É/g;
	$p =~ s/eill?e?/ɛJ/g;
	$p =~ s/vill(ois|ien|j|w)/viL$1/g;
	$p =~ s/${s}vill/$1vil/g;
	$p =~ s/ill/iJ/g;
	$p =~ s/JJ/J/g;
	$p =~ s/nou/Nou/g;
	$p =~ s/ou([ia]|ɛ̃|ɛ|É)/w$1/g;
	$p =~ s/oue($cons)/wɛ$1/g;

	$p =~ s/y/i/g;
	$p =~ s/eu[xs]?$e/ø$1/g;
	$p =~ s/e(?:u|û)(d?)/ø$1/g;
	$p =~ s/ø($cons)/œ$1/g;
	$p =~ s/œ([zs])/ø$1/g;
	$p =~ s/an([ow])/AN$1/g;
	$p =~ s/ou/U/g;
	$p =~ s/ann/AN/g;
	$p =~ s/onn/ɔn/g;
	$p =~ s/inn/IN/g;
	$p =~ s/omm/ɔm/g;
	$p =~ s/mn/MN/g;
	$p =~ s/o[nm]($cons|s?\b)/ɔ̃$1/g;
	$p =~ s/o($cons)/ɔ$1/g;
	$p =~ s/e?au/O/g;
	$p =~ s/e?oi/wa/g;
	#$p =~ s/i([$voy])[^es]/j$1/g;
	$p =~ s/ann/An/g;
	$p =~ s/em([bp])/ɑ̃$1/g;
	$p =~ s/e([nt])\1/ɛ$1/g;
	$p =~ s/en($voy)/ən$1/g;
	$p =~ s/an($voy)/An$1/g;
	$p =~ s/am[mh]/AM/g;
	$p =~ s/anh/AN/g;
	$p =~ s/im[mh]/IM/g;
	$p =~ s/($voy)n($voy)/$1N$2/g;
	$p =~ s/[ae][nm]($cons)/ɑ̃$1/g;
	$p =~ s/[ae]n(($cons)?)/ɑ̃$1/g;
	$p =~ s/${s}a?in($cons)/$1ɛ̃$2/g;
	$p =~ s/($cons)[ea]?in($cons)/$1ɛ̃$2/g;
	$p =~ s/($cons)[ea]?in$e/$1ɛ̃$2/g;
	$p =~ s/(\b|$cons)(i?)(ain|en|i[nm])h?($cons)/$1$2ɛ̃$4/g;
	$p =~ s/$s(?:ain|en|[iy][nm])($cons)/$1ɛ̃$2/g;
	#$p =~ s/(\b|$cons)(i?)(an)(\b|$cons)/$1$2ɑ̃$4/g;
	$p =~ s/e([t])/ə$1/g;
	$p =~ s/e(($cons){2})/ɛ$1/g;
	$p =~ s/e($cons)\1/ɛ$1$1/g;
	$p =~ s/e([x])/ɛ$1/g;
	$p =~ s/e([gm])s?$e/ɛ$1/g;
	$p =~ s/[ae]i/ɛ/g;
	$p =~ s/i(ɛ|ɛ̃|É|ɑ̃|ɔ|ɔ̃|ø|œ|ɑ|[aou])/J$1/g;
	
	# Consonnes
	$p =~ s/t{2}/T/gi;
	#$p =~ s/s{2}/S/gi;
	$p =~ s/($voy)sh?($voy)/$1z$2/g;
	$p =~ s/cc([aoUuy]|ɔ|ɔ̃)/k$1/g;
	$p =~ s/($voy)cc($ei)/$1ks$2/g;
	$p =~ s/cc($ei)/ks$1/g;
	$p =~ s/cc/k/g;
	$p =~ s/c($aou)/k$1/g;
	$p =~ s/c($ei|J)/s$1/g;
	$p =~ s/c/k/g;
	$p =~ s/gn($voy)/ɲ$1/g;
	$p =~ s/g($aou)/G$1/g;
	$p =~ s/g($ei)/ʒ$1/g;
	$p =~ s/j/ʒ/g;
	$p =~ s/ge$e/ʒ$1/g;
	$p =~ s/g$e/G$1/g;
	$p =~ s/qu($voy)/k$1/g;
	$p =~ s/gu($voy)/G$1/g;
	$p =~ s/x/ks/g;
	$p =~ s/g/G/g;
	
	# Doubles
	#$p =~ s/([trdp])\1/$1/g;
	#$p =~ s/($voy)\1/$1/g;
	
	# Derniers
	$p =~ s/(ɲ)[Jj]/$1/g;
	$p =~ s/ant?s?$e/ɑ̃$1/g;
	$p =~ s/u/Y/g;
	$p =~ s/Y([iIa]|É)/ɥ$1/g;
	$p =~ s/q/k/g;
	$p =~ s/($voy)[ts]$e/$1$2/g;
	$p =~ s/([^\b]{2})e /$1 /g;
	$p =~ s/(e|ə)$//g;	# e muet
	$p =~ s/e/ə/g;	# e caduc
	$p =~ s/h//g;
	
	$p = SAMPA_API($p);
	$p =~ s/($cons)\1/$1/g;
	$p =~ s/^ +//;
	$p =~ s/ +$//;
	
	return $p;
}

sub SAMPA_API
{
	my ($w) = @_;
	$w =~ s/([A-Z])/\l$1/g;
	$w =~ s/ŒŒ/œ̃/g;
	$w =~ s/Œ/œ/g;
	$w =~ s/r/ʁ/g;
	$w =~ s/g/ɡ/g;
	$w =~ s/É/e/g;
	return $w;
}

sub count_letters
{
	my ($dbh, $lang, $nocase) = @_;
	
	# Get all articles titles
	my $articles = get_articles($dbh, $lang);
	my $n = @$articles;
	print STDERR "$n articles in lang $lang\n";

	# Count every letter (diacritics included)
	my ($letters, $stats) = letters($articles, $nocase);
	
	# List all letters counts
	print_letters($letters, $stats, $lang);
}

sub letters
{
	my ($articles, $nocase) = @_;
	my %count = ();
	my %stats = ();
	
	foreach my $word (@$articles) {
		$stats{"words"}++;
		$word = decode('utf8', $word);
		my @chars = split(//, $word);
		my %word_count = ();
		foreach my $c (@chars) {
			$c = lc($c) if $nocase;
			$count{$c}{"letters"}++;
			$word_count{$c}++;
			$stats{"letters"}++;
		}
		
		# Only count each letter once for each word
		foreach my $c (keys %word_count) {
			$count{$c}{"words"}++;
		}
	}
	return \%count, \%stats;
}

sub print_letters
{
	my ($letters, $stats, $lang) = @_;
	
	print STDOUT "#Language: $lang\n";
	print "#Letters: $stats->{'letters'}\n";
	print "#Words: $stats->{'words'}\n";
	foreach my $char (sort { $letters->{$b}->{"letters"} <=> $letters->{$a}->{"letters"} } keys %$letters) {
		my @line = (
			formater(encode('utf8', $char)),
			$letters->{$char}->{'letters'},
			$letters->{$char}->{'words'},
			sprintf("%.3f", $letters->{$char}->{'letters'} / $stats->{'letters'} * 100),
			sprintf("%.3f", $letters->{$char}->{'words'} / $stats->{'words'} * 100),
		);
		print STDOUT join("\t", @line) . "\n";
	}
}

sub formater
{
	my $char = shift;
	
	if ($char eq ' ') {
		return "[espace]";
	} elsif ($char eq '.') {
		return "[point]";
	} elsif ($char eq '/') {
		return "[barre oblique]";
	} elsif ($char eq ':') {
		return "[deux-points]";
	}
	return $char;
}

##################################
# MAIN
init();

my $dbh = DBI->connect("dbi:SQLite:dbname=$opt{d}","","");
if ($opt{p}) {
	pronunciations($dbh, $opt{p});
} elsif ($opt{c}) {
	count_letters($dbh, $opt{c}, $opt{I});
}

__END__


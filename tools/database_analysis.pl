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
	NOT l_is_flexion AND
	NOT l_is_gentile
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
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hd:p:c:I', \%opt ) or usage();
	usage() if $opt{h};
	usage("Database needed (-d)") unless $opt{d};
	usage("Type of analysis needed") if not $opt{p} xor $opt{c};
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
	GROUP BY a_title
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
	my $same = expected_pronunciation($articles, $lang);
	my $nsame = @$same;
	print STDERR "$nsame articles with expected pronunciation " . sprintf("(%.2f %%)\n", $nsame/$n*100);

	# List all words where the pronunciation is different from expected
}

sub expected_pronunciation
{
	my ($articles, $lang) = @_;
	
	my @same = ();
	foreach my $a (@$articles) {
		push @same, $a if check_pronunciation($a, $lang);
	}
	return \@same;
}

sub check_pronunciation
{
	my ($art, $lang) = @_;

	# Check French
	if ($lang eq 'fr') {
		my $pron = pron_in_fr($art);
		
		if ($pron) {
			my $diff = different($art->{p_pron}, $pron);
			my $diffest = very_different($art->{p_pron}, $pron);
			my $diffs = '';
			if ($diff) {
				if ($diffest) {
					$diffs = 'nope';
				} else {
					$diffs = 'OK?';
				}
			} else {
				$diffs = 'OK';
			}
			print STDOUT "$diffs\t$art->{'a_title'}\t'$pron'\t'".clean_pron($art->{p_pron})."'\n";
			return not $diff;
		} else {
			return 0;
		}
	}
	return 1;
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
	
	$m =~ s/([\s\.‿  ])+//g;
	$m =~ s/ə//g;
	return $m;
}

sub simplest
{
	my ($m) = @_;
	
	$m = simple($m);
	$m =~ s/ɑ/a/g;
	$m =~ s/ɔ/o/g;
	$m =~ s/ɛ/e/g;
	$m =~ s/ʁ/r/g;
	$m =~ s/ɡ/g/g;
	$m =~ s/j/i/g;
	$m =~ s/(.)\1/$1/g;
	return $m;
}

sub clean_pron
{
	my ($pron) = @_;
	$pron =~ s/[\.,;:!\?]//g;
	$pron =~ s/'|’/ /g;
	return $pron;
}

sub pron_in_fr
{
	my ($art) = @_;
	my $w = $art->{'a_title'};
	my $typ = $art->{'l_type'} ? $art->{'l_type'} : '';
	
	if ($w =~ /\b([A-Z\.,;!\(\)+\-]|−)+\b/ or $w =~ /[0-9]/) {
		return '';
	}
	my $p = clean_pron(lc($w));
	
	my $voy = "[eaoAiIuUY]";
	$voy .= "|" . "ɛ|ɛ̃|É|È|œ|œ̃|ɑ|ɑ̃|ə|ɔ|ɔ̃|ø";
	$voy .= "|" . decode('utf8',"ɛ|ɛ̃|É|È|œ|œ̃|ɑ|ɑ̃|ə|ɔ|ɔ̃|ø");
	my $cons = "[cbdfgGklmnpqrRsStTvz]";
	$cons .= "|" . decode('utf8', "ɡ|ʒ|ʁ|ʃ");
	my $ei = decode("utf8", "i|É|ə|œ");
	$ei .= "|e|i|É|ə|œ";
	my $s = '(\s|^)';
	my $e = '(\s|$)';
	
	# Mots
	$p =~ s/\b([ldms])es\b/$1ɛ\b/g;
	$p =~ s/\b([ldms])e\b/$1ə/g;
	$p =~ s/\bet\b/É/g;
	$p =~ s/\buns?\b/œ̃/g;
	
	# Terminaisons courantes
	if ($typ eq 'verb' and not $art->{'l_is_locution'}) {
		$p =~ s/ez\b/É/g;
		$p =~ s/e(nt|s)?\b//g;
		$p =~ s/ent\b//g;
	} else {
		$p =~ s/tions?\b/SJɔ̃/g;
	}
	$p =~ s/er\b/É/g;
	$p =~ s/ex\b/ɛks/g;
	$p =~ s/ert\b/ɛʁ/g;
	$p =~ s/(ots?|e?aux?)\b/O/g;
	$p =~ s/ements?\b/əmɑ̃/g;
	$p =~ s/ments?\b/mɑ̃/g;
	$p =~ s/an[tc]s?\b/ɑ̃/g;
	$p =~ s/antes?\b/ɑ̃t/g;
	$p =~ s/ient?s?\b/Jɛ̃/g;
	$p =~ s/ets?$e/ɛ$1/g;
	$p =~ s/ettes?\b/ɛT/g;
	$p =~ s/ès\b/ɛS/g;
	$p =~ s/iers?\b/JÉ/g;
	$p =~ s/ompt/ɔ̃t/g;
	$p =~ s/amps/ɑ̃/g;
	$p =~ s/on[dt]s?\b/ɔ̃/g;
	$p =~ s/oses?\b/oz/g;
	$p =~ s/eux\b/ø/g;
	$p =~ s/ails?\b/ɑJ/g;
	$p =~ s/ards?$e/ɑʁ$1/g;
	$p =~ s/eds?\b/É/g;
	$p =~ s/($cons)els?\b/ɛl/g;

	$p =~ s/tionn/SJɔn/g;
	$p =~ s/euse/øz/g;
	
	$p =~ s/\bantis/ɑ̃TIS/g;
	
	$p =~ s/[sx](\s|$)//g;
	$p =~ s/($voy)[pdt]\b/$1/g;
	$p =~ s/ç/S/g;
	$p =~ s/î|ï/I/g;
	$p =~ s/ô/O/g;
	$p =~ s/oû/U/g;
	$p =~ s/à|â/ɑ/g;
	$p =~ s/ê|è/ɛ/g;
	$p =~ s/é/É/g;

	
	# 1 Voyelles
	$p =~ s/($voy)s($voy)/$1z$2/g;	# se -> ze
	$p =~ s/oy($voy)/waJ$1/g;
	$p =~ s/y($voy)/J$1/g;
	$p =~ s/ou?in/wɛ̃/g;
	$p =~ s/ou([ia]|ɛ̃|ɛ)/w$1/g;
	$p =~ s/oue($cons)/wɛ$1/g;
	$p =~ s/oi/wa/g;
	$p =~ s/aill/ɑJ/gi;
	$p =~ s/euill?e?/ŒJ/g;
	$p =~ s/ueill?e?/ŒJ/g;
	$p =~ s/(œ|oe)il/ŒJ/g;
	$p =~ s/œ/É/g;
	$p =~ s/eill?e?/ɛJ/g;
	$p =~ s/vill/vil/g;
	$p =~ s/ill/iJ/g;

	$p =~ s/y/i/g;
	$p =~ s/eu[xs]?$/ø/g;
	$p =~ s/eu/ø/g;
	$p =~ s/ø($cons)/œ$1/g;
	$p =~ s/ou/U/g;
	$p =~ s/onn/ɔn/g;
	$p =~ s/omm/ɔm/g;
	$p =~ s/o[nm]($cons|s?\b)/ɔ̃$1/g;
	$p =~ s/o($cons)/ɔ$1/g;
	$p =~ s/e?au/O/g;
	$p =~ s/e?oi/wa/g;
	#$p =~ s/i([$voy])[^es]/j$1/g;
	$p =~ s/ann/An/g;
	$p =~ s/e([nt])\1/ɛ$1/g;
	$p =~ s/en($voy)/ən$1/g;
	$p =~ s/an($voy)/An$1/g;
	$p =~ s/mn/MN/g;
	$p =~ s/[ae][nm]($cons)/ɑ̃$1/g;
	$p =~ s/[ae]n(($cons)?)/ɑ̃$1/g;
	$p =~ s/(\b|$cons)(i?)(ain|en|in)h?(\b|$cons)/$1$2ɛ̃$4/g;
	$p =~ s/\b(ain|en|in)($cons)/ɛ̃$2/g;
	#$p =~ s/(\b|$cons)(i?)(an)(\b|$cons)/$1$2ɑ̃$4/g;
	$p =~ s/e([t])/ə$1/g;
	$p =~ s/e(($cons){2})/ɛ$1/g;
	$p =~ s/e($cons)\1/ɛ$1$1/g;
	$p =~ s/e([x])/ɛ$1/g;
	$p =~ s/ai/ɛ/g;
	$p =~ s/i(ɛ|ɛ̃|É|ɑ̃|ɔ|ɔ̃|ø|œ|[aou])/J$1/g;
	
	# Consonnes
	$p =~ s/($voy)sh?($voy)/$1z$2/g;
	$p =~ s/cc([aoUuy]|ɔ|ɔ̃)/k$1/g;
	$p =~ s/($voy)cc($ei)/$1ks$2/g;
	$p =~ s/cc($ei)/ks$1/g;
	$p =~ s/cc/k/g;
	$p =~ s/c([lraouU]|ɔ)/k$1/g;
	$p =~ s/c($ei|J)/s$1/g;
	$p =~ s/(sc|c|s)h/ʃ/g;
	$p =~ s/c/k/g;
	$p =~ s/ph/f/g;
	$p =~ s/gn($voy)/ɲ$1/g;
	$p =~ s/g([aoUY]|ɔ)/G$1/g;
	$p =~ s/g($ei)/ʒ$1/g;
	$p =~ s/j|ge$/ʒ/g;
	$p =~ s/qu($voy)/k$1/g;
	$p =~ s/gu($voy)/G$1/g;
	$p =~ s/x/ks/g;
	$p =~ s/g/G/g;
	
	# Doubles
	$p =~ s/($cons)\1/$1/g;
	#$p =~ s/([trdp])\1/$1/g;
	#$p =~ s/($voy)\1/$1/g;
	
	# Derniers
	$p =~ s/ant?s?\b/ɑ̃/g;
	$p =~ s/u/Y/g;
	$p =~ s/Y[iI]/ɥi/g;
	$p =~ s/($voy)[ts]\b/$1/g;
	$p =~ s/([^\b]{2})e /$1 /g;
	$p =~ s/e\b//g;	# e muet
	$p =~ s/e/ə/g;	# e caduc
	$p =~ s/h//g;
	
	return SAMPA_API($p);
}

sub SAMPA_API
{
	my ($w) = @_;
	$w =~ tr/AYUIOJGMNST/ayuiojgmnst/;
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


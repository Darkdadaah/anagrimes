#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;
use DBI;
use Encode;

our %opt;	# Getopt options

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
	
	my $query = "SELECT DISTINCT(a_title) FROM articles JOIN lexemes ON a_artid=l_artid WHERE l_lang=?";
	return $dbh->selectcol_arrayref($query, undef, $lang);
}

sub get_articles_prons
{
	my ($dbh, $lang) = @_;
	
	my $query = "SELECT a_title, p_pron FROM entries WHERE l_lang=? AND NOT p_pron IS NULL GROUP BY a_title";
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
		my $pron = pron_in_fr($art->{'a_title'});
		
		if ($pron) {
			my $diff = different($art->{p_pron}, $pron);
			my $diffs = $diff ? ':-(' : 'OK';
			print STDOUT "$diffs\t$art->{'a_title'}\t'$pron'\t'$art->{p_pron}'\n";
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

sub simple
{
	my ($m) = @_;
	
	$m =~ s/[\s\.‿ ]+//g;
	$m =~ s/ə//g;
	return $m;
}

sub pron_in_fr
{
	my ($w) = @_;
	
	if ($w =~ /\b([A-Z\.,;!\(\)+\-]|−)+\b/ or $w =~ /[0-9]/) {
		return '';
	}
	my $p = lc($w);
	
	$p =~ s/[\.,;:!\?]//g;
	$p =~ s/'|’/ /g;
	
	my $voy = "eaiuUY";
	$voy .= "ɛÉÈɛ̃œɑ";
	$voy .= decode('utf8', "ɛÉÈɛ̃œɑə");
	my $cons = "bdfGklmnpsStvz";
	$cons .= "ɡʒʁʃ";
	$cons .= decode('utf8', "ɡʒʁʃ");
	
	# Mots
	$p =~ s/\b([ldms])es\b/$1ɛ/g;
	$p =~ s/\b([ldms])e\b/$1ə/g;
	
	# Terminaisons courantes
	$p =~ s/tions?\b/SJɔ̃/g;
	$p =~ s/(ots?|e?aux?)\b/O/g;
	$p =~ s/ements?\b/əmɑ̃/g;
	$p =~ s/ments?\b/mɑ̃/g;
	$p =~ s/ants?\b/ɑ̃/g;
	$p =~ s/antes?\b/ɑ̃t/g;
	$p =~ s/ient?s?\b/Jɛ̃/g;
	$p =~ s/ets?\b/ɛ/g;
	$p =~ s/ettes?\b/ɛT/g;
	$p =~ s/ès\b/ɛS/g;
	$p =~ s/iers?\b/JÉ/g;
	$p =~ s/er\b/É/g;
	
	$p =~ s/s\b//g;
	$p =~ s/ç/S/g;
	
	# 1 Voyelles
	$p =~ s/ï/I/g;
	$p =~ s/é/É/g;
	$p =~ s/ê|è/ɛ/g;
	$p =~ s/e([$cons]{2})/ɛ$1/g;
	$p =~ s/([$voy])s([$voy])/$1z$2/g;	# se -> ze
	$p =~ s/oy([$voy])/waJ$1/g;
	$p =~ s/y([$voy])/J$1/g;
	$p =~ s/y/i/g;
	$p =~ s/ou?in/wɛ̃/g;
	$p =~ s/ou([iaɛ̃ɛ])/w$1/g;
	$p =~ s/oue([$cons])/wɛ$1/g;
	$p =~ s/oi/wa/g;
	$p =~ s/euill?e?/œJ/g;
	$p =~ s/ueill?e?/œJ/g;
	$p =~ s/ille/iJe/g;
	$p =~ s/ails?$/ɑJ/gi;
	$p =~ s/eu[xs]?$/ø/g;
	$p =~ s/(e|œ)u/œ/g;
	$p =~ s/ou/U/g;
	$p =~ s/o([$cons])\1/ɔ$1/g;
	$p =~ s/on([$cons]|s?\b)/ɔ̃$1/g;
	$p =~ s/à|â/ɑ/g;
	$p =~ s/e?au|ô/O/g;
	$p =~ s/e?oi/wa/g;
	$p =~ s/o([^$voy])/ɔ$1/g;
	#$p =~ s/i([$voy])[^es]/j$1/g;
	$p =~ s/e([$cons])\1/ɛ$1/g;
	$p =~ s/an([$cons])/ɑ̃$1/g;
	$p =~ s/(\b|[$cons])(i?)(ain|en|in)h?(\b|[$cons])/$1$2ɛ̃$4/g;
	$p =~ s/\b(ain|en|in)([$cons])/ɛ̃$2/g;
	$p =~ s/(\b|[$cons])(i?)(an)(\b|[$cons])/$1$2ɑ̃$4/g;
	$p =~ s/iɛ̃/Jɛ̃/g;
	$p =~ s/iɛ/Jɛ/g;
	$p =~ s/ia/Ja/g;
	$p =~ s/ai/ɛ/g;
	
	# Consonnes
	$p =~ s/cc/k/g;
	$p =~ s/cc([aoɔUiuy])/k$1/g;
	$p =~ s/cc([eÉiJ])/ks$1/g;
	$p =~ s/c([lraoɔuU])/k$1/g;
	$p =~ s/c([eÉiJ])/s$1/g;
	$p =~ s/(sc|c|s)h/ʃ/g;
	$p =~ s/c/k/g;
	$p =~ s/ph/f/g;
	$p =~ s/gn([$voy])/ɲ$1/g;
	$p =~ s/g([aoɔUiÉ])/ʒ$1/g;
	$p =~ s/gu/G/g;
	$p =~ s/j|ge|g$/ʒ/g;
	$p =~ s/qu([ei])/k$1/g;
	$p =~ s/x/ks/g;
	
	# Doubles
	$p =~ s/([$cons])\1/$1/g;
	$p =~ s/([$voy])\1/$1/g;
	
	# Derniers
	$p =~ s/ant?s?\b/ɑ̃/g;
	$p =~ s/u/Y/g;
	$p =~ s/([$voy])[ts]\b/$1/g;
	$p =~ s/([^\b]{2})e /$1 /g;
	$p =~ s/e\b//g;	# e muet
	$p =~ s/e/ə/g;	# e caduc
	$p =~ s/h//g;
	
	return SAMPA_API($p);
}

sub SAMPA_API
{
	my ($w) = @_;
	$w =~ tr/YUIJGOST/yuijgost/;
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


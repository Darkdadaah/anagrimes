#!/usr/bin/perl -w

# Wiktionnaire parser
# Author: Matthieu Barba
#
# This module contains tools to manipulate and transform pronunciations

package wiktio::pron_tools ;

use Exporter ;
@ISA=('Exporter') ;
@EXPORT_OK = qw(
	cherche_prononciation
	section_prononciation
	simple_prononciation
) ;

use strict ;
use warnings ;

sub cherche_prononciation
{
	my ($line, $lang) = @_ ;
	my %pron = () ;
	my $p = '' ;
	
	if ($line =~ /^'''.+?''' ?.*?\{\{pron\|([^\|\}\r\n]+?)\}\}/ and $1 and not $line =~ /SAMPA/) {
		$p = $1 ;
		$pron{$p} = 1 ;
	}
	# Ancien
	elsif ($line =~ /^'''.+?''' ?.*?\/([.^\/]+?)\// and $1 and not $line =~ /SAMPA/) {
		$p = $1 ;
		$pron{$p} = 1 ;
	}
	
	# Juste une prononciation dans un modèle
# 				/\|ps=.+\|/
	elsif ($line =~ /\| ?(pm|ps|pron|pron2|pron3)=([^\|\}\r\n]+?)\|/) {
		$p = $2 ;
		$p =~ s/[ .,:\/]//g ;
		$pron{$p} = 1 ;
	}
	elsif ($line =~ /\| ?(pron|pron2)=([^\|\}\r\n]+?)\s*\| ?(pron2|pron3)=([^\|\}\r\n]+?)\s*(\||\}\})/) {
		$p = $2 ;
		$p =~ s/[ .,:\/]//g ;
		$pron{$p} = 1 ;
	}
	
	# Inv -__-
	elsif ($line =~ /\{\{fr-inv\|([^\|\}\r\n]+?)\}\}/ and $1) {
		$p = $1 ;
		$pron{$p} = 1 ;
	}
	###########################
	# TRADIT et ORTHO1990
	elsif ($line =~ /\{\{fr-(r[ée]g|ind)\|\{\{[^\|\}\r\n]+?\}\}\|([^\|\}\r\n]+?)\}\}/) {
		$p = $2 ;
		$pron{$p} = 1 ;
	}
	elsif ($line =~ /\{\{fr-(r[ée]g|ind)\|mf=oui\|\{\{[^\|\}\r\n]+?\}\}\|([^\|\}\r\n]+?)\}\}/) {
		$p = $2 ;
		$pron{$p} = 1 ;
	}
	elsif ($line =~ /\{\{fr-(r[ée]g|ind)\|([^\|\}\r\n]+?)\|\{\{[^\|\}\r\n]+?\}\}\}\}/) {
		$p = $2 ;
		$pron{$p} = 1 ;
	}
	elsif ($line =~ /\{\{fr-(r[ée]g|ind)\|mf=oui\|([^\|\}\r\n]+?)\|\{\{[^\|\}\r\n]+?\}\}\}\}/) {
		$p = $2 ;
		$pron{$p} = 1 ;
	}
	
	# rég
	elsif ($line =~ /\{\{fr(-accord)?-r(é|e)g\|([^\}\r\n]+?)\}\}/ and $3) {
		my $li = $3 ;
		my @par = split(/\|/, $li) ;
		foreach my $p (@par) {
			if (not $p =~ /=/) {
				$pron{$p} = 1 ;
			} elsif ($p =~ /^pron2=(.+?)$/) {
				$pron{$1} = 1 ;
			}
		}
	}
	
	# Lettre
	elsif ($line =~ /\{\{lettre\|[^\|\}\r\n]+?\|[^\|\}\r\n]+?\|([^\|\}\r\n]+?)\}\}/ and $1) {
		$p = $1 ;
		$pron{$p} = 1 ;
	}
	# cons
	elsif ($line =~ /\{\{fr-accord-cons\|([^\|\}\r\n]+?)\|[^\|\}\r\n]+?\|?.*?\}\}/ and $1) {
		$p = $1 ;
		$pron{$p} = 1 ;
	}
	
	# 4 paramètres
	elsif ($line =~ /\{\{fr-accord-([^\|]+?)\|([^\|\}\r\n]+?)\|([^\|\}\r\n]+?)\|([^\|\}\r\n]+?)\|([^\|\}\r\n]+?)\}\}/) {
		my ($term, $p1, $p2, $p3, $p4) = ($1,$2,$3,$4,$5) ;
		$p1 =~ s/^[1-9]=// ;
		$p2 =~ s/^[1-9]=// ;
		$p3 =~ s/^[1-9]=// ;
		$p4 =~ s/^[1-9]=// ;
		if ($term eq 'if') {	$p = $p3.$p4.'f' ; }
		else { print STDERR "Modèle 4p non reconnu:\t$term\t$p1\t$p2\t$p3\t$p4\t$line" ; }
		$pron{$p} = 1 ;
	}
	
	# 3 paramètres
	elsif ($line =~ /\{\{fr-accord-([^\|]+?)\|([^\|\}\r\n]+?)\|([^\|\}\r\n]+?)\|([^\|\}\r\n]+?)\}\}/) {
		my ($term, $p1, $p2, $p3) = ($1,$2,$3,$4) ;
		$p1 =~ s/^[1-9]=// ;
		$p2 =~ s/^[1-9]=// ;
		$p3 =~ s/^[1-9]=// ;
		if ($term eq 'ot') {	$p = $p2.'o' ; }
		elsif ($term eq 'eur' and $p2 =~ /rice=.+/) {	$p = $p3.'œʁ' ; }
		elsif ($term eq 'eur' and $p3 =~ /rice=.+/) {	$p = $p2.'œʁ' ; }
		else { print STDERR "Modèle 3p non reconnu:\t$term\t$p1\t$p2\t$p3\t$line" ; }
		$pron{$p} = 1 ;
# 					print "$title = $term\t$p1\t$p\n" ;
	}
	
	# 2 paramètres
	elsif ($line =~ /\{\{fr-accord-([^\|]+?)\|([^\|\}\r\n]+?)\|([^\|\}\r\n]+?)\}\}/) {
		my ($term, $p1, $p2) = ($1,$2,$3) ;
		$p1 =~ s/^[1-9]=// ;
		$p2 =~ s/^[1-9]=// ;
# 					if ($term eq 'ind') { $p = $p1 ; }
		if ($term eq 'en' and $p1 =~ /un_n=/) {	$p = $p2.'ɛ̃' ; }
		elsif ($term eq 'en' and $p2 =~ /un_n=/) {	$p = $p1.'ɛ̃' ; }
		elsif ($term eq 'en' and $p2 =~ /pron2=/) {	$p = $p1.'ɛ̃' ; }
		elsif ($term eq 'et' and $p1 =~ /è=.+/) {	$p = $p2.'ɛ' ; }
		elsif ($term eq 'et' and $p2 =~ /è=.+/) {	$p = $p1.'ɛ' ; }
		elsif ($term eq 'al' or $term eq 'mf-al') {	$p = $p2.'al' ; }
		elsif ($term eq 'eau') {	$p = $p2.'o' ; }
		elsif ($term eq 'eur') {	$p = $p2.'œʁ' ; }
		elsif ($term eq 'eux') {	$p = $p2.'ø' ; }
		elsif ($term eq 'er') {	$p = $p2.'e' ; }
		elsif ($term eq 'if') {	$p = $p2.'if' ; }
		elsif ($term eq 'ot') {	$p = $p2.'o' ; }
		elsif ($term eq 'y') {	$p = $p2.'i' ; }
		elsif ($term eq 'oux') {	$p = $p2.'u' ; }
		elsif ($term eq 'ail') {	$p = $p2.'aj' ; }
		elsif ($term eq 's') { $p = $p1 ; }
		else { print STDERR "Modèle 2p non reconnu:\t$term\t$p1\t$p2\t$line" ; }
		$pron{$p} = 1 ;
	}
	
	# 1 paramètre
	elsif ($line =~ /\{\{fr-accord-([^\|]+?)\|([^\|\}\r\n]+?)\}\}/) {
		my ($term, $p1) = ($1,$2) ;
		$p1 =~ s/^[1-9]=// ;
		if ($term eq 'mf-x') { $p = $p1 ; }
		elsif ($term eq 'an' or $term eq 'an(n)') {	$p = $p1.'ɑ̃' ; }
		elsif ($term eq 'el') {	$p = $p1.'ɛl' ; }
		elsif ($term eq 'en' or $term eq 'in') {	$p = $p1.'ɛ̃' ; }
		elsif ($term eq 'on') { $p = $p1.'ɔ̃' ; }
		elsif ($term eq 'et') {	$p = $p1.'ɛ' ; }
		elsif ($term eq 's') { $p = $p1 ; }
		else { print STDERR "Modèle 1p non reconnu:\t$term\t$p1\t$line" ; }
		$pron{$p} = 1 ;
# 					die if $title eq 'oiseau' ;
	}
	my @prononciations = keys %pron ;
	@prononciations = check_prononciation(@prononciations) ;
	return @prononciations ;
}

sub section_prononciation
{
	my ($lines) = @_ ;
	my %pron = () ;
	my $p = '' ;
	
	foreach my $line (@$lines) {
		if ($line =~ /^\* ?\{\{pron\|([^\|\}\r\n]+?)\}\}/ and $1 and not $line =~ /SAMPA/) {
			$p = $1 ;
			$pron{$p} = 1 ;
		}
		elsif ($line =~ /^\* .+ ?\{\{pron\|([^\|\}\r\n]+?)\}\}/ and not $line =~ /SAMPA/ and $1) {
			$p = $1 ;
			$pron{$p} = 1 ;
		}
		elsif ($line =~ /^\* ?\/([^\|\}\/\r\n]+?)\// and $1 and not $line =~ /SAMPA/) {
			$p = $1 ;
			$pron{$p} = 1 ;
		}
		elsif ($line =~ /^\* ?.+ ?\/([^\/]+?)\// and $1 and not $line =~ /SAMPA/) {
			$p = $1 ;
			$pron{$p} = 1 ;
		}
	}
	
	my @prononciations = keys %pron ;
	@prononciations = check_prononciation(@prononciations) ;
	return @prononciations ;
}

sub check_prononciation
{
	my @pron ;
	foreach my $p (@_) {
		if ($p =~ /[0-9@\\"&\?EAOIU]/) {
			print STDERR "Probablement (X-)SAMPA et pas API : $p\n" ;
		} elsif ($p =~ /[g]/) {
			my $p2 = $p ;
			$p2 =~ s/g/ɡ/g ;
			print STDERR "Correction API g : $p -> $p2\n" ;
			push @pron, $p2 ;
		} elsif ($p =~ /[:]/) {
			my $p2 = $p ;
			$p2 =~ s/:/ː/g ;
			print STDERR "Correction API deux-points : $p -> $p2\n" ;
			push @pron, $p2 ;
		} elsif ($p =~ /[']/) {
			my $p2 = $p ;
			$p2 =~ s/'/ˈ/g ;
			print STDERR "Correction API ton : $p -> $p2\n" ;
			push @pron, $p2 ;
		} else {
			push @pron, $p ;
		}
	}
	return @pron ;
}

sub simple_prononciation
{
	my ($pron0) = @_ ;
	my $pron = $pron0 ;
	$pron =~ s/[\.,\- ‿ːˈˌ]//g ;
	return $pron ;
}

1 ;

__END__

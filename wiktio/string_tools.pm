#!/usr/bin/perl -w

# Wiktionnaire parser
# Author: Matthieu Barba
#
# This module contains tools to manipulate and transform strings

package wiktio::string_tools ;

use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use Exporter ;
@ISA=('Exporter') ;
@EXPORT_OK = qw(
	APItoSAMPA
	SAMPAtoAPI
	ascii
	ascii_strict
	transcription
	anagramme
) ;

use strict ;
use warnings ;
use Encode ;
use Unicode::Normalize ;
use wiktio::basic 	qw( $langues_transcrites ) ;

sub unicode_NFKD($)
{
	my ($mot0) = @_ ;
	
	my $mot = $mot0 ;
	
	$mot = NFKD($mot) ;
	$mot =~ s/\pM//g ;
	return $mot ;
}

sub ascii
{
	my ($mot0) = @_ ;
	my $mot = $mot0 ;
	
	# Lettres spéciales
	$mot =~ s/Æ/AE/g ;
	$mot =~ s/æ/ae/g ;
	$mot =~ s/Œ/OE/g ;
	$mot =~ s/œ/oe/g ;
	$mot =~ s/ø/oe/g ;
	$mot =~ s/’/'/g ;
	$mot =~ s/ʻ/'/g ;
# 	
# 	# Enlever les caractères superflus
	$mot =~ s/&amp;//g ;
	$mot =~ s/&quot;//g ;
	$mot =~ s/‿/ /g ;
	$mot =~ s/…/.../g ;
	$mot =~ s/_/ /g ;
	
	$mot = unicode_NFKD($mot) ;
	
	$mot =~ s/[\/!?,><=\$~·;ː:(){}\[\]\\`]//g ;
	
# 	$mot =~ s/[^\x00-\x7F]+//g ;		#Ne garder que les caractères ascii
	
	# Check
	if ($mot eq '') {
# 		print STDERR "Mot vide: '$mot0'\n" ;
		return '' ;
# 	} elsif ($mot =~ /[a-zA-Z0-9]/ and $mot =~ /^[a-zA-Z0-9 \.'&\-]+$/) {
# 		return $mot ;
# 	} else {
# 		print STDERR "Asciisation incomplète : '$mot0' -> '$mot'\n" ;
# 		return '' ;
# 	}
	} else {
		return $mot ;
	}
}

sub ascii_strict
{
	my $mot0 = shift ;
	my $mot = $mot0 ;
	$mot = ascii($mot) ;
	
	# Strict
	$mot =~ s/[\.'\- ]//g ;
	
	return $mot ;
	
# 	if ($mot =~ /^[a-zA-Z0-9]+$/) {
# 		return $mot ;
# 	} else {
# # 		print "non ascii strict: $mot\n" ;
# 		return '' ;
# 	}
}

sub anagramme
{
	my $mot0 = shift ;
	
	my $mot = lc(ascii_strict($mot0)) ;
	
	# Sort
	if ($mot) {
		my @lettres = split('', $mot) ;
		$mot = join('', sort @lettres) ;
	}
	
	# Check
	return $mot ;
}

sub transcription
{
	my ($titre, $langues) = @_ ;
	
	my $transcrit = $titre ;
	foreach my $l (@$langues) {
		if ($langues_transcrites->{'cyrillique'}->{$l}) {
			#############
			# Cyrillique
			
			# Combinaisons
			$transcrit =~ s/([ыи])й$/$1/ ;	# En fin de mot
			$transcrit =~ s/й/i/g ;		# Sinon
			
			$transcrit =~ s/([ийИЙ])ю/$1ou/ ;	# Après voyelle i
			$transcrit =~ s/ю/iou/g ;	# Sinon
			$transcrit =~ s/Ю/Iou/g ;	# Sinon
			
			$transcrit =~ s/([ийИЙ])я/$1a/g ;	# Après voyelle i
			$transcrit =~ s/я/ia/g ;	# Sinon
			$transcrit =~ s/Я/Ia/g ;	# Sinon
			
			# Caractères doublés
			$transcrit =~ s/х/kh/g ;
			$transcrit =~ s/Х/Kh/g ;
			$transcrit =~ s/ц/ts/g ;
			$transcrit =~ s/Ц/Ts/g ;
			$transcrit =~ s/ч/tch/g ;
			$transcrit =~ s/Ч/Tch/g ;
			$transcrit =~ s/ш/ch/g ;
			$transcrit =~ s/Ш/Ch/g ;
			$transcrit =~ s/щ/chtch/g ;
			$transcrit =~ s/Щ/Chtch/g ;
			$transcrit =~ s/у/ou/g ;
			$transcrit =~ s/У/Ou/g ;
			
			# Caractères muets
			$transcrit =~ s/[ЪъЬь]//g ;
			
			# Transcription directe
			$transcrit =~ tr/абвгґдежзіиклмнопрстфыэ/abvggdejziiklmnoprstfye/ ;
			$transcrit =~ tr/АБГҐДЕЖЗІИКЛМНОПРСТФЫЭ/ABGGDEJZIIKLMNOPRSTFYE/ ;
			
			# Non classique
			$transcrit =~ tr/є/e/ ;
			$transcrit =~ tr/Є/E/ ;
			
			# Latinisation (son /j/)
			$transcrit =~ s/ј/y/g ;
			$transcrit =~ s/Ј/y/g ;
			
# 			$transcrit =~ tr/абвгдежзиклмнопрстуф/abvgdejziklmnoprstuf/ ;
# 			print "[$l] transcrit: $transcrit\n" ;
			return $transcrit ;
		}
	}
}

sub APItoSAMPA
{
	my $pron = shift ;
	
 	# Erreurs
	$pron =~ s/ʀ/R/g ;
 	$pron =~ s/ǝ/@/g ;
 	$pron =~ s/·/./g ;
	
	# Translittération
 	$pron =~ s/ɑ/A/g ;
 	$pron =~ s/ɔ/O/g ;
 	$pron =~ s/ɛ/E/g ;
 	$pron =~ s/œ/9/g ;
 	$pron =~ s/ø/2/g ;
 	$pron =~ s/ə/@/g ;
 	$pron =~ s/ʁ/R/g ;
 	$pron =~ s/ʃ/S/g ;
 	$pron =~ s/ŋ/N/g ;
 	$pron =~ s/ɡ/g/g ;
 	$pron =~ s/ɲ/J/g ;
 	$pron =~ s/ʒ/Z/g ;
 	$pron =~ s/ɥ/H/g ;
	
	# Intonations et autres
 	$pron =~ s/̃/~/g ;
 	$pron =~ s/ˈ/"/g ;
 	$pron =~ s/ˌ/%/g ;
 	$pron =~ s/ː/:/g ;
 	$pron =~ s/‿/-\\/g ;
 	$pron =~ s/ʔ/?/g ;
 	$pron =~ s/ /-/g ;
 	
	return $pron ;
}

sub SAMPAtoAPI
{
	my $pron = shift ;
	
	#%s/s\/\(.\+\)\/\(.\+\)\/g/s\/\2\/\1\/g/
	# Erreurs
	$pron =~ s/R/ʀ/g ;
 	$pron =~ s/@/ǝ/g ;
 	$pron =~ s/\./·/g ;
	
	# Translittération
 	$pron =~ s/A/ɑ/g ;
 	$pron =~ s/O/ɔ/g ;
 	$pron =~ s/E/ɛ/g ;
 	$pron =~ s/9/œ/g ;
 	$pron =~ s/2/ø/g ;
 	$pron =~ s/@/ə/g ;
 	$pron =~ s/R/ʁ/g ;
 	$pron =~ s/S/ʃ/g ;
 	$pron =~ s/N/ŋ/g ;
 	$pron =~ s/g/ɡ/g ;
 	$pron =~ s/J/ɲ/g ;
 	$pron =~ s/Z/ʒ/g ;
 	$pron =~ s/H/ɥ/g ;
	
	# Intonations et autres
 	$pron =~ s/~/̃/g ;
 	$pron =~ s/"/ˈ/g ;
 	$pron =~ s/%/ˌ/g ;
 	$pron =~ s/:/ː/g ;
 	$pron =~ s/-\\/‿/g ;
 	$pron =~ s/[?]/ʔ/g ;
 	$pron =~ s/-/ /g ;
 	
	return $pron ;
}

sub SAMPAtoSortKey($)
{
	my $pron0 = shift ;
	my $p = $pron0 ;
	my @splitted = split //, $pron0 ;
	
	# Rejoin commposites (~ etc.)
# 	for (int $i=0; $i<@splitted; $i++) {
# 		
# 	}
	
 	$p =~ s/A~/zzz1/g ;
 	$p =~ s/O~/zzz3/g ;
 	$p =~ s/E~/zzz4/g ;
 	$p =~ s/9~/zzz5/g ;
 	$p =~ s/2~/zzz6/g ;
	
 	$p =~ s/A/a/g ;
 	$p =~ s/o/ozz1/g ;
 	$p =~ s/O/ozz3/g ;
 	
 	$p =~ s/e/ezz1/g ;
 	$p =~ s/@/ezz3/g ;
 	$p =~ s/E/ezz4/g ;
 	$p =~ s/9/ezz5/g ;
 	$p =~ s/2/ezz6/g ;
 	
 	$p =~ s/R/rzzz/g ;
 	$p =~ s/S/czzz/g ;
 	$p =~ s/N/jzzz/g ;
 	$p =~ s/J/gzz1/g ;
 	$p =~ s/Z/gzz3/g ;
 	$p =~ s/u/yzz1/g ;
 	$p =~ s/H/yzz2/g ;
 	$p =~ s/[?:"%]//g ;
 	$p =~ s/\.//g ;
 	$p =~ s/-//g ;
 	$p =~ s/-\\//g ;
	
	return $p ;
}

1 ;

__END__

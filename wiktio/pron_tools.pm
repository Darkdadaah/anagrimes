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

sub cherche_tables
{
	my ($lignes, $lang, $titre) = @_ ;
	
	my @tables = () ;
	
	if ($lang eq 'fr') {
		print "[[$titre]]\t'$lang'\n" if ref($lignes) eq '' ;
		for (my $i=0 ; $i < @$lignes ; $i++) {
			my $ligne = $lignes->[$i] ;
			
			my $table_texte = '' ;
			my %table = () ;
			
			# Détection d'une table?
			if ($ligne =~ /^\{\{$lang-/ or $ligne =~ /^\{\{lettre/) {
				# Oui, c'est une table ! Récupération complète
				chomp($ligne) ;
				$ligne =~ s/\s*\|\s*$// ;
				$table_texte = $ligne ;
				
				# Sur une seule ligne ?
				my $ouverture = ($ligne =~ tr/\{//) ;
				my $fermeture = ($ligne =~ tr/\}//) ;
				my $compte = $ouverture - $fermeture ;
				if ($compte > 0) {
# 					print "Table multiligne...\n" ;
					while ($compte > 0) {
						$i++ ;
						$ligne = $lignes->[$i] ;
						chomp($ligne) ;
						$ligne =~ s/\s*\|\s*$// ;
						$ouverture = ($ligne =~ tr/\{//) ;
						$fermeture = ($ligne =~ tr/\}//) ;
						$compte = $compte + $ouverture - $fermeture ;
						$ligne =~ s/\s*\|\s*// ;
						$ligne = '|'.$ligne ;
						$table_texte .= $ligne ;
					}
				}
# 				print "table finale : $table_texte\n" ;
				
				# Extraction des données
				# Nettoyage externe
				$table_texte =~ s/^\s*\{\{ *(.+) *\}\}\s*$/$1/ ;
# 				print "table nettoyée 1 : $table_texte\n" ;
				# Nettoyage interne
				$table_texte =~ s/\{\{ *([^\}]+) *\}\}//g ;
				$table_texte =~ s/\{\{ *([^\}]+) *\}\}//g ;
				$table_texte =~ s/\{\{ *([^\}]+) *\}\}//g ;
# 				print "table nettoyée 2 : $table_texte\n" ;
				
				# Extraction des champs
				my @champs = split (/\s*\|\s*/, $table_texte) ;
				
				# Titre de la table
				$table{'nom'} = $champs[0] ;
				$table{'nom'} =~ s/^$lang-// ;
				
				# Champs
				my $num = 1 ;
				for (my $j=1; $j < @champs ; $j++) {
					my $texte = $champs[$j] ;
					# Argument?
					if ($texte =~ /(.+)=(.*)/) {
						$table{'arg'}{$1} = $2 ;
					# Numéro?
					} else {
						while ($table{'arg'}{$num}) {
							$num++ ;
						}
						$table{'arg'}{$num} = $texte ;
					}
				}
				
				# Table parsée:
# 				if ($table{'nom'} eq ' ') {
# 					print "[$titre]\tTable parsée: $table_texte $table{'nom'} ($champs[0])\n" ;
# 					foreach my $arg (sort keys %{$table{'arg'}}) {
# 						print "\t'$arg' = '$table{'arg'}{$arg}'\n" ;
# 					}
# 				}
# 				
				push @tables, \%table ;
			}
		}
	}
	
	return \@tables ;
}

sub cherche_prononciation
{
	my ($lignes, $lang, $titre) = @_ ;
	
	if (ref($lignes) eq '') {
		print STDERR "[[$titre]]\tproblème de mise en forme en $lang\n" ;
		return ;
	}
	
	my %pron = () ;
	
	# Prononciation sur la ligne de forme ?
	foreach my $ligne (@$lignes) {
		# Avec {{pron|}}
		if ($ligne =~ /^'''.+?''' ?.*?\{\{pron\|([^\}\r\n]+?)\}\}/) {
			my $p = $1 ;
			if (not $p =~ /[=\|]/) {
				$pron{$p} = 1 ;
			} elsif ($p =~ /^lang=[^\|\}]+\|(.+)$/ or $p =~ /^(.+)\|lang=[^\|\}]+$/) {
				$pron{$1} = 1 ;
			} elsif ($p =~ /^lang=[^\|\}]+\|$/ or $p =~ /^\|lang=[^\|\}]+$/ or $p =~ /^lang=[^\|\}]+$/) {
				# Vide
			} elsif ($p =~ /.\|./ and not $p =~ /=/) {
				print STDERR "[[$titre]]\tProbable résidu X-SAMPA dans {{pron}} (p='$p')\n" ;
			} else {
				print STDERR "[[$titre]]\tFormat de {{pron}} invalide (p='$p')\n" ;
			}
		}
		elsif ($ligne =~ /^'''.+?''' ?.*?\{\{pron\|([^\}\r\n]+?)\} ou \{\{pron\|([^\}\r\n]+?)\}\}\}/) {
			my $p1 = $1 ;
			my $p2 = $2 ;
			if (not $p1 =~ /[=\|]/) {
				$pron{$p1} = 1 ;
			} elsif ($p1 =~ /^lang=.{2,3}\|(.+)$/ or $p1 =~ /^(.+)\|lang=.{2,3}$/) {
				$pron{$1} = 1 ;
# 			} elsif ($p1 =~ /^lang=.{2,3}\|$/ or $p1 =~ /^\|lang=.{2,3}$/) {
				# Vide
			} else {
				print STDERR "[[$titre]]\tFormat de {{pron}} invalide (p1='$p1')\n" ;
			}
			
			if (not $p2 =~ /[=\|]/) {
				$pron{$p2} = 1 ;
			} elsif ($p2 =~ /^lang=.{2,3}\|(.+)$/ or $p2 =~ /^(.+)\|lang=.{2,3}$/) {
				$pron{$1} = 1 ;
# 			} elsif ($p2 =~ /^lang=.{2,3}\|$/ or $p2 =~ /^\|lang=.{2,3}$/) {
				# Vide
			} else {
				print STDERR "[[$titre]]\tFormat de {{pron}} invalide (p2='$p2')\n" ;
			}
		}
		
		# Ancien
		if ($ligne =~ /^'''.+?'''.*?\/([^\/]*?)\/ ou \/([^\/]*?)\//) {
			$pron{$1} = 1 ;
			$pron{$2} = 1 ;
			print STDERR "[[$titre]]\tvieille prononciation de ligne de forme /$1/, /$2/\n" ;
		}
		elsif ( $ligne =~ /^'''.+?'''.*?\/([^\/]*?)\// ) {
			$pron{$1} = 1 ;
			print STDERR "[[$titre]]\tvieille prononciation de ligne de forme /$1/\n" ;
		}
	}
	
	# Extrait les infos de toutes les tables
	my $tables = cherche_tables($lignes, $lang, $titre) ;
	
	if ($lang eq 'fr') {
		for (my $i=0; $i < @$tables; $i++) {
			my $nom = $tables->[$i]->{'nom'} ;
			my $arg = $tables->[$i]->{'arg'} ;
			
			# Pour toutes les tables connues
			if ($nom eq 'inv') {
				$pron{$arg->{1}} = 1 if ($arg->{1}) ;
				$pron{$arg->{pron}} = 1 if ($arg->{pron}) ;
				$pron{$arg->{pron2}} = 1 if ($arg->{pron2}) ;
				$pron{$arg->{pron3}} = 1 if ($arg->{pron3}) ;
				$pron{$arg->{p2s}} = 1 if ($arg->{p2s}) ;
				$pron{$arg->{p2s2}} = 1 if ($arg->{p2s2}) ;
				$pron{$arg->{p2s3}} = 1 if ($arg->{p2s3}) ;
			}
			elsif ($nom eq 'accord-ind') {
				$pron{$arg->{pron}} = 1 if ($arg->{pron}) ;
				$pron{$arg->{pm}} = 1 if ($arg->{pm}) ;
			}
			elsif ($nom eq 'rég' or $nom eq 'reg' or $nom eq 'accord-rég' or $nom eq 'accord-reg') {
				$pron{$arg->{1}} = 1 if ($arg->{1}) ;
				$pron{$arg->{pron2}} = 1 if ($arg->{pron2}) ;
				$pron{$arg->{pron3}} = 1 if ($arg->{pron3}) ;
				$pron{$arg->{p2}} = 1 if ($arg->{p2}) ;
				$pron{$arg->{p3}} = 1 if ($arg->{p3}) ;
			}
			elsif ($nom eq 'accord-mf') {
				$pron{$arg->{ps}} = 1 if ($arg->{ps}) ;
				$pron{$arg->{ps2}} = 1 if ($arg->{ps2}) ;
				$pron{$arg->{ps3}} = 1 if ($arg->{ps3}) ;
				$pron{$arg->{p2s}} = 1 if ($arg->{p2s}) ;
				$pron{$arg->{p2s2}} = 1 if ($arg->{p2s2}) ;
				$pron{$arg->{p2s3}} = 1 if ($arg->{p2s3}) ;
				$pron{$arg->{pron}} = 1 if ($arg->{pron}) ;
				$pron{$arg->{pron2}} = 1 if ($arg->{pron2}) ;
				$pron{$arg->{pron3}} = 1 if ($arg->{pron3}) ;
			}
			elsif ($nom eq 'accord-mixte') {
				$pron{$arg->{pm}} = 1 if ($arg->{pm}) ;
				$pron{$arg->{pm2}} = 1 if ($arg->{pm2}) ;
				$pron{$arg->{pm3}} = 1 if ($arg->{pm3}) ;
				$pron{$arg->{pms}} = 1 if ($arg->{pms}) ;
				$pron{$arg->{pms2}} = 1 if ($arg->{pms2}) ;
				$pron{$arg->{pms3}} = 1 if ($arg->{pms3}) ;
				$pron{$arg->{pron}} = 1 if ($arg->{pron}) ;
				$pron{$arg->{pron2}} = 1 if ($arg->{pron2}) ;
				$pron{$arg->{pron3}} = 1 if ($arg->{pron3}) ;
			}
			# Ne devrait pas etre utilisé comme tel
			elsif ($nom eq 'accord-mixte-reg' or $nom eq 'accord-mixte-rég') {
				my $suff = '' ;
				$suff .= $arg->{psufm} if ($arg->{psufm}) ;
				$suff .= " $arg->{pinv}" if ($arg->{pinv}) ;
				$pron{$arg->{2}.$suff} = 1 if ($arg->{2}) ;
				$pron{$arg->{pron2}.$suff} = 1 if ($arg->{pron2}) ;
				$pron{$arg->{pron3}.$suff} = 1 if ($arg->{pron3}) ;
				print STDERR "[[$titre]]\tmodèle 'fr-$nom' est inapproprié\n" ;
			}
			elsif ($nom eq 'accord-comp-mf' or $nom eq 'accord-comp') {
				my $mot_1 = $arg->{3} ;
				my $mot_2 = $arg->{4} ;
				my $sep = $arg->{'ptrait'} ? $arg->{'ptrait'} : '.' ;
				$sep =~ s/&#32;/ / ;
				
				if ($mot_1 and $mot_2) {
					my $comp = $mot_1 . $sep . $mot_2 ;
					$pron{$comp} = 1 ;
				} elsif ($mot_1 or $mot_2) {
					print STDERR "[[$titre]]\tmodèle 'fr-$nom' mal rempli\n" ;
				}
			}
			# Radical en 1
			elsif ($nom =~ /^accord-(an|el|en|et|in|s|mf-x)$/) {
				my $suff = '' ;
				if    ($1 eq 'an') {	$suff = 'ɑ̃' ;	}
				elsif ($1 eq 'el') {	$suff = 'ɛl' ;	}
				elsif ($1 eq 'en') {	$suff = 'ɛ̃' ;	}
				elsif ($1 eq 'et') {	$suff = 'ɛ' ;	}
				elsif ($1 eq 'in') {	$suff = 'ɛ̃' ;	}
				elsif ($1 eq 's') {	$suff = '' ;	}
				elsif ($1 eq 'mf-x') {	$suff = '' ;	}
				else { print STDERR "[[$titre]] ERREUR SCRIPT : accord non déclaré 'accord-$1'\n"; }
				$pron{$arg->{1}.$suff} = 1 if ($arg->{1}) ;
				$pron{$arg->{pron}.$suff} = 1 if ($arg->{pron}) ;
				$pron{$arg->{pron2}.$suff} = 1 if ($arg->{pron2}) ;
				$pron{$arg->{pron3}.$suff} = 1 if ($arg->{pron3}) ;
			}
			# Radical en 2
			elsif ($nom =~ /^accord-(mf-ail|mf-al|al|if|f|ot|eau|ef|er|eur|eux|oux)$/) {
				my $suff = '' ;
				if ($1 eq 'mf-ail') {	$suff = 'aj' ;	}
				elsif ($1 eq 'mf-al') {	$suff = 'al' ;	}
				elsif    ($1 eq 'al') {	$suff = 'al' ;	}
				elsif ($1 eq 'if') {	$suff = 'if' ;	}
				elsif ($1 eq 'f')  {	$suff = 'f' ;	}
				elsif ($1 eq 'ot') {	$suff = 'o' ;	}
				elsif ($1 eq 'eau') {	$suff = 'o' ;	}
				elsif ($1 eq 'ef') {	$suff = 'ɛf' ;	}
				elsif ($1 eq 'er') {	$suff = 'e' ;	}
				elsif ($1 eq 'eur') {	$suff = 'œʁ' ;	}
				elsif ($1 eq 'eux') {	$suff = 'ø' ;	}
				elsif ($1 eq 'oux') {	$suff = 'u' ;	}
				else { print STDERR "[[$titre]] ERREUR SCRIPT : accord non déclaré 'accord-$1'\n"; }
				$pron{$arg->{2}.$suff} = 1 if ($arg->{2}) ;
				$pron{$arg->{pron}.$suff} = 1 if ($arg->{pron}) ;
				$pron{$arg->{pron2}.$suff} = 1 if ($arg->{pron2}) ;
				$pron{$arg->{pron3}.$suff} = 1 if ($arg->{pron3}) ;
			}
			elsif ($nom eq 'accord-cons') {
				my $suff = '' ;
				$suff .= " $arg->{pinv}" if $arg->{pinv} ;	# Beuh
				$pron{$arg->{1}.$suff} = 1 if ($arg->{1}) ;
				$pron{$arg->{'pron-ms'}.$suff} = 1 if ($arg->{'pron-ms'}) ;
			}
			elsif ($nom eq 'accord-on') {
				my $suff = 'ɔ̃' ;
				$suff .= " $arg->{pinv}" if $arg->{pinv} ;	# Beuh
				$pron{$arg->{1}.$suff} = 1 if ($arg->{1}) ;
				$pron{$arg->{pron}.$suff} = 1 if ($arg->{pron}) ;
				$pron{$arg->{pron2}.$suff} = 1 if ($arg->{pron2}) ;
				$pron{$arg->{pron3}.$suff} = 1 if ($arg->{pron3}) ;
			}
			elsif ($nom eq 'accord-ain') {
				my $suff = 'ɛ̃' ;
				$pron{$arg->{1}.$suff} = 1 if ($arg->{1}) ;
				$pron{$arg->{'pron-radical'}.$suff} = 1 if ($arg->{'pron-radical'}) ;
				$pron{$arg->{pron2}.$suff} = 1 if ($arg->{pron2}) ;
				$pron{$arg->{pron3}.$suff} = 1 if ($arg->{pron3}) ;
			}
			elsif ($nom eq 'lettre') {
				$pron{$arg->{3}} = 1 if ($arg->{3}) ;
			}
			elsif ($nom eq 'accord-personne') {
				# Impossible de déterminer la prononciation du mot vedette
			}
			elsif ($nom eq 'verbe-flexion') {
				# rien, pas une table d'accord
			}
			else {
			# TABLE INCONNUE ? DIABLE !
				print STDERR "[[$titre]]\tTable $lang inconnue: '$nom'" ;
				print STDERR " (paramètres: " ;
				my @arg_texte = () ;
				foreach my $a (sort keys %$arg) {
					push @arg_texte, "$a=$arg->{$a}" ;
				}
				print STDERR join(' | ', @arg_texte), " )\n" ;
			}
		}
	}
	
	my @prononciations = keys %pron ;
	@prononciations = sort (check_prononciation(\@prononciations, $titre)) ;
	return \@prononciations ;
}

sub section_prononciation
{
	my ($lignes, $titre) = @_ ;
	
	my %pron = () ;
	my $p = '' ;
	
	foreach my $ligne (@$lignes) {
		if ($ligne =~ /^\* ?\{\{pron\|([^\|\}\r\n]+?)\}\}/ and $1 and not $ligne =~ /SAMPA/) {
			$p = $1 ;
			$p =~ s/^lang=.{2,3}// ;
			$pron{$p} = 1 if $p ;
		}
		elsif ($ligne =~ /^\* .+ ?\{\{pron\|([^\|\}\r\n]+?)\}\}/ and not $ligne =~ /SAMPA/ and $1) {
			$p = $1 ;
			$p =~ s/^lang=.{2,3}// ;
			$pron{$p} = 1 if $p ;
		}
		elsif ($ligne =~ /^\* ?\/([^\|\}\/\r\n]+?)\// and $1 and not $ligne =~ /SAMPA/) {
			$p = $1 ;
			$pron{$p} = 1 ;
		}
		elsif ($ligne =~ /^\* ?.+ ?\/([^\/]+?)\// and $1 and not $ligne =~ /SAMPA/) {
			$p = $1 ;
			$pron{$p} = 1 ;
		}
	}
	
	my @prononciations = keys %pron ;
	@prononciations = check_prononciation(\@prononciations, $titre) ;
	return @prononciations ;
}

sub check_prononciation
{
	my ($prononciations, $titre) = @_ ;
	my @pron ;
	
	foreach my $p (@$prononciations) {
		if ($p =~ /&.{2,5};/) {
			print STDERR "[[$titre]]	Caractère HTML : $p\n" ;
		}
		if ($p =~ /[0-9@\\"&\?EAOIU]/) {
			print STDERR "[[$titre]]	Probablement (X-)SAMPA et pas API : $p\n" ;
		} elsif ($p =~ /[g]/) {
			my $p2 = $p ;
			$p2 =~ s/g/ɡ/g ;
			print STDERR "[[$titre]]	Correction API g : $p -> $p2\n" ;
			push @pron, $p2 ;
		} elsif ($p =~ /[:]/) {
			my $p2 = $p ;
			$p2 =~ s/:/ː/g ;
			print STDERR "[[$titre]]	Correction API deux-points : $p -> $p2\n" ;
			push @pron, $p2 ;
		} elsif ($p =~ /[']/) {
			my $p2 = $p ;
			$p2 =~ s/'/ˈ/g ;
			print STDERR "[[$titre]]	Correction API ton : $p -> $p2\n" ;
			push @pron, $p2 ;
		} elsif ($p =~ /\/ ou \// or / ou /) {
			print STDERR "[[$titre]]	à dédoubler : $p\n" ;
			my @ou_pron = split(/\/? ou \/?/, $p) ;
			push @pron, @ou_pron ;
		} else {
			push @pron, $p ;
		}
	}
	
	# Corrections simples
	foreach my $p (@pron) {
		# Pas d'espaces en début ou fin
		$p =~ s/^ +// ;
		$p =~ s/ +$// ;
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

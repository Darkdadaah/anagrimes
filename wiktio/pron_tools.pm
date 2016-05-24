#!/usr/bin/perl -w

# Wiktionnaire parser
# Author: Matthieu Barba
#
# This module contains tools to manipulate and transform pronunciations

package wiktio::pron_tools;

use Exporter;
@ISA       = ('Exporter');
@EXPORT_OK = qw(
  cherche_prononciation
  cherche_transcription
  section_prononciation
  simple_prononciation
  extrait_rimes
  nombre_de_syllabes
);

use strict;
use warnings;

use utf8;
use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use wiktio::basic;

my @voyelles = qw( a ɑ ɒ æ e ɛ ɜ ɝ ə i ɪ o œ ɔ u y ɯ ʊ ʌ );
push @voyelles, ( 'ɑ̃', 'ɛ̃', 'œ̃', 'ɔ̃' );

sub cherche_tables {
    my ( $lignes, $lang, $titre ) = @_;

    my @tables = ();

    #if ($lang eq 'fr') {
    for ( my $i = 0 ; $i < @$lignes ; $i++ ) {
        my $ligne = $lignes->[$i];

        my $table_texte = '';
        my %table       = ();

        # Détection d'une table?
        if ( $ligne =~ /^\{\{$lang-/ or $ligne =~ /^\{\{lettre/ ) {

            # Oui, c'est une table ! Récupération complète
            chomp($ligne);
            $ligne =~ s/\s*\|\s*$//;
            $table_texte = $ligne;

            # Sur une seule ligne ?
            my $ouverture = ( $ligne =~ tr/\{// );
            my $fermeture = ( $ligne =~ tr/\}// );
            my $compte    = $ouverture - $fermeture;
            if ( $compte > 0 ) {

                # 					print "Table multiligne...\n";
                while ( $compte > 0 and $lignes->[ $i + 1 ] ) {
                    $i++;
                    $ligne = $lignes->[$i];
                    last if not $ligne;
                    chomp($ligne);
                    $ligne =~ s/\s*\|\s*$//;
                    $ouverture = ( $ligne =~ tr/\{// );
                    $fermeture = ( $ligne =~ tr/\}// );
                    $compte    = $compte + $ouverture - $fermeture;
                    $ligne =~ s/\s*\|\s*//;
                    $ligne = '|' . $ligne;
                    $table_texte .= $ligne;
                }

                # Still open? BAD
                if ( $compte > 0 ) {
                    special_log( 'unclosed_table', $titre, '', $compte );
                }
            }

            # 				print "table finale : $table_texte\n";

            # Extraction des données
            # Nettoyage externe
            $table_texte =~ s/^\s*\{\{ *(.+) *\}\}\s*$/$1/;

            # 				print "table nettoyée 1 : $table_texte\n";
            # Nettoyage interne
            $table_texte =~ s/\{\{ *([^\}]+) *\}\}//g;
            $table_texte =~ s/\{\{ *([^\}]+) *\}\}//g;
            $table_texte =~ s/\{\{ *([^\}]+) *\}\}//g;

            # 				print "table nettoyée 2 : $table_texte\n";

            # Extraction des champs
            my @champs = split( /\s*\|\s*/, $table_texte );

            # Titre de la table
            $table{'nom'} = $champs[0];
            $table{'nom'} =~ s/^$lang-//;

            # Champs
            my $num = 1;
            for ( my $j = 1 ; $j < @champs ; $j++ ) {
                my $texte = $champs[$j];

                # Argument?
                if ( $texte =~ /(.+)=(.*)/ ) {
                    $table{'arg'}{$1} = $2;

                    # Numéro?
                }
                else {
                    while ( defined( $table{'arg'}{$num} ) ) {
                        $num++;
                    }
                    $table{'arg'}{$num} = $texte;
                }
            }

# Table parsée:
# 				if ($table{'nom'} eq ' ') {
# 					print "[$titre]\tTable parsée: $table_texte $table{'nom'} ($champs[0])\n";
# 					foreach my $arg (sort keys %{$table{'arg'}}) {
# 						print "\t'$arg' = '$table{'arg'}{$arg}'\n";
# 					}
# 				}
#
            push @tables, \%table;
        }
    }

    #}

    return \@tables;
}

sub cherche_prononciation {
    my ( $lignes, $lang, $titre, $type, $flexion ) = @_;

    if ( ref($lignes) eq '' ) {
        special_log( 'mef', $titre, '', "en $lang" );
        return;
    }

    my %pron = ();

    # Prononciation sur la ligne de forme ?
    foreach my $ligne (@$lignes) {

        # Avec {{pron|}}
        if ( $ligne =~ /^'''.+?''' ?.*?\{\{pron\|([^\}\r\n]+?)\}\}/ ) {
            my $p = $1;

            # Pron donnée mais sans code langue
            if ( not $p =~ /[=\|]/ ) {
                $pron{$p} = 1;
                special_log( 'bad_pron_nolang', $titre, '', "p='$p'" );

                # Pron donnée avec la langue donnée en paramètre lang=
            }
            elsif ($p =~ /^lang=[^\|\}]+\|(.*)$/
                or $p =~ /^(.*)\|lang=[^\|\}]+$/
                or $p =~ /^(\s?)lang=[^\|\}]+$/ )
            {
                $pron{$1} = 1 if $1;

                # Vide ou non, avec code langue
            }
            elsif ( $p =~ /^([^\|\}]*)\|([^\|\}]+)$/ ) {
                $pron{$1} = 1 if $1;

                # Une erreur ?
            }
            else {
                special_log( 'bad_pron', $titre, '', "p='$p'" );
            }
        }
        elsif ( $ligne =~
/^'''.+?''' ?.*?\{\{pron\|([^\}\r\n]+?)\}\}.+ \{\{pron\|([^\}\r\n]+?)\}\}\}/
          )
        {
            my $p1 = $1;
            my $p2 = $2;

            # Pron donnée mais sans code langue
            if ( not $p1 =~ /[=\|]/ ) {
                $pron{$p1} = 1;
                special_log( 'bad_pron_nolang', $titre, '', "p1='$p1'" );

                # Pron donnée avec la langue donnée en paramètre lang=
            }
            elsif ( $p1 =~ /^lang=.+\|(.+)$/ or $p1 =~ /^(.+)\|lang=.+$/ ) {
                $pron{$1} = 1;

                # Vide ou non, avec code langue
            }
            elsif ( $p1 =~ /^([^\|\}])*\|([^\|\}]+)$/ ) {
                $pron{$1} = 1 if $1;

                # Une erreur ?
            }
            else {
                special_log( 'bad_pron', $titre, '', "p1='$p1'" );
            }

            # Pron donnée mais sans code langue
            if ( not $p2 =~ /[=\|]/ ) {
                $pron{$p2} = 1;
                special_log( 'bad_pron_nolang', $titre, '', "p2='$p2'" );

                # Pron donnée avec la langue donnée en paramètre lang=
            }
            elsif ( $p2 =~ /^lang=.+\|(.+)$/ or $p2 =~ /^(.+)\|lang=.+$/ ) {
                $pron{$1} = 1;

                # Vide ou non, avec code langue
            }
            elsif ( $p2 =~ /^([^\|\}])*\|([^\|\}]+)$/ ) {
                $pron{$1} = 1 if $1;

                # Une erreur ?
            }
            else {
                special_log( 'bad_pron', $titre, '', "p2='$p2'" );
            }
        }

        # Ancien
        elsif ( $ligne =~ /^'''.+?'''.*?\/([^\/]*?)\/.+ \/([^\/]*?)\// ) {
            $pron{$1} = 1;
            $pron{$2} = 1;

#print STDERR "[[$titre]]\tvieille prononciation de ligne de forme /$1/, /$2/\n";
            special_log( 'vieille_pron', $titre, "/$1/, /$2/" );
        }
        elsif ( $ligne =~ /^'''.+?'''.*?\/([^\/]*?)\// ) {
            $pron{$1} = 1;
            special_log( 'vieille_pron', $titre, "/$1/" );
        }
    }

    # Ignore flexions and don't care further if pronunciations already found
    if ( not $flexion and keys %pron == 0 ) {
        my $tables = cherche_tables( $lignes, $lang, $titre );

        # TABLES EN FRANÇAIS - FRENCH
        if ( $lang eq 'fr' ) {
          TABLE: for ( my $i = 0 ; $i < @$tables ; $i++ ) {
                my $nom = $tables->[$i]->{'nom'};
                my $arg = $tables->[$i]->{'arg'};

                # Table in flexions? Detect with s= or ms= without p= or mp=
                if (   ( defined( $arg->{s} ) and not defined( $arg->{p} ) )
                    or ( defined( $arg->{ms} ) and not defined( $arg->{mp} ) ) )
                {
                    next TABLE;
                }

                # Pour toutes les tables connues
                if ( $nom eq 'inv' ) {
                    $pron{ $arg->{1} }     = 1 if ( $arg->{1} );
                    $pron{ $arg->{pron} }  = 1 if ( $arg->{pron} );
                    $pron{ $arg->{pron2} } = 1 if ( $arg->{pron2} );
                    $pron{ $arg->{pron3} } = 1 if ( $arg->{pron3} );
                    $pron{ $arg->{p2s} }   = 1 if ( $arg->{p2s} );
                    $pron{ $arg->{p2s2} }  = 1 if ( $arg->{p2s2} );
                    $pron{ $arg->{p2s3} }  = 1 if ( $arg->{p2s3} );
                }
                elsif ( $nom eq 'accord-ind' ) {
                    $pron{ $arg->{pron} } = 1 if ( $arg->{pron} );
                    $pron{ $arg->{pm} }   = 1 if ( $arg->{pm} );
                }
                elsif ($nom eq 'rég'
                    or $nom eq 'reg'
                    or $nom eq 'accord-rég'
                    or $nom eq 'accord-reg' )
                {
                    $pron{ $arg->{1} }     = 1 if ( $arg->{1} );
                    $pron{ $arg->{pron2} } = 1 if ( $arg->{pron2} );
                    $pron{ $arg->{pron3} } = 1 if ( $arg->{pron3} );
                }
                elsif ( $nom eq 'rég-x' ) {
                    $pron{ $arg->{1} }     = 1 if ( $arg->{1} );
                    $pron{ $arg->{pron2} } = 1 if ( $arg->{pron2} );
                    $pron{ $arg->{pron3} } = 1 if ( $arg->{pron3} );
                }
                elsif ( $nom eq 'accord-mf' ) {
                    $pron{ $arg->{ps} }    = 1 if ( $arg->{ps} );
                    $pron{ $arg->{ps2} }   = 1 if ( $arg->{ps2} );
                    $pron{ $arg->{ps3} }   = 1 if ( $arg->{ps3} );
                    $pron{ $arg->{p2s} }   = 1 if ( $arg->{p2s} );
                    $pron{ $arg->{p2s2} }  = 1 if ( $arg->{p2s2} );
                    $pron{ $arg->{p2s3} }  = 1 if ( $arg->{p2s3} );
                    $pron{ $arg->{pron} }  = 1 if ( $arg->{pron} );
                    $pron{ $arg->{pron2} } = 1 if ( $arg->{pron2} );
                    $pron{ $arg->{pron3} } = 1 if ( $arg->{pron3} );
                }
                elsif ( $nom eq 'accord-mixte' ) {
                    $pron{ $arg->{pm} }    = 1 if ( $arg->{pm} );
                    $pron{ $arg->{pm2} }   = 1 if ( $arg->{pm2} );
                    $pron{ $arg->{pm3} }   = 1 if ( $arg->{pm3} );
                    $pron{ $arg->{pms} }   = 1 if ( $arg->{pms} );
                    $pron{ $arg->{pms2} }  = 1 if ( $arg->{pms2} );
                    $pron{ $arg->{pms3} }  = 1 if ( $arg->{pms3} );
                    $pron{ $arg->{pron} }  = 1 if ( $arg->{pron} );
                    $pron{ $arg->{pron2} } = 1 if ( $arg->{pron2} );
                    $pron{ $arg->{pron3} } = 1 if ( $arg->{pron3} );
                }

                # Ne devrait pas etre utilisé comme tel
                elsif ($nom eq 'accord-mixte-reg'
                    or $nom eq 'accord-mixte-rég' )
                {
                    my $suff = '';
                    $suff .= $arg->{psufm}   if ( $arg->{psufm} );
                    $suff .= " $arg->{pinv}" if ( $arg->{pinv} );
                    $pron{ $arg->{2} . $suff }     = 1 if ( $arg->{2} );
                    $pron{ $arg->{pron2} . $suff } = 1 if ( $arg->{pron2} );
                    $pron{ $arg->{pron3} . $suff } = 1 if ( $arg->{pron3} );

               #print STDERR "[[$titre]]\tmodèle 'fr-$nom' est inapproprié\n";
                    special_log( 'flextable_accord-mixte-rég', $titre, '',
                        "fr-nom" );
                }
                elsif ( $nom eq 'accord-comp-mf' or $nom eq 'accord-comp' ) {
                    my $mot_1 = $arg->{3};
                    my $mot_2 = $arg->{4};
                    my $sep   = $arg->{'ptrait'} ? $arg->{'ptrait'} : '.';
                    $sep =~ s/&#32;/ /;

                    if ( $mot_1 and $mot_2 ) {
                        my $comp = $mot_1 . $sep . $mot_2;
                        $pron{$comp} = 1;
                    }
                    elsif ( $mot_1 or $mot_2 ) {
                        special_log( 'remplissage', $titre, '', "fr-$nom" );
                    }
                }

                # Radical en 1
                elsif ( $nom =~ /^accord-(an|el|en|et|in|s|mf-x|ot|at)$/ ) {
                    my $suff = '';
                    if    ( $1 eq 'an' )   { $suff = 'ɑ̃'; }
                    elsif ( $1 eq 'el' )   { $suff = 'ɛl'; }
                    elsif ( $1 eq 'en' )   { $suff = 'ɛ̃'; }
                    elsif ( $1 eq 'et' )   { $suff = 'ɛ'; }
                    elsif ( $1 eq 'in' )   { $suff = 'ɛ̃'; }
                    elsif ( $1 eq 's' )    { $suff = ''; }
                    elsif ( $1 eq 'mf-x' ) { $suff = ''; }
                    elsif ( $1 eq 'ot' )   { $suff = 'o'; }
                    elsif ( $1 eq 'at' )   { $suff = 'a'; }
                    else { special_log( 'accord', $titre, "'accord-$1'" ); }
                    $pron{ $arg->{1} . $suff }     = 1 if ( $arg->{1} );
                    $pron{ $arg->{pron} . $suff }  = 1 if ( $arg->{pron} );
                    $pron{ $arg->{pron2} . $suff } = 1 if ( $arg->{pron2} );
                    $pron{ $arg->{pron3} . $suff } = 1 if ( $arg->{pron3} );
                }

                # Radical en 2
                elsif ( $nom =~
                    /^accord-(mf-ail|mf-al|al|if|f|eau|ef|er|eur|eux|oux)$/ )
                {
                    my $suff = '';
                    if    ( $1 eq 'mf-ail' ) { $suff = 'aj'; }
                    elsif ( $1 eq 'mf-al' )  { $suff = 'al'; }
                    elsif ( $1 eq 'al' )     { $suff = 'al'; }
                    elsif ( $1 eq 'if' )     { $suff = 'if'; }
                    elsif ( $1 eq 'f' )      { $suff = 'f'; }
                    elsif ( $1 eq 'eau' )    { $suff = 'o'; }
                    elsif ( $1 eq 'ef' )     { $suff = 'ɛf'; }
                    elsif ( $1 eq 'er' )     { $suff = 'e'; }
                    elsif ( $1 eq 'eur' )    { $suff = 'œʁ'; }
                    elsif ( $1 eq 'eux' )    { $suff = 'ø'; }
                    elsif ( $1 eq 'oux' )    { $suff = 'u'; }
                    else { special_log( 'accord', $titre, "'accord-$1'" ); }
                    $pron{ $arg->{2} . $suff }     = 1 if ( $arg->{2} );
                    $pron{ $arg->{pron} . $suff }  = 1 if ( $arg->{pron} );
                    $pron{ $arg->{pron2} . $suff } = 1 if ( $arg->{pron2} );
                    $pron{ $arg->{pron3} . $suff } = 1 if ( $arg->{pron3} );
                }
                elsif ( $nom eq 'accord-cons' ) {
                    my $suff = '';
                    $suff .= " $arg->{pinv}" if $arg->{pinv};    # Beuh
                    $pron{ $arg->{1} . $suff } = 1 if ( $arg->{1} );
                    $pron{ $arg->{'pron-ms'} . $suff } = 1
                      if ( $arg->{'pron-ms'} );
                }
                elsif ( $nom eq 'accord-on' ) {
                    my $suff = 'ɔ̃';
                    $suff .= " $arg->{pinv}" if $arg->{pinv};    # Beuh
                    $pron{ $arg->{1} . $suff }     = 1 if ( $arg->{1} );
                    $pron{ $arg->{pron} . $suff }  = 1 if ( $arg->{pron} );
                    $pron{ $arg->{pron2} . $suff } = 1 if ( $arg->{pron2} );
                    $pron{ $arg->{pron3} . $suff } = 1 if ( $arg->{pron3} );
                }
                elsif ( $nom eq 'accord-ain' ) {
                    my $suff = 'ɛ̃';
                    $pron{ $arg->{1} . $suff } = 1 if ( $arg->{1} );
                    $pron{ $arg->{'pron-radical'} . $suff } = 1
                      if ( $arg->{'pron-radical'} );
                    $pron{ $arg->{pron2} . $suff } = 1 if ( $arg->{pron2} );
                    $pron{ $arg->{pron3} . $suff } = 1 if ( $arg->{pron3} );
                }
                elsif ( $nom eq 'lettre' ) {
                    $pron{ $arg->{3} } = 1 if ( $arg->{3} );
                }
                elsif ( $nom eq 'accord-personne' ) {

                    # Impossible de déterminer la prononciation du mot vedette
                }
                elsif ( $nom eq 'verbe-flexion' ) {

                    # rien, pas une table d'accord
                }
                else {
                    # TABLE INCONNUE ? DIABLE !
                    my $texte     = "{{$nom| ";
                    my @arg_texte = ();
                    foreach my $a ( sort keys %$arg ) {
                        push @arg_texte, "$a=$arg->{$a}";
                    }
                    $texte .= join( ' | ', @arg_texte );
                    $texte .= ' }}';
                    special_log( 'flextable_inconnue', $titre, $texte, $nom );
                }
            }
        }
    }

    my @prononciations = keys %pron;
    @prononciations = sort ( check_prononciation( \@prononciations, $titre ) );
    return \@prononciations;
}

sub cherche_transcription {
    my ( $lignes, $lang, $titre, $type ) = @_;
    my $tables = cherche_tables( $lignes, $lang, $titre );

    my %transcriptions = ();

    # TABLES EN JAPONAIS - JAPANESE
    if ( $lang eq 'ja' ) {
        for ( my $i = 0 ; $i < @$tables ; $i++ ) {
            my $nom = $tables->[$i]->{'nom'};
            my $arg = $tables->[$i]->{'arg'};

            # Table kanji, romaji, prononciation -> transcription !
            # OBSOLETE mais encore utilisé
            if ( $nom eq 'ka' ) {

                # 1 = kana
                # 2 = transcription Hepburn
                if ( $arg->{2} ) {
                    $transcriptions{ $arg->{2} }++;
                }
            }
            elsif ( $nom eq 'trans' ) {

# 1 ou kanji 	Optionnel. Graphie en kanji si elle existe.
# kanji2 	Optionnel. Si il existe une variante orthographique ou des kanjis alternatifs.
# kanji3 	Optionnel. Pareil que le paramètre kanji2.
# 2 ou hira 	Optionnel. Graphie en hiragana
# 3 ou kata 	Optionnel. Graphie en katakana.
# 4 ou tr 	Optionnel. Transcription romaji utilisant la méthode Hepburn.
# 5 ou pron 	Optionnel. Prononciation en alphabet phonétique international (API).

                # Get transcription
                if ( $arg->{4} ) {
                    $transcriptions{ $arg->{4} }++;
                }
                elsif ( $arg->{tr} ) {
                    $transcriptions{ $arg->{tr} }++;
                }
            }
        }
    }
    my @transcriptions = sort keys %transcriptions;
    return \@transcriptions;
}

sub section_prononciation {
    my ( $lignes, $titre ) = @_;

    my %pron = ();
    my $p    = '';

    foreach my $ligne (@$lignes) {
        if (    $ligne =~ /^\* ?\{\{pron\|([^\}\r\n]+?)\}\}/
            and $1
            and not $ligne =~ /SAMPA/ )
        {
            $p = $1;
            my @ps = split( /\s*\|\s*/, $p );
            if ( $ps[0] =~ /lang=/ ) {
                $pron{ $ps[1] } = 1 if $ps[1];
            }
            else {
                $pron{ $ps[0] } = 1 if $ps[0];
            }
        }
        elsif ( $ligne =~ /^\* ?.+ ?\{\{pron\|([^\}\r\n]+?)\}\}/
            and not $ligne =~ /SAMPA/
            and $1 )
        {
            $p = $1;
            my @ps = split( /\s*\|\s*/, $p );
            if ( $ps[0] =~ /lang=/ ) {
                $pron{ $ps[1] } = 1 if $ps[1];
            }
            else {
                $pron{ $ps[0] } = 1 if $ps[0];
            }
        }
        elsif ( $ligne =~ /^\* ?\/([^\|\}\/\r\n]+?)\//
            and $1
            and not $ligne =~ /SAMPA/ )
        {
            $p = $1;
            $pron{$p} = 1;
        }
        elsif ( $ligne =~ /^\* ?.+ ?\/([^\/]+?)\//
            and $1
            and not $ligne =~ /SAMPA/ )
        {
            $p = $1;
            $pron{$p} = 1;
        }
        else {
        }
    }

    my @prononciations = keys %pron;
    @prononciations = check_prononciation( \@prononciations, $titre );
    return @prononciations;
}

sub check_prononciation {
    my ( $prononciations, $titre ) = @_;
    my @pron;

    foreach my $p (@$prononciations) {
        if ( $p =~ /&.{2,5};/ ) {

            # Excepté les <>
            my $p2 = $p;
            $p2 =~ s/&lt;/</g;
            $p2 =~ s/&gt;/>/g;

            # Reste?
            if ( $p2 =~ /&.{2,5};/ ) {
                special_log( 'HTML', $titre, $p2 );
            }
        }
        if ( $p =~ /[0-9@\\"&\?EAOIU]/ ) {
            special_log( 'SAMPA', $titre, $p );
        }
        elsif ( $p =~ /[g]/ ) {
            my $p2 = $p;
            $p2 =~ s/g/ɡ/g;
            special_log( 'API_g', $titre, "$p -> $p2" );
            push @pron, $p2;
        }
        elsif ( $p =~ /[:]/ ) {
            my $p2 = $p;
            $p2 =~ s/:/ː/g;
            special_log( 'API_2points', $titre, "$p -> $p2" );
            push @pron, $p2;
        }
        elsif ( $p =~ /[']/ ) {
            my $p2 = $p;
            $p2 =~ s/'/ˈ/g;
            special_log( 'API_ton', $titre, "$p -> $p2" );
            push @pron, $p2;
        }
        elsif ( $p =~ /ǝ|ᴣ/ ) {
            my $p2 = $p;
            $p2 =~ s/ǝ/ə/g;
            $p2 =~ s/ᴣ/ʒ/g;
            special_log( 'API_wrong_letter', $titre, "$p" );
            push @pron, $p2;
        }
        elsif ( $p =~ /\/( ou |, )\// or $p =~ /( ou |, )/ ) {
            special_log( 'double_pron', $titre, $p );
            my @ou_pron = split( /\/? ou \/?/, $p );
            push @pron, @ou_pron;
        }
        else {
            push @pron, $p;
        }
    }

    # Corrections simples
    foreach my $p (@pron) {

        # Pas d'espaces en début ou fin
        $p =~ s/^ +//;
        $p =~ s/ +$//;
    }

    return @pron;
}

sub simple_prononciation {
    my ($pron0) = @_;
    my $pron = $pron0;
    $pron =~ s/[\.,\- ‿ːˈˌ]//g;

    # Cas spéciaux
    # r: identique partout
    $pron =~ s/[ʁrɹʀɾ]/r/g;

    # Autres
    $pron =~ s/ʧ/tʃ/;
    $pron =~ s/ʤ/dʒ/;
    return $pron;
}

sub extrait_rimes {
    my ($pron0) = @_;
    my @lettres = split( //, $pron0 );

    # Concat diacritics
    my @let = ();
    foreach my $l (@lettres) {

        # Diac? Concat
        if ( $l eq '̃' and $let[$#let] ) {
            $let[$#let] .= $l;
        }
        else {
            push @let, $l;
        }
    }

    my %rimes = ( pauvre => '', suffisante => '', riche => '', voyelle => '' );
    $rimes{pauvre} = $let[-1] if @let >= 1 and $let[-1];
    $rimes{suffisante} = join( '', @let[ -2 .. -1 ] ) if @let >= 2;
    $rimes{riche}      = join( '', @let[ -3 .. -1 ] ) if @let >= 3;

    # Get last voyelle
  VOY: for ( my $i = $#let ; $i > 0 ; $i-- ) {
        if ( $let[$i] ~~ @voyelles ) {
            $rimes{voyelle} = $let[$i];
            last VOY;
        }
    }

    return \%rimes;
}

sub nombre_de_syllabes {
    my ($pron) = @_;

    return 0 if not $pron;

    $pron =~ s/^[\. ˈ:]//;
    $pron =~ s/[\. ˈ:]$//;
    my @syllabes = split( /[\. ˈ:]+/, $pron );
    my $nsyl = @syllabes;

    return $nsyl;
}

1;

__END__


#!/usr/bin/perl -w

# Wiktionnaire parser
# Author: Matthieu Barba
#
# This module contain a specific parser
# of the content of the fr.wiktionary articles

package wiktio::parser;

use Exporter;    # So that we can export functions and vars
@ISA = ('Exporter');    # This module is a subclass of Exporter

# What can be exported
@EXPORT_OK =
  qw( parseArticle parseLanguage parseType is_gentile is_sigle section_meanings cherche_genre);

use strict;
use warnings;

use utf8;
use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use wiktio::basic;

# STRUCTURE DATA
our $level3 = {
    'étymologie'   => 'étymologie',
    'étym'         => 'étymologie',
    'etym'          => 'étymologie',
    'prononciation' => 'prononciation',
    'pron'          => 'prononciation',
    'voir aussi'    => 'voir aussi',
    'voir'          => 'voir aussi',
    'anagrammes'    => 'anagrammes',
    'anagr'         => 'anagrammes',
    'références'  => 'réferences',
    'réf'          => 'réferences',
    'ref'           => 'réferences',
};

our $word_type = {
    'adjectif'                              => 'adj',
    'adj'                                   => 'adj',
    'adjectif qualificatif'                 => 'adj',
    'adverbe'                               => 'adv',
    'adv'                                   => 'adv',
    'adverbe interrogatif'                  => 'adv-int',
    'adv-int'                               => 'adv-int',
    'adverbe int'                           => 'adv-int',
    'adverbe pronominal'                    => 'adv-pron',
    'adv-pron'                              => 'adv-pron',
    'adverbe pro'                           => 'adv-pron',
    'adverbe relatif'                       => 'adv-rel',
    'adv-rel'                               => 'adv-rel',
    'adverbe rel'                           => 'adv-rel',
    'conjonction'                           => 'conj',
    'conj'                                  => 'conj',
    'conjonction de coordination'           => 'conj-coord',
    'conj-coord'                            => 'conj-coord',
    'conjonction coo'                       => 'conj-coord',
    'copule'                                => 'copule',
    'adjectif démonstratif'                => 'adj-dém',
    'adj-dém'                              => 'adj-dém',
    'adjectif dém'                         => 'adj-dém',
    'déterminant'                          => 'det',
    'dét'                                  => 'det',
    'adjectif exclamatif'                   => 'adj-excl',
    'adj-excl'                              => 'adj-excl',
    'adjectif exc'                          => 'adj-excl',
    'adjectif indéfini'                    => 'adj-indéf',
    'adj-indéf'                            => 'adj-indéf',
    'adjectif ind'                          => 'adj-indéf',
    'adjectif interrogatif'                 => 'adj-int',
    'adj-int'                               => 'adj-int',
    'adjectif int'                          => 'adj-int',
    'adjectif numéral'                     => 'adj-num',
    'adj-num'                               => 'adj-num',
    'adjectif num'                          => 'adj-num',
    'adjectif possessif'                    => 'adj-pos',
    'adj-pos'                               => 'adj-pos',
    'adjectif pos'                          => 'adj-pos',
    'article'                               => 'art',
    'art'                                   => 'art',
    'article défini'                       => 'art-déf',
    'art-déf'                              => 'art-déf',
    'article déf'                          => 'art-déf',
    'article indéfini'                     => 'art-indéf',
    'art-indéf'                            => 'art-indéf',
    'article ind'                           => 'art-indéf',
    'article partitif'                      => 'art-part',
    'art-part'                              => 'art-part',
    'article par'                           => 'art-part',
    'nom'                                   => 'nom',
    'substantif'                            => 'nom',
    'nom commun'                            => 'nom',
    'nom de famille'                        => 'nom-fam',
    'nom-fam'                               => 'nom-fam',
    'patronyme'                             => 'patronyme',
    'nom propre'                            => 'nom-pr',
    'nom-pr'                                => 'nom-pr',
    'nom scientifique'                      => 'nom-sciences',
    'nom-sciences'                          => 'nom-sciences',
    'nom science'                           => 'nom-sciences',
    'nom scient'                            => 'nom-sciences',
    'prénom'                               => 'prenom',
    'préposition'                          => 'prep',
    'prép'                                 => 'prep',
    'pronom'                                => 'pronom',
    'pronom-adjectif'                       => 'pronom-adj',
    'pronom démonstratif'                  => 'pronom-dém',
    'pronom-dém'                           => 'pronom-dém',
    'pronom dém'                           => 'pronom-dém',
    'pronom indéfini'                      => 'pronom-indéf',
    'pronom-indéf'                         => 'pronom-indéf',
    'pronom ind'                            => 'pronom-indéf',
    'pronom interrogatif'                   => 'pronom-int',
    'pronom-int'                            => 'pronom-int',
    'pronom int'                            => 'pronom-int',
    'pronom personnel'                      => 'pronom-pers',
    'pronom-pers'                           => 'pronom-pers',
    'pronom-per'                            => 'pronom-pers',
    'pronom réf'                           => 'pronom-pers',
    'pronom-réfl'                          => 'pronom-pers',
    'pronom réfléchi'                     => 'pronom-pers',
    'pronom possessif'                      => 'pronom-pos',
    'pronom-pos'                            => 'pronom-pos',
    'pronom pos'                            => 'pronom-pos',
    'pronom relatif'                        => 'pronom-rel',
    'pronom-rel'                            => 'pronom-rel',
    'pronom rel'                            => 'pronom-rel',
    'verbe'                                 => 'verb',
    'verb'                                  => 'verb',
    'verbe pronominal'                      => 'verb',
    'verb-pr'                               => 'verb',
    'verbe pr'                              => 'verb',
    'interjection'                          => 'interj',
    'interj'                                => 'interj',
    'onomatopée'                           => 'onoma',
    'onoma'                                 => 'onoma',
    'onom'                                  => 'onoma',
    'affixe'                                => 'aff',
    'aff'                                   => 'aff',
    'circonfixe'                            => 'circon',
    'circonf'                               => 'circon',
    'circon'                                => 'circon',
    'infixe'                                => 'inf',
    'inf'                                   => 'inf',
    'interfixe'                             => 'interf',
    'interf'                                => 'interf',
    'particule'                             => 'part',
    'part'                                  => 'part',
    'particule numérale'                   => 'part-num',
    'part-num'                              => 'part-num',
    'particule num'                         => 'part-num',
    'postposition'                          => 'post',
    'post'                                  => 'post',
    'postpos'                               => 'post',
    'préfixe'                              => 'pre',
    'préf'                                 => 'pre',
    'radical'                               => 'radical',
    'rad'                                   => 'radical',
    'suffixe'                               => 'suf',
    'suff'                                  => 'suf',
    'suf'                                   => 'suf',
    'pré-verbe'                            => 'preverb',
    'pré-nom'                              => 'pre-nom',
    'locution'                              => 'loc',
    'loc'                                   => 'loc',
    'locution-phrase'                       => 'phr',
    'loc-phr'                               => 'phr',
    'locution-phrase'                       => 'phr',
    'locution phrase'                       => 'phr',
    'proverbe'                              => 'prov',
    'prov'                                  => 'prov',
    'quantificateur'                        => 'quantif',
    'quantif'                               => 'quantif',
    'variante typographique'                => 'var-typo',
    'var-typo'                              => 'var-typo',
    'variante typo'                         => 'var-typo',
    'variante par contrainte typographique' => 'var-typo',
    'lettre'                                => 'lettre',
    'symbole'                               => 'symb',
    'symb'                                  => 'symb',
    'classificateur'                        => 'class',
    'class'                                 => 'class',
    'classif'                               => 'class',
    'numéral'                              => 'numeral',
    'numér'                                => 'numeral',
    'num'                                   => 'numeral',
    'sinogramme'                            => 'sinogramme',
    'sinog'                                 => 'sinogramme',
    'sino'                                  => 'sinogramme',
    'erreur'                                => 'faute',
    'faute'                                 => 'faute',
    'faute d\'orthographe'                  => 'faute',
    'faute d’orthographe'                 => 'faute',
    'gismu'                                 => 'gismu',
    'rafsi'                                 => 'rafsi',
};

our $level4 = {
    'anagrammes'                 => 'anagrammes',
    'anagramme'                  => 'anagrammes',
    'anagr'                      => 'anagrammes',
    'dico sinogrammes'           => 'dico sinogrammes',
    'sino-dico'                  => 'dico sinogrammes',
    'dico-sino'                  => 'dico sinogrammes',
    'écriture'                  => 'écriture',
    'écrit'                     => 'écriture',
    'étymologie'                => 'étymologie',
    'étym'                      => 'étymologie',
    'etym'                       => 'étymologie',
    'prononciation'              => 'prononciation',
    'pron'                       => 'prononciation',
    'prononciations'             => 'prononciation',
    'références'               => 'références',
    'référence'                => 'références',
    'réf'                       => 'références',
    'ref'                        => 'références',
    'voir aussi'                 => 'voir aussi',
    'voir'                       => 'voir aussi',
    'abréviations'              => 'abréviations',
    'abrév'                     => 'abréviations',
    'antonymes'                  => 'antonymes',
    'ant'                        => 'antonymes',
    'anto'                       => 'antonymes',
    'apparentés'                => 'apparentés',
    'apr'                        => 'apparentés',
    'app'                        => 'apparentés',
    'apparentés étymologiques' => 'apparentés',
    'augmentatifs'               => 'augmentatifs',
    'augm'                       => 'augmentatifs',
    'citations'                  => 'citations',
    'cit'                        => 'citations',
    'composés'                  => 'composés',
    'compos'                     => 'composés',
    'diminutifs'                 => 'diminutifs',
    'dimin'                      => 'diminutifs',
    'dérivés'                  => 'dérivés',
    'drv'                        => 'dérivés',
    'dérivés autres langues'   => 'dérivés autres langues',
    'drv-int'                    => 'dérivés autres langues',
    'dérivés int'              => 'dérivés autres langues',
    'expressions'                => 'expressions',
    'exp'                        => 'expressions',
    'expr'                       => 'expressions',
    'faux-amis'                  => 'faux-amis',
    'gentilés'                  => 'gentilés',
    'gent'                       => 'gentilés',
    'holonymes'                  => 'holonymes',
    'holo'                       => 'holonymes',
    'hyponymes'                  => 'hyponymes',
    'hypo'                       => 'hyponymes',
    'hyperonymes'                => 'hyperonymes',
    'hyper'                      => 'hyperonymes',
    'vidéos'                    => 'vidéos',
    'méronymes'                 => 'méronymes',
    'méro'                      => 'méronymes',
    'noms vernaculaires'         => 'noms vernaculaires',
    'noms-vern'                  => 'noms vernaculaires',
    'phrases'                    => 'Proverbes et phrases toutes faites',
    'quasi-synonymes'            => 'quasi-synonymes',
    'q-syn'                      => 'quasi-synonymes',
    'quasi-syn'                  => 'quasi-synonymes',
    'synonymes'                  => 'synonymes',
    'syn'                        => 'synonymes',
    'traductions'                => 'traductions',
    'trad'                       => 'traductions',
    'traductions à trier'       => 'traductions à trier',
    'trad-trier'                 => 'traductions à trier',
    'trad trier'                 => 'traductions à trier',
    'transcriptions'             => 'transcriptions',
    'trans'                      => 'transcriptions',
    'tran'                       => 'transcriptions',
    'translittérations'         => 'translittérations',
    'translit'                   => 'translittérations',
    'troponymes'                 => 'troponymes',
    'tropo'                      => 'troponymes',
    'vocabulaire'                => 'vocabulaire',
    'voc'                        => 'vocabulaire',
    'vocabulaire apparenté'     => 'vocabulaire',
    'vocabulaire proche'         => 'vocabulaire',
    'anciennes orthographes'     => 'anciennes orthographes',
    'ortho-arch'                 => 'anciennes orthographes',
    'anciennes ortho'            => 'anciennes orthographes',
    'variantes'                  => 'variantes',
    'var'                        => 'variantes',
    'variantes dialectales'      => 'variantes dialectales',
    'dial'                       => 'variantes dialectales',
    'var-dial'                   => 'variantes dialectales',
    'variantes dial'             => 'variantes dialectales',
    'variantes dialectes'        => 'variantes dialectales',
    'dialectes'                  => 'variantes dialectales',
    'variantes ortho'            => 'variantes ortho',
    'var-ortho'                  => 'variantes ortho',
    'variantes orthographiques'  => 'variantes ortho',
    'conjugaison'                => 'conjugaison',
    'conjug'                     => 'conjugaison',
    'déclinaison'               => 'déclinaison',
    'décl'                      => 'déclinaison',
    'attestations'               => 'attestations',
    'attest'                     => 'attestations',
    'hist'                       => 'attestations',
    'homophones'                 => 'homophones',
    'homo'                       => 'homophones',
    'paronymes'                  => 'paronymes',
    'paro'                       => 'paronymes',
    'note'                       => 'note',
    'notes'                      => 'notes',

};

sub parseArticle {
    my ( $article0, $title ) = @_;
    die "Not an array (parseArticle)\n" if not ref($article0) eq 'ARRAY';
    die "Empty array (parseArticle)\n"  if $#{$article0} == -1;

    # copy and clean before parsing
    my $article = ();
    for ( my $i = 0 ; $i < @$article0 ; $i++ ) {
        my $line = $article0->[$i];
        next if $line =~ /^\s*$/;

        # Delete
        if ( $line =~ s/&lt;!--(.*)--&gt;// ) {
            special_log( 'html_hidden', $title, "<!--$1-->" );
        }

        # Don't delete for now, multiple lines...
        elsif ( $line =~ /(&lt;!--.*)$/ ) {
            my $hidden = $1;
            $i++;
            while ( $i < @$article0 ) {
                $line = $article0->[$i];
                last if ( $line =~ /--&gt;/ );
                $hidden .= $line;
                $i++;
            }
            $line =~ s/^(.*--&gt;)//;
            $hidden .= $1;
            special_log( 'html_hidden_long', $title, "$hidden" );
        }
        push @$article, $line;
    }

    # Extract the main sections:
    my $sections = {};
    $sections->{'tail'} = ();
    $sections->{'head'} = ();

    # head, languages, tail
    my $language = '';

    # HEAD
    while ( my $line = shift @$article ) {
        if ( $line =~ /^#REDIRECT/i ) {
            $sections->{'redirect'} = 1;
            return $sections;
        }

        # HEAD?
        unless ( $line =~ /^([ =]*)== *\{\{langue\|(.+?)\}\} *==([ =]*)$/ ) {
            push @{ $sections->{'head'} }, $line;
        }
        else {
            $language = $2;
            special_log( 'level2_syntax', $title, "'^$1== $1'" )
              if ( $1 and $1 ne '' );
            special_log( 'level2_syntax', $title, "'$1 ==$3\$'" )
              if ( $3 and $3 ne '' );
            $sections->{'language'}->{$language} = ();
            last;
        }
    }

    # continue to retrieve the languages
    while ( my $line = shift @$article ) {
        special_log( 'oldlevel2', $title ) if $line =~ /\{\{=[^\}]+=\}\}/;

        # TAIL ?
        if (
               $line =~ /^\{\{clé de tri/
            or $line =~ /^\[\[[a-z-]+?:.+?\]\]$/    # interwiki
            or $line =~ /^\[\[Catégorie:.+?\]\]$/i
          )
        {
            push @{ $sections->{'tail'} }, $line;
        }

        # Another language?
        elsif ( $line =~ /^([ =]*)== *\{\{langue\|(.+?)\}\} *==([ =]*)$/ ) {
            $language = $2;
            special_log( 'level2_syntax', $title, "'^$1== $1'" )
              if ( $1 and $1 ne '' );
            special_log( 'level2_syntax', $title, "'$1 ==$3\$'" )
              if ( $3 and $3 ne '' );
            $sections->{'language'}->{$language} = ();

            # Continue this language
        }
        else {
            push @{ $sections->{'language'}->{$language} }, $line;
        }
    }

    return $sections;
}

sub parseLanguage {
    my ( $article, $title, $lang ) = @_;
    die "Not an array (parseLanguage)\n" if not ref($article) eq 'ARRAY';
    die "Empty array (parseLanguage)\n"  if $#{$article} == -1;

    # Extract the main sections:
    my $sections = {};
    $sections->{'head'}          = ();
    $sections->{'etymologie'}    = ();
    $sections->{'prononciation'} = ();
    $sections->{'voir'}          = ();
    $sections->{'references'}    = ();
    $sections->{'types'}         = {};    # Array

    # Get the HEAD if any
    foreach my $line (@$article) {
        unless ( $line =~ /\{\{-.+?-[\|\}]|=+\s*\{\{S\|/ ) {
            push @{ $sections->{'head'} }, $line;
        }
        else {
            last;
        }
    }

    # Continue to retrieve the sections
    my $level = '';
    my $key   = '';

    foreach my $line (@$article) {
        my $templevel = '';
        my $eqstart   = '';
        my $eqend     = '';

        # Is it a section, but an old one?
        if ( $line =~ /\{\{-(.+?)-[\|\}]/ ) {
            $templevel = $1;
        }
        elsif ( $line =~ /^\s*(=+)\s*\{\{S\|([^\|\}]+?)[\|\}].*\}\s*(=+)\s*$/ )
        {
            $eqstart   = $1;
            $eqend     = $3;
            $templevel = $2;
        }

        if ($templevel) {
            $templevel = lcfirst($templevel);

            # Any level3 header? (except type)
            if ( exists $level3->{$templevel} ) {
                $level = $templevel;
                $key   = '';

                # Save
                $sections->{ $level3->{$level} }->{lines} = [];
                $templevel = '';

                # Check level
                if ( $eqstart ne '===' or $eqend ne '===' ) {
                    if ( $eqstart eq '' and $eqend eq '' ) {
                        special_log( 'section_3_no_equal', $title,
                            "$lang\t$eqstart $level $eqend" );
                    }
                    else {
                        special_log( 'section_3_number_of_equal', $title,
                            "$lang\t$eqstart $level $eqend" );
                    }
                }
                next;
            }

            # Else supposedly a type
            else {
                my $type = $templevel;
                my ( $flex, $loc ) = ( $false, $false );

                # Detect old "flexion"
                if   ( $type =~ s/^flex-// ) { $flex = $true; }
                else                         { $flex = $false; }

                # Detect old "locution"
                if ( $type =~ s/^loc-// or $type eq 'prov' ) { $loc = $true; }
                else                                         { $loc = $false; }

                # Is it a registered type3 header?
                if ( exists $word_type->{$type} ) {

                    # Number (if any)
                    my $num = 0;
                    if ( $line =~ /\|num=([0-9]+)[\|\}]/ ) {
                        $num = $1;
                    }
                    if ( $line =~ /\|flexion[\|\}]/ ) {
                        $flex = $true;
                    }
                    if ( $line =~ /\|locution=([^\|\}]+)[\|\}]/ ) {
                        my $locpar = $1;
                        if ( $locpar eq 'oui' ) {
                            $loc = $true;
                        }
                        elsif ( $locpar eq 'non' ) {
                            $loc = $false;
                        }
                        else {
                            special_log( 'bad_loc_par', $title,
                                "$lang\t$type\t$locpar" );
                        }

                        # Guess!
                    }
                    else {
                        if ( $title =~ / / ) {
                            $loc = $true;
                        }
                    }

                    # Alias?
                    $type = $word_type->{$type};

                    # Save
                    $key   = $type . $num . $flex . $loc;
                    $level = '';
                    special_log( 'level3_duplicates', $title,
                        "$lang\t$type\t$key" )
                      if exists( $sections->{type}->{$key} );
                    $sections->{type}->{$key}->{lines} = [];
                    $sections->{type}->{$key}->{flex}  = $flex;
                    $sections->{type}->{$key}->{loc}   = $loc;
                    $sections->{type}->{$key}->{num}   = $num;
                    $sections->{type}->{$key}->{type}  = $type;

                    # Check level
                    if ( $eqstart ne '===' or $eqend ne '===' ) {
                        if ( $eqstart eq '' and $eqend eq '' ) {
                            special_log( 'section_type_no_equal', $title,
                                "$lang\t$eqstart $type $eqend" );
                        }
                        else {
                            special_log( 'section_type_number_of_equal',
                                $title, "$lang\t$eqstart $type $eqend" );
                        }
                    }

                    next;

                    # Level4: don't care for now, continue
                }
                elsif ( exists $level4->{$type} ) {
                    #########################
                    # Need to at least check their level
                    # Unknown level3 or 4: log
                }
                else {
                    $key   = '';
                    $level = '';
                    special_log( 'section_unknown', $title,
                        "$templevel\t$type" );
                }
            }
        }

        # Retrieve text
        # Level3 section text
        if ($level) {
            push @{ $sections->{ $level3->{$level} }->{lines} }, $line;
        }

        # Type section text
        elsif ($key) {
            push @{ $sections->{type}->{$key}->{lines} }, $line;
        }
    }

    # Clean up "ébauches"
    if (    $sections->{'etymologie'}
        and $#{ $sections->{'etymologie'}->{lines} } == 0
        and ${ $sections->{'etymologie'}->{lines} }[0] =~ /\{\{ébauche-étym/ )
    {
        delete $sections->{'etymologie'};
    }

    return $sections;
}

sub parseType {
    my ( $article, $title ) = @_;
    die "Not an array (parseType)\n" if not ref($article) eq 'ARRAY';
    die "Empty array (parseType)\n"  if $#{$article} == -1;
    die "Not a text (parseType)\n"   if not ref($title) eq '';
    die "No title (parseType)\n"     if not $title;

    # Extract the main sections:
    my $sections = {};
    $sections->{'head'} = ();

    my $line;

    # HEAD
    while ( $line = shift @$article ) {
        unless ( $line =~ /\{\{-.+?-[\|\}]/ ) {
            push @{ $sections->{'head'} }, $line;
        }
        else {
            last;
        }
    }

    # OTHER SUB SECTIONS
    my $level = '';
    my $num   = '';
    if ( $line and $line =~ /\{\{-(.+?)-[\|\}]/ ) {
        my $templevel = $1;
        if ( exists $level4->{$templevel} ) {
            $level = $templevel;
            $sections->{$level} = ();
        }
        else {
            special_log( 'level4', $title, $templevel );
        }
    }
    else {
        # This article does not contain any level4 section
        special_log( 'nolevel4', $title );
        return $sections;
    }

    # continue to retrieve the sections
    while ( $line = shift @$article ) {

        # Another section?
        if ( $line =~ /{{-(.+?)-[\|\}]/ ) {
            my $templevel = $1;
            if ( exists $level4->{$templevel} ) {
                $level = $templevel;
                $sections->{$level} = ();
                next;
            }
            else {
                special_log( 'level4', $title, $templevel );
            }
        }

        # Continue this language
        if ( exists $level4->{$level} ) {
            push @{ $sections->{$level} }, $line;
        }
    }

    return $sections;
}

sub is_gentile {
    my ( $lines, $type ) = @_;
    my $gent = 0;
    return 0 if $type ne 'nom' and $type ne 'adj';

    foreach my $line (@$lines) {
        if (
            $line =~ /\{\{note-gentilé/
            or (
                $type eq 'nom'
                and ( $line =~
/# *(?:\{\{[^\}]+\}\} *)*(?:\[\[habitant\|)?Habitant(?:\]\])? (?:de|du|d'|d’)/
                    or $line =~
/# *(?:\{\{[^\}]+\}\} *)*(?:Personne|Membre) du peuple (?:de|du|d'|d’)/
                    or $line =~
                    /# *(?:\{\{[^\}]+\}\} *)*(?:\[\[peuple\|)?Peuple(?:\]\])?/ )
            )
            or (
                $type eq 'adj'
                and ( $line =~
/# *(?:\{\{[^\}]+\}\} *)*Relatif (?:à|au) .+?, (?:commune|ville|village|région|pays|continent)/
                    or $line =~
/# *(?:\{\{[^\}]+\}\} *)*(?:Relatif à la|Relatif au|Qui concerne) [A-ZÉÈ].+? ses habitants/
                )
            )
          )
        {
            $gent = 1;
            last;
        }
    }
    return $gent;
}

sub section_meanings {
    my ( $lines, $title, $lang ) = @_;
    my @defs = ();

    foreach my $line (@$lines) {

        # End if next section
        if ( $line =~ /^=+|^\{\{-/ ) {
            last;
        }
        elsif ( $line =~ /^#+\s*([^\*]+)\s*$/ ) {
            next if $line =~ /^[:*]/;
            my $def = $1;
            chomp($def);

            # Remove html comments
            if ( $def =~ s/<!--(.+?)-->//g ) {
                special_log( 'def_html_comments', $title, "$lang : $1" );
            }

            # No variants, stubs and such
            if (   $def =~ /\{\{(variante|ébauche)/
                or $def =~ /Variante orthographique/ )
            {
                next;
            }

            # Remove wiki italic/bold
            $def =~ s/('{3})(.+?)\1/$2/g;
            $def =~ s/('{2})(.+?)\1/$2/g;

            # Recognize some templates
            $def =~ s/\{\{terme?\|([^\|\}]+?)\}\} */($1) /g;
            $def =~ s/\{\{lien\|([^\|\}]+?)(\|.+)?\}\}/$1/g;
            $def =~ s/\{\{w\|([^\|\}]+?)\}\}/$1/g;
            $def =~ s/\{\{cf\|([^\}]+?)\}\}/cf $1/g;
            $def =~ s/\{\{formatnum:([^\}]+?)\}\}/$1/g;
            $def =~ s/\{\{ex\|(.+)\}\}/<sup>$1<\/sup>/g;
            $def =~ s/\{\{x10\|(.+)\}\}/×10<sup>$1<\/sup>/g;

            # Fchim : enlève les séparateurs, met les numéros en indice
            $def =~ s/(\{\{fchim\|.*)\|([\|\}])/$1$2/g;
            $def =~ s/\{\{fchim\|(.*)([0-9]+)(.*)\}\}/$1<sub>$2<\/sub>$3/g;

            # Réfs
            $def =~ s/<\/?ref>//g;
            $def =~ s/\{\{R\|[^\}]+\}\}//g;

            # Change templates like {{foo}} into the form (foo)
            $def =~ s/\{\{([^\\}\|]+)\|[^\}]+\}\} */($1) /g;
            $def =~ s/\{\{([^\\}\|]+)\}\} */($1) /g;
            $def =~ s/\[\[[^\|\]]+\|([^\|\]]+)\]\]/$1/g;
            $def =~ s/\[\[([^\|\]]+)\]\]/$1/g;

            # First letter in a parenthesis = uppercase
            $def =~ s/\((.)/(\u$1/g;

            push @defs, $def;
        }
    }
    return \@defs;
}

sub cherche_genre {
    my ( $lignes, $lang, $titre, $type ) = @_;

    if ( ref($lignes) eq '' ) {
        special_log( 'mef', $titre, '', "en $lang" );
        return;
    }

    # Stop at the form line
    my $genre = '';
    my $max   = 0;
    foreach my $ligne (@$lignes) {
        if ( $ligne =~
/^'''.+?''' .*\{\{(m|f|c|fplur|fsing|fm \?|genre|mf|mf \?|mn \?|mplur|msing|n|nplur|nsinig|i|t)\}\}/
          )
        {
            $genre = $1;
            last;
        }
        elsif ( $ligne =~ /^'''.+'''/ ) {
            last;
        }
        $max++;
        if ( $max > 15 ) {
            special_log( 'ligne_forme_loin', $titre, "$lang" . "-$type" );
            last;
        }
    }

    return $genre;
}

sub is_sigle {
    my ( $lignes, $lang, $titre, $type ) = @_;

    if ( ref($lignes) eq '' ) {
        special_log( 'mef', $titre, '', "en $lang" );
        return;
    }

    # Stop at the form line
    my $sigle = '';
    my $max   = 0;
    foreach my $ligne (@$lignes) {
        if ( $ligne =~
/^'''.+?''' .*\{\{(sigle|abrév|abréviation|acron|acronyme)(?:\|.+)?\}\}/
          )
        {
            $sigle = $1;
            $sigle = 'abrev' if $sigle eq 'abrév' or $sigle eq 'abréviation';
            $sigle = 'acron' if $sigle eq 'acronyme';
            last;
        }
        elsif ( $ligne =~ /^'''.+'''/ ) {
            last;
        }
        $max++;
        if ( $max > 15 ) {
            special_log( 'ligne_forme_loin', $titre, "$lang" . "-$type" );
            last;
        }
    }

    return $sigle;
}

1;

__END__


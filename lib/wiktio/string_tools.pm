#!/usr/bin/perl -w

# Wiktionnaire parser
# Author: Matthieu Barba
#
# This module contains tools to manipulate and transform strings

package wiktio::string_tools;

use Exporter;
@ISA       = ('Exporter');
@EXPORT_OK = qw(
  APItoSAMPA
  SAMPAtoAPI
  ascii
  ascii_strict
  anagramme
  unicode_NFKD
  unisort_key
);

use strict;
use warnings;

use utf8;
use open IO => ':encoding(UTF-8)';
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

use Encode;
use Unicode::Normalize;
use wiktio::basic;
use wiktio::basic qw( $langues_transcrites );

sub unicode_NFKD {
    my ($mot0) = @_;

    my $mot = $mot0;

    $mot = NFKD($mot);
    $mot =~ s/\pM//g;
    return $mot;
}

sub ascii {
    my ($mot0) = @_;
    my $mot = $mot0;

    # Lettres spéciales
    $mot =~ s/Æ/AE/g;
    $mot =~ s/æ/ae/g;
    $mot =~ s/Œ/OE/g;
    $mot =~ s/œ/oe/g;
    $mot =~ s/ø/oe/g;
    $mot =~ s/’/'/g;
    $mot =~ s/ʻ/'/g;

    #
    # 	# Enlever les caractères superflus
    $mot =~ s/&amp;//g;
    $mot =~ s/&quot;//g;
    $mot =~ s/‿/ /g;
    $mot =~ s/…/.../g;
    $mot =~ s/_/ /g;

    $mot = unicode_NFKD($mot);

    $mot =~ s/[\/!?,><=\$~·;ː:(){}\[\]\\`]//g;

    # 	$mot =~ s/[^\x00-\x7F]+//g;		#Ne garder que les caractères ascii

    # Check
    if ( $mot eq '' ) {

        # 		print STDERR "Mot vide: '$mot0'\n";
        return '';

        # 	} elsif ($mot =~ /[a-zA-Z0-9]/ and $mot =~ /^[a-zA-Z0-9 \.'&\-]+$/) {
        # 		return $mot;
        # 	} else {
        # 		print STDERR "Asciisation incomplète : '$mot0' -> '$mot'\n";
        # 		return '';
        # 	}
    }
    else {
        return $mot;
    }
}

sub ascii_strict {
    my $mot0 = shift;
    my $mot  = $mot0;
    $mot = ascii($mot);

    # Strict
    $mot =~ s/[\.'\-]//g;

    return $mot;

    # 	if ($mot =~ /^[a-zA-Z0-9]+$/) {
    # 		return $mot;
    # 	} else {
    # # 		print "non ascii strict: $mot\n";
    # 		return '';
    # 	}
}

sub unisort_key {
    my ($word) = @_;
    return lc( ascii($word) ) . ' | ' . $word;
}

sub anagramme {
    my $mot0 = shift;

    my $mot = lc( ascii_strict($mot0) );

    # Sort and create alphagram
    if ($mot) {
        my @lettres = split( '', $mot );
        $mot = join( '', sort @lettres );
    }

    # Check
    return $mot;
}

1;

__END__

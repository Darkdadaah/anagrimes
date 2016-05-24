
# Wiktionnaire bases
# Author: Matthieu Barba
# This module contains basic data and functions for Wiktionary fr
package wiktio::basic;

use Exporter;
@ISA = ('Exporter');

@EXPORT = qw(
  $log
  special_log
  $true $false
  print_value
  to_utf8
);

@EXPORT_OK = qw(
  $langues_transcrites
  step
  stepl
);

use strict;
use warnings;

use utf8;
use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use Encode qw(decode);

our $true  = 1;
our $false = 0;

our $log = '';

sub step {
    print STDERR $_[0] ? ( $_[0] =~ /[\r\n]$/ ? "$_[0]" : "$_[0]\n" ) : "\n";
}
sub stepl { print STDERR $_[0] ? "$_[0]" : "" }

# Print a value for a given hash ref, array ref or text
sub print_value {
    my ( $text, $ref ) = @_;

    # Get the number if the ref is a hash or an array
    my $val = '';
    if ( ref($ref) eq 'ARRAY' ) {
        $val = $#{$ref} + 1;
    }
    elsif ( ref($ref) eq 'HASH' ) {
        $val = keys %$ref;
    }
    else {
        $val = $ref;
    }

    # Print the value
    step( sprintf( $text, $val ) );
}

# Log specific errors in separate files
sub special_log {
    my ( $nom, $titre, $texte, $other ) = @_;
    return if not $log;

    my $logfile = $log . '_' . $nom;

    open( LOG, ">>$logfile" ) or die("Couldn't write $logfile: $!");
    my $raw_texte = $texte ? $texte : '';

    #$raw_texte =~ s/\[\[([^\]]+)\]\]/__((__$1__))__/g;
    $raw_texte .= "\t($other)" if $other;
    print LOG "$titre\t$raw_texte\n";
    close(LOG);
}

sub to_utf8 {
    my $opts = shift;

    if ( ref($opts) eq 'HASH' ) {
        foreach my $v ( keys %$opts ) {
            $opts->{$v} = Encode::decode( 'UTF-8', $opts->{$v} );
        }
    }
    elsif ( ref($opts) eq 'HASH' ) {
        map { Encode::decode( 'UTF-8', $_ ); } @$opts;
    }
    elsif ( ref($opts) eq '' ) {
        $opts = Encode::decode( 'UTF-8', $opts );
    }
    return $opts;
}
1;

1;

__END__

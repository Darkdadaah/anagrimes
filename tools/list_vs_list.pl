#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;

# UTF8
use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use utf8;

our %opt;    # Getopt options

#################################################
# Message about this program and how to use it
sub usage {
    print STDERR "[ $_[0] ]\n" if $_[0];
    print STDERR << "EOF";
	
	This script compares two words lists.
	
	usage: $0 [-h] -f file
	
	-h        : this (help) message
	
	-r <path> : path to the first list (reference)
	-t <path> : path to the second list (test)

	Outputs:
	-o <path> : words from the test not found in the reference
	
	Options:
	-d        : don't take diacritics into account
	-L        : ignore locutions
EOF
    exit;
}

##################################
# Command line options processing
sub init() {
    getopts( 'r:t:o:L', \%opt ) or usage();
    usage() if $opt{h};
    usage("No reference file given (-r)") unless $opt{r};
    usage("No test file given (-t)")      unless $opt{t};
    usage("No output file given (-o)")    unless $opt{o};
}

####################################################################
# FUNCTIONS

sub get_words {
    my ( $file, $no_loc ) = @_;

    my $list = {};

    open( FILE, $file ) or die("$file: $!");
    while (<FILE>) {
        my $line = $_;
        chomp($line);

        my ($word) = split( /\t|","/, $line );
        next if not $word;
        next if $no_loc and $word =~ / /;
        $word =~ s/"//g;

        my $key = $word;
        $key = nodia($key);
        $list->{$key}++;

        if ( $word =~ / / ) {
            my @sub_words = split( ' ', $word );
            map { my $key = nodia($_); $list->{$key} = $_; } @sub_words;
        }
    }
    close(FILE);

    return $list;
}

sub nodia {
    my ( $w, $nodiacritics ) = @_;
    return $w if not $nodiacritics;

    $w = lc($w);
    $w =~ tr/ââä/aaa/;
    $w =~ tr/éèêë/eeee/;
    $w =~ tr/îï/ii/;
    $w =~ tr/ôö/oo/;
    $w =~ tr/ûü/uu/;

    return $w;
}

####################################################################
# MAIN
init();

# Get reference word list
my $rt = get_words( $opt{r}, $opt{L} );

{
    print STDERR keys(%$rt) . " mots dans la liste de référence\n";
}

# Compare every word
open( TEST, $opt{t} )    or die("$opt{t}: $!");
open( OUT,  ">$opt{o}" ) or die("Couldn't write $opt{o}: $!");
my $nref    = 0;
my $missing = 0;
while (<TEST>) {
    next if /^\s*$/;

    my $line = $_;
    chomp($line);

    my ($word) = split( /\t|","/, $line );
    $word =~ s/"//g;
    next if $opt{L} and $word =~ / /;

    my $key = nodia( $word, $opt{d} );

    # Not in the reference?
    if ( not $rt->{$key} ) {
        print OUT "$line\n";
        $missing++;
    }
    else {
        delete $rt->{$key};
    }
    $nref++;
}
close(OUT);
close(TEST);

{
    print STDERR "$nref mots dans la liste test\n";
}

{
    print STDERR
      "$missing mots de la test absents de la liste de référence\n";
}

__END__

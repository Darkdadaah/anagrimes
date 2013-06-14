#!/usr/bin/perl -w

use strict ;
use warnings ;
# UTF8
use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use utf8 ;

my $nodiacritics = 1 ;

####################################################################
# FUNCTIONS

sub get_words($)
{
        my $file = shift ;
        
        my $list = {} ;
        
        open(FILE, $file) or die("$file: $!") ;
        my $code = 'utf8' ;
        while(<FILE>) {
                my $line = $_ ;
                chomp($line) ;
                
                my ($word) = split(/\t|","/, $line) ;
                next if not $word ;
                $word =~ s/"//g ;

                my $key = $word ;
                $key = nodia($key) ;
                $list->{$key} = $word ;
                
                if ($word =~ / /) {
                        my @sub_words = split(' ', $word) ;
                        map { my $key = nodia($_) ; $list->{$key} = $_ ; } @sub_words ;
                }
        }
        close(FILE) ;
        
        return $list ;
}

sub nodia {
        my ($w)  = @_ ;
        return $w if not $nodiacritics ;
        
        $w =~ s/(â|â|ä)/a/g ;
        $w =~ s/(é|è|ê|ë)/e/g ;
        $w =~ s/(î|ï)/i/g ;
        $w =~ s/(ô|ö)/o/g ;
        $w =~ s/(û|ü)/u/g ;

        $w = lc($w) ;
        
        return $w ;
}

####################################################################
# MAIN

# Get files
my $refs = $ARGV[0] ;   die("No reference file provided\n") unless $refs ;
my $test = $ARGV[1] ;   die("No test file provided\n") unless $test ;

# Get refs word list
my $rt = get_words($test) ;

# Compare every word
open(REF, $refs) or die("$refs: $!") ;
my $nref=0 ;
my $missing=0 ;
my $code = 'utf8' ;
while(<REF>) {
        next if /^\s*$/ ;
        
        my $line = $_ ;
        chomp($line) ;
        
        my ($word) = split(/\t|","/, $line) ;
        $word =~ s/"//g ;
        
        my $key = nodia($word) ;
        
        # Not in the test?
        if (not $rt->{$key}) {
                print STDOUT "$word\n" ;
                $missing++ ;
        }
        $nref++ ;
}
close(REF) ;

{
        print STDERR "$nref mots dans la liste référence\n" ;
}

{
        print STDERR keys(%$rt)." mots dans la liste test\n" ;
}

{
        print STDERR "$missing mots de la référence absents de la liste test\n" ;
}


__END__

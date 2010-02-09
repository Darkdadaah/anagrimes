#!/usr/bin/perl -w

# Test the functions ascii etc.
use strict ;
use warnings ;

use utf8 ;
use open IO => ':utf8';
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use lib '..' ;
use wiktio::string_tools	qw(ascii ascii_strict anagramme) ;
our %opt ;

while(<>) {
	chomp ;
	print soundex($_), "\n" ;
}


sub soundex
{
	my $word = shift ;
	my $soundex = uc(ascii_strict($word)) ;
	
	# Extract first letter
	my $first = substr($soundex, 0, 1) ;
	$soundex = substr($soundex, 1, length($soundex)-1) ;
	
	# No voyel
	$soundex =~ s/[AEHIOUWY]//g ;
	
	# Numberize
	$soundex =~ tr/BPCKQDTLMNRGJXZSFV/112223345567788899/ ;
	
	# No doubles
	for (my $n = 1 ; $n <= 9 ; $n++) {
		$soundex =~ s/$n+/$n/g ;
	}
	
	# reappend the first
	$soundex = $first . $soundex ;
	
	# Cut or complete
	my $len = length($soundex) ;
	if ($len > 4) {
		$soundex = substr($soundex, 0, 4) ;
	} elsif ($len < 4) {
		$soundex .= '0'x(4-$len) ;
	}
	
	return $soundex ;
}


__END__

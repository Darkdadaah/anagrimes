#!/usr/bin/perl -w

# Test the functions ascii etc.
use strict ;
use warnings ;

use utf8 ;
use open IO => ':encoding(utf8)';
binmode STDIN, ":encoding(utf8)";
binmode STDOUT, ":encoding(utf8)";
binmode STDERR, ":encoding(utf8)";
use Encode qw(decode encode);



use lib '..' ;
use wiktio::string_tools	qw(ascii ascii_strict anagramme) ;

foreach my $a (@ARGV) {
	my $u = decode("utf-8", $a) ;
	print STDERR ("$a / $u\t", length($a), ' / ', length($u), "\n") ;
}

while(<STDIN>) {
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
	my $lim = 4 ;
	my $len = length($soundex) ;
	if ($len > $lim) {
		$soundex = substr($soundex, 0, $lim) ;
	} elsif ($len < $lim) {
		$soundex .= '0'x($lim-$len) ;
	}
	
	return $soundex ;
}


__END__

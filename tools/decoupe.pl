#!/usr/bin/perl -w
use strict ;

my $file = $ARGV[0] ;

die("Fichier nécessaire (argument 1)\n") if not $file ;
print "$file\n" ;
open(FILE, "<$file") or die("") ;

# Declarations
my $max= $ARGV[1] ? $ARGV[1] : 100000 ;
my $num=1 ;
my $n=0 ;

# Suffix?
my $filename = '' ;
my $suff = '' ;
if ($file =~ /^(.+)(\..+?)$/) {
	$filename = $1 ;
	$suff = $2 ;
}  else {
	$filename = $file ;
	$suff = '' ;
}
my $out = $filename.'_'.$num.$suff ;

# First file
open(OUT, ">$out") or die "Error" ;

# Ecrit la première ligne pour chaque fichier
my $first = <FILE> ;
print OUT $first ;

while (<FILE>) {
	if ($n>$max) {
		$num++ ;
		$n=0 ;
		close(OUT) ;
		$out =  $filename.'_'.$num.$suff ;
		open(OUT, ">$out") or die "Error" ;
		print OUT $first ;
	}
	print OUT $_ ;
	
	$n++ ;
}
close(OUT) ;
close(FILE) ;
__END__

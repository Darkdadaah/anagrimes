#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;

our %opt;	# Getopt options

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0];
	print STDERR << "EOF";
	
	This script split a list in smaller lists with a given max length.
	
	usage: $0 [-h] -f file
	
	-h        : this (help) message
	
	-i <path> : path to the list to split
	-l <int>  : max number of elements in each subfile

	Optional:
	-H        : keep the first line in every file
	-T        : keep the last line in every file
EOF
	exit;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'i:l:HT', \%opt ) or usage();
	usage() if $opt{h};
	usage("No file given (-i)") unless $opt{i};
	usage("No max length given (-l)") unless ($opt{l} and $opt{l} > 0);
}

sub split_file
{
	my ($list_path, $max, $head, $tail) = @_;


	open(LIST, "<$list_path") or die("Couldn't read list file $list_path: $!");
	
	# Define iterator arguments
	my $num=1;	# For the file name
	my $n=0;	# For the number of lines

	# If the filename has a suffix, keep the suffix while numbering the sub-files
	my $filename = '';
	my $suff = '';
	if ($list_path =~ /^(.+)(\..+?)$/) {
		$filename = $1;
		$suff = $2;
	}  else {
		$filename = $list_path;
		$suff = '';
	}
	my $out_path = $filename.'_'.$num.$suff;
	
	# Begin to write the first file
	open(OUT, ">$out_path") or die("Couldn't write $out_path: $!");

	# Write the first line in each file
	my $first = '';
	if ($head) {
		$first = <LIST>;
		print OUT $first;
	}
	
	# Read the list file...
	my $last = '';
	while (my $line = <LIST>) {
		# If we reached the max number or lines, close the current file
		# and open a new one with the next file number
		if ($n >= $max) {
			# Close old file
			$n=0;
			close(OUT);
			
			# Init new file
			$num++;
			my $out_path =  $filename.'_'.$num.$suff;
			open(OUT, ">$out_path") or die("Couldn't write $out_path: $!");
			print OUT $first if $opt{H};
		}
		# Continue to write the lines from the original file
		print OUT $line;
		$n++;
		$last = $line;
	}
	close(OUT);
	close(LIST);
	
	# Write the last line for every file (except the last one)
	if ($tail) {
		for (my $i=1; $i < $num; $i++) {
			my $out_path =  $filename.'_'.$i.$suff;
			
			open(OUT, ">>$out_path") or die("Couldn't append to $out_path: $!");
			print OUT $last;
			close(OUT);
		}
	}
	
	return $num;
}

##################################
# MAIN
init();

my $num = split_file($opt{i}, $opt{l}, $opt{H}, $opt{T});
print STDERR "$num files created\n";

__END__


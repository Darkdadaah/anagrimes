#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;
use lib '..';
use wiktio::string_tools qw(ascii);
use utf8;
use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

our %opt;    # Getopt options

#################################################
# Message about this program and how to use it
sub usage {
    print STDERR "[ $_[0] ]\n" if $_[0];
    print STDERR << "EOF";

    This script split a list in smaller lists with a given max length.

    usage: $0 [-h] -f file

    -h        : this (help) message

    -i <path> : path to the list to split
    -l <int>  : max number of elements in each subfile
    -A        : try to cut first letters together (-l needed)

    Optional:
    -H        : keep the first line in every file
    -T        : keep the last line in every file
EOF
    exit;
}

##################################
# Command line options processing
sub init() {
    getopts( 'i:l:HTA', \%opt ) or usage();
    usage() if $opt{h};
    usage("No file given (-i)") unless $opt{i};
    usage("Max length or alphabet order to give (-l|-A)")
      unless ( $opt{l} and $opt{l} > 0 or $opt{A} );
}

sub split_file {
    my ( $list_path, $max, $head, $tail, $alphabet ) = @_;

    open( LIST, "<$list_path" )
      or die("Couldn't read list file $list_path: $!");

    # Define iterator arguments
    my $num = 1;    # For the file name
    my $n   = 0;    # For the number of lines

   # If the filename has a suffix, keep the suffix while numbering the sub-files
    my $filename = '';
    my $suff     = '';
    if ( $list_path =~ /^(.+)(\..+?)$/ ) {
        $filename = $1;
        $suff     = $2;
    }
    else {
        $filename = $list_path;
        $suff     = '';
    }
    my $out_path = $filename . '_' . $num . $suff;

    # Begin to write the first file
    open( OUT, ">$out_path" ) or die("Couldn't write $out_path: $!");

    # Write the first line in each file
    my $first = '';
    if ($head) {
        $first = <LIST>;
        print OUT $first;
    }

    # Read the list file...
    my $last   = '';
    my @files  = ($out_path);
    my $letter = '';
    while ( my $line = <LIST> ) {
        next if $line =~ /^\s*$/;

        # Find first letter
        my $cur_letter = '';
        my $title      = $line;
        if ( $title =~ /^([^\]]+\]\]).*$/ ) {
            $title = $1;
        }
        my $asciized = ascii($title);
        if ( $asciized =~ /^[^\-\p{Letter}]*(\-|\p{Letter})/ ) {
            $cur_letter = "\L$1";
            $cur_letter = $letter if $asciized =~ /\d/;
        }

        # If we reached the max number or lines, close the current file
        # and open a new one with the next file number
        if (   ( $max and $n >= $max )
            or ( $alphabet and $cur_letter ne $letter ) )
        {
            warn("$letter -> $cur_letter\n");

            # Close old file
            $n = 0;
            close(OUT);

            # Init new file
            $num++;
            my $id = ( $alphabet and $cur_letter ) ? $cur_letter : $num;
            my $out_path = $filename . '_' . $id . $suff;
            push @files, $out_path;
            open( OUT, ">$out_path" ) or die("Couldn't write $out_path: $!");
            print OUT $first if $head;
        }

        # Continue to write the lines from the original file
        print OUT $line;
        $n++;
        $letter = $cur_letter;
        $last = $line if not $line =~ /^\s*$/;
    }
    close(OUT);
    close(LIST);

    # Write the last line for every file (except the last one)
    if ($tail) {
        foreach my $out_path (@files) {
            open( OUT, ">>$out_path" )
              or die("Couldn't append to $out_path: $!");
            print OUT "$last\n";
            close(OUT);
        }
    }

    return $num;
}

##################################
# MAIN
init();

my $num = split_file( $opt{i}, $opt{l}, $opt{H}, $opt{T}, $opt{A} );
print STDERR "$num files created\n";

__END__


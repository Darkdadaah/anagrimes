#!/usr/bin/perl -w

# Wiktionnaire parser
# Author: Matthieu Barba
#
# This module extracts text for every article
# in a Wikimedia project xml dump

package wiktio::dump_reader;

use Exporter;    # So that we can export functions and vars
@ISA = ('Exporter');    # This module is a subclass of Exporter

# What can be exported
@EXPORT = qw( open_dump parse_dump );

use strict;
use warnings;

use utf8;
use open IO => ':encoding(UTF-8)';
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

# Change the input to automatically handle file compression
sub _dump_input {
    my $infile = shift;

    # Open file (compressed or not)
    my $input = '';
    if ( $infile =~ /\.bz2$/ ) {
        $input = "bzcat $infile |";
    }
    elsif ( $infile =~ /\.gz$/ ) {
        $input = "gunzip -c $infile |";
    }
    elsif ( $infile =~ /\.7z$/ ) {
        $input = "7z x -so $infile 2> /dev/null |";
    }
    elsif ( $infile =~ /\.xml$/ ) {
        $input = $infile;
    }
    else {
        print STDERR
          "Error: unsupported dump file format or compression: $infile\n";
        exit(1);
    }

    return $input;
}

sub open_dump {
    my ($dump_path) = @_;
    open( my $dump_fh, _dump_input($dump_path) )
      or die("Couldn't open '$dump_path': $!\n");
    return $dump_fh;
}

# Right now this parser uses regex to get data from an XML file...
# should change it to a real XML reader
sub parse_dump {
    my ( $dump_fh, $param ) = @_;
    my %par = $param ? %$param : ();

    my $in_revision = 0;
    my %article     = ();
    $article{'fulltitle'}    = undef;
    $article{'namespace'}    = undef;
    $article{'title'}        = undef;
    $article{'content'}      = [];
    $article{'redirect'}     = undef;
    $article{'contributors'} = {};
    $article{'id'}           = undef;

  LINE: while ( my $line = <$dump_fh> ) {

        # Get page title
        # one line
        if ( $line =~ /<title>(.+?)<\/title>/ ) {
            $article{'fulltitle'} = $1;
        }

        # several lines
        elsif ( $line =~ /<title>(.*?)$/ ) {
            $article{'fulltitle'} = $1;
            $article{'fulltitle'} =~ s/[\r\n]+/ /;
            while ( my $inline = <$dump_fh> ) {
                if ( not $inline =~ /<\/title>/ ) {
                    $article{'title'} .= $inline;
                }
                elsif ( $inline =~ /^(.*)<\/text>/ ) {
                    $article{'title'} .= $1 if defined($1);
                    next LINE;
                }
            }
        }

        # Get content
        # No line
        elsif ( $line =~ /<text[^>]*\/>$/ ) {
            @{ $article{'content'} } = ('');
            last LINE;
        }

        # one line
        elsif ( $line =~ /<text.*>(.*?)<\/text>/ ) {

            # Latest version or whole history?
            if ( $par{whole_history} and $article{'content'} ) {
                push @{ $article{'content'} }, $1;
            }
            else {
                @{ $article{'content'} } = $1;
            }
        }

        # several lines
        elsif ( $line =~ /<text.*>(.*?)$/ ) {

            # Latest version or whole history?
            if ( $par{whole_history} and $article{'content'} ) {
                push @{ $article{'content'} }, $1;
            }
            else {
                @{ $article{'content'} } = $1;
            }

            while ( my $inline = <$dump_fh> ) {
                if ( not $inline =~ /<\/text>/ ) {
                    push @{ $article{'content'} }, $inline;
                }
                elsif ( $inline =~ /^(.*)<\/text>/ ) {
                    push @{ $article{'content'} }, $1 if defined($1);
                    next LINE;
                }
            }
        }

        # Get page authors
        elsif ( $line =~ /<username>(.+?)<\/username>/ ) {
            $article{'contributors'}{$1}++;
        }

        # Get namespace
        elsif ( $line =~ /<ns>([0-9]+?)<\/ns>/ ) {
            $article{'ns'} = $1;
        }

        # Revision? (we don't want revision id)
        elsif ( $line =~ /<revision>/ ) {
            $in_revision = 1;
        }

        # Get article id
        elsif ( $line =~ /<id>([0-9]+?)<\/id>/ ) {
            if ( not $in_revision ) {
                $article{'id'} = $1;
            }
        }

        # End of page
        elsif ( $line =~ /<\/page>/ ) {

            # No use returning an incomplete article
            if ( not defined( $article{'fulltitle'} ) ) {
                return {};
            }
            last LINE;
        }
        elsif ( $line =~ /<\/mediawiki>/ or eof($dump_fh) ) {
            return undef;
        }
    }

    # Is it a redirect?
    $article{'redirect'} = _is_redirect( \%article );

    # What is the namespace?
    ( $article{'namespace'}, $article{'title'} ) =
      _extract_namespace( \%article );

    return \%article;
}

sub _is_redirect {
    my ($article) = @_;

    # Only look at the first line
    my $first_line = $article->{'content'}->[0];

    if ( $first_line and $first_line =~ /#redirect(ion)? *:? *\[\[(.+?)\]\]/i )
    {
        return $2;
    }
    return;
}

sub _extract_namespace {
    my ($article) = @_;
    return ( undef, undef ) unless defined( $article->{'fulltitle'} );

    my $ns    = undef;
    my $title = "$article->{'fulltitle'}";
    if ( $title =~ /^([^:]+?):(.+?)$/ ) {
        $ns    = $1;
        $title = $2;
    }

    return $ns, $title;
}

1;

__END__


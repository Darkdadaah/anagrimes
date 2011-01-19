#!/usr/bin/perl -w

# Test the functions ascii etc.
use strict ;
use warnings ;
use Getopt::Std ;

use utf8 ;
use Encode qw(decode encode) ;
use open IO => ':utf8';
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use lib '..' ;
use wiktio::string_tools	qw(ascii ascii_strict anagramme) ;
use wiktio::parser		qw(parseArticle parseLanguage parseType) ;
our %opt ;
my $redirects = '' ;
my $articles = '' ;

# Defaut
# $opt{i} = '' ;

#################################################
# Message about this program and how to use it
sub usage
{
	print STDERR "[ $_[0] ]\n" if $_[0] ;
	print STDERR << "EOF";
	
	This script parse a Wiktionary dump and extract article names
	
	usage: $0 [-h] -f file
	
	-h        : this (help) message
	-i <path> : dump path
	-o <path> : list of all the articles selected
	-O <path> : list of all articles with the pattern but excluded
	-p <str>  : pattern to search
	-n <str>  : pattern to exclude
	-S <str>  : use this namespace
	
	-s        : special (see script)
	
	-L <str>  : language to include only
	-N <str>  : language to exclude
	
	-F <path> : path to a list of general patterns to search
	
	example: $0 -i data/frwikt.xml
EOF
	exit ;
}

##################################
# Command line options processing
sub init()
{
	getopts( 'hi:o:O:p:n:S:L:N:F:s', \%opt ) or usage() ;
	usage() if $opt{h} ;
	usage( "Dump path needed (-i)" ) if not $opt{i} ;
	if (not $opt{F}) {
		if (not $opt{s} and not $opt{p}) {
			usage( "Pattern needed (-p)" ) ;
			usage( "Only 1 language option (-L|-N)" ) if $opt{L} and $opt{N} ;
		}
	}
	
	if ($opt{o}) {
		open(ARTICLES, "> $opt{o}") or die "Couldn't write $opt{o}: $!\n" ;
		close(ARTICLES) ;
	}
	if ($opt{O}) {
		open(ARTICLES, "> $opt{O}") or die "Couldn't write $opt{O}: $!\n" ;
		close(ARTICLES) ;
	}
	
	unless ($opt{s}) {
		$opt{p} = correct_pattern($opt{p}) ;
		$opt{n} = correct_pattern($opt{n}) ;
	}
}

###################################

sub correct_pattern
{
	my $p = shift ;
	$p = decode('utf8', $p) ;
	if ($p) {
		$p =~ s/</&lt;/ ;
		$p =~ s/>/&gt;/ ;
	}
	return $p ;
}

# REDIRECTS
sub redirect
{
}

sub get_patterns
{
	my ($file) = @_ ;
	
	open FILE, "<$file" or die "Couldn't read $file: $!" ;
	
	my ($lang, $no_lang, $pattern, $no_pattern, $output, $no_output) = (0,0,0,0,0,0) ;
	my @routines ;
	
	while (<FILE>) {
		if (/^BEGIN$/) {
			while (<FILE>) {
				last if /\/\// ;
				if (/^(.+)=(.+)$/) {
					if ($1 eq 'lang') {
						$lang = $2 ;
					} elsif ($1 eq 'no_lang') {
						$no_lang = $2 ;
					} elsif ($1 eq 'pattern') {
						$pattern = $2 ;
					} elsif ($1 eq 'no_pattern') {
						$pattern = $2 ;
					} elsif ($1 eq 'output') {
						$output = $2 ;
					} elsif ($1 eq 'no_output') {
						$no_output = $2 ;
					}
				}
			}
			if (/\/\//) {
				my @routine = ($lang, $no_lang, $pattern, $no_pattern, $output, $no_output) ;
				push @routines, \@routine ;
			}
		}
	}
	
	return @routines ;
}

###################################
# ARTICLE
sub article
{
	my ($article, $title) = @_ ;
	my %count = () ;
	if ($opt{F}) {
		foreach my $pattern (get_patterns($opt{F})) {
			($opt{L}, $opt{N}, $opt{p}, $opt{n}, $opt{o}, $opt{O}) = @$pattern ;
# 			print "$opt{L}, $opt{N}, $opt{p}, $opt{n}, $opt{o}, $opt{O}\n" ;
			$count{'Count'} = read_article($article, $title) ;
		}
	} else {
		my $name = 'Count' ;
		$count{$name} = read_article($article, $title) ;
	}
	return \%count ;
}

sub read_article
{
	my ($article0, $title) = @_ ;
	my $article = () ;
	if ($opt{L}) {
		my $lang = parseArticle($article0, $title) ;
		
		if ($lang->{'language'}->{$opt{L}}) {
			$article = $lang->{'language'}->{$opt{L}} ;
		} else {
			return 0 ;
		}
	} elsif ($opt{N}) {
		my $lang = parseArticle($article0, $title) ;
		
		if ($lang->{'language'}->{$opt{N}}) {
			delete $lang->{'language'}->{$opt{N}} ;
		}
		
		foreach my $l (keys %{$lang->{'language'}}) {
			if (not ref($lang->{'language'}->{$l}) eq 'ARRAY') {
				print STDERR "[[$title]]\tSection de langue vide : $l\n" ;
				next ;
			}
			push @$article, @{$lang->{'language'}->{$l}} ;
		}
		
	} else {
		$article = $article0 ;
	}
	
	my ($count, $n) = (0,0) ;
	my ($ok, $no) = (0,0) ;
	my ($ok_pattern, $no_pattern) = ('','') ;
	
	foreach my $line (@$article) {
		$n++ ;
		if ($opt{n} and $line =~ /($opt{n})/) {
			$no_pattern = "<< $1 >> ($n)" ;
			$no = 1 ;
		}
		if ($line =~ /($opt{p})/) {
			$count++ if not $no ;
			$ok_pattern = "<< $1 >> ($n)" ;
			$ok = 1 ;
			$line =~ s/$opt{p}// ;
		}
		while ($line =~ /($opt{p})/) {
			$count++ if not $no ;
			$ok_pattern .= "\t<< $1 >> ($n)" ;
			$line =~ s/$opt{p}// ;
		}
	}
	$ok_pattern =~ s/\n/\\n/g ;
	$ok_pattern =~ s/\r/\\r/g ;
	$no_pattern =~ s/\n/\\n/g ;
	$no_pattern =~ s/\r/\\r/g ;
	
	if ($ok and not $no and $opt{o}) {
		open(ARTICLES, ">> $opt{o}") or die "Couldn't write $opt{o}: $!\n" ;
		print ARTICLES "* [[$title]]\t$ok_pattern\n" ;
		close(ARTICLES) ;
	}
	if ($ok and $no and $opt{O}) {
		open(ARTICLES, ">> $opt{O}") or die "Couldn't write $opt{O}: $!\n" ;
		print ARTICLES "* [[$title]]\t$ok_pattern\t$no_pattern\n" ;
		close(ARTICLES) ;
	}
	return $count ;
}

###################
# MAIN
init() ;

# Connect
open(DUMP, $opt{i}) or die "Couldn't open '$opt{i}': $!\n" ;
my $title = '' ;
my ($n, $redirect) = (0,0) ;
my $complete_article = 0 ;
my %already = () ;
my @article = () ;
my $count = {} ;

while(<DUMP>) {
	if ( /<title>(.+?)<\/title>/ ) {
		$title = $1 ;
		# Exclut toutes les pages en dehors de l'espace principal
		if ($opt{S}) {
			$title = '' if not $title =~ /^$opt{S}:/ ;
		} else {
			$title = '' if $title =~ /[:\/]/ ;
		}
		
	} elsif ( $title and /<text xml:space="preserve">(.*?)<\/text>/ ) {
		@article = () ;
		push @article, "$1\n" ;
		$complete_article = 1 ;
		
		} elsif ( $title and  /<text xml:space="preserve">(.*?)$/ ) {
		@article = () ;
		push @article, "$1\n" ;
		while ( <DUMP> ) {
			next if /^\s+$/ ;
			if ( /^(.*?)<\/text>/ ) {
				push @article, "$1\n" ;
				last ;
			} else {
				push @article, $_ ;
			}
		}
		$complete_article = 1 ;
	}
	if ($complete_article) {
		if ($article[0] =~ /#redirect/i) {
			if ($opt{s}) {
				my $target = $article[0] ;
				$target =~ s/^.*\[\[(.+)\]\].*$/$1/ ;
				chomp($target) ;
				push @{$already{ lc($title) }}, "$title|]][[:$target|<sup>(<small>redirect</small>)</sup>" ;
				$n++ ;
				print "[$n] $title\n" if $n%500==0 ;
				$title = '' ;
				$redirect++ ;
			} else {
				######################################
				# Traiter les redirects ici
				redirect(\@article, $title) ;
				######################################
				$redirect++ ;
			}
		} else {
			if ($opt{s}) {
				push @{$already{ lc($title) }}, "$title|" ;
				$n++ ;
				print "[$n] $title\n" if $n%500==0 ;
				$title = '' ;
			} else {
				######################################
				# Traiter les articles ici
				my $article_count = article(\@article, $title) ;
				foreach my $num (keys %$article_count) {
					$count->{$num} += $article_count->{$num}  ;
				}
			}
			######################################
			$n++ ;
			print "[$n] $title\n" if $n%10000==0 ;
		}
		$complete_article = 0 ;
	}
}
close(DUMP) ;

print "Total = $n\n" ;
print "Total_redirects = $redirect\n" ;

if ($opt{s}) {
	print "Recherche des doublons: " ;
	# Filter special
	open(SPECIAL, ">> $opt{o}") or die("Couldn't write $opt{o}: $!\n") ;
	my $space = '' ;
	foreach my $t (sort keys %already) {
		my $num = $#{ $already{$t} }+1 ;
		if ($num == 1) {
			delete $already{$t} ;
		} else {
			(my $new_space) = split(':', $t) ;
			if ($space ne $new_space) {
				$space = $new_space ;
				print SPECIAL "\n== ". (ucfirst($space)) ." ==\n" ;
			}
			my $prefix = '' ;
			if ($space eq 'catégorie') {
				$prefix = ':' ;
			}
			print SPECIAL "* [[$prefix". join("]], [[$prefix", sort { $a cmp $b } @{ $already{$t} }) . "]]\n" ;
		}
	}
	close(SPECIAL) ;
	my $total = keys %already ;
	print "$total\n" ;
} else {
	foreach my $c (keys %$count) {
		print "$c:\t$count->{$c}\n" ;
	}
}

__END__
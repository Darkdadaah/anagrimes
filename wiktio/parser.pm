# Wiktionnaire parser
# Author: Matthieu Barba
#
# This module contain a specific parser
# of the content of the fr.wiktionary articles

package wiktio::parser ;

use Exporter ;		# So that we can export functions and vars
@ISA=('Exporter') ;	# This module is a subclass of Exporter

# What can be exported
@EXPORT_OK = qw( parseArticle printArticle parseLanguage printLanguage parseType printType is_gentile) ;

use strict ;
use warnings ;
use wiktio::basic 	qw( $level3 $word_type $level4 step ) ;

sub parseArticle
{
	my ($article0, $title) = @_ ;
	die "Not an array (parseArticle)\n" if not ref($article0) eq 'ARRAY' ;
	die "Empty array (parseArticle)\n" if $#{$article0} == -1 ;
	
	# copy
	my $article = () ;
	foreach my $line (@$article0) {
		push @$article, $line ;
	}
	
	# Extract the main sections:
	my $sections = {} ;
	$sections->{'tail'} = () ;
	$sections->{'head'} = () ;
	
	# head, languages, tail
	my $line ;
	my $language ='' ;
	
	# HEAD
	while ( my $line = shift @$article ) {
		if ( $line =~ /^#REDIRECT/i ) {
			$sections->{'redirect'} = 1 ;
			return $sections ;
		}
		# HEAD?
		unless ( $line =~ /\{\{=(.+?)=\}\}/ ) {
			push @{$sections->{'head'}}, $line ;
		} else {
			$language = $1 ;
			$sections->{'language'}->{$language} = () ;
			last ;
		}
	}
	
	# continue to retrieve the languages
	while ($line = shift @$article) {
		# TAIL ?
		if (
		$line =~ /^\{\{clé de tri/
		or
		$line =~ /^\[\[[a-z-]+?:.+?\]\]$/	# interwiki
		or
		$line =~ /^\[\[Catégorie:.+?\]\]$/i
		) {
			push @{$sections->{'tail'}}, $line ;
		}
		
		# Another language?
		elsif ( $line =~ /{{=(.+?)=}}/ ) {
			$language = $1 ;
			$sections->{'language'}->{$language} = () ;
		
		# Continue this language
		} else {
			push @{$sections->{'language'}->{$language}}, $line ;
		}
	}
	
	return $sections ;
}

sub printArticle
{
	my $sections = shift ;
	
	if ( $#{$sections->{'head'}} > -1 ) {
		step( "\n== HEAD ==" ) ;
		foreach ( @{$sections->{'head'}} ) {
			step( $_ ) ;
		}
	}
	
	foreach my $lang ( sort keys %{$sections->{'language'}} ) {
	step( "\n".("-"x50) ) ;
	step( "\n== LANGUAGE: $lang ==\n" ) ;
		if ( ref($sections->{'language'}->{$lang}) eq 'ARRAY' ) {
			foreach ( @{$sections->{'language'}->{$lang}} ) {
				step( $_ ) ;
			}
		} elsif ( ref($sections->{'language'}->{$lang}) eq 'HASH' ) {
			printLanguage( $sections->{'language'}->{$lang} ) ;
		}
	}
	
	if ( $#{$sections->{'tail'}} > -1 ) {
		step( "\n".("-"x50) ) ;
		step( "\n== TAIL ==" ) ;
		foreach ( @{$sections->{'tail'}} ) {
			step( $_ ) ;
		}
	}
}

sub parseLanguage
{
	my ( $article, $title ) = @_ ;
	die "Not an array (parseLanguage)\n" if not ref($article) eq 'ARRAY' ;
	die "Empty array (parseLanguage)\n" if $#{$article} == -1 ;
	
	# Extract the main sections:
	my $sections = {} ;
	$sections->{'head'} = () ;
	$sections->{'etymologie'} = () ;
	$sections->{'prononciation'}  = () ;
	$sections->{'voir'}  = () ;
	$sections->{'references'}  = () ;
	$sections->{'types'}  = {} ;
	
	my $line ;
	
	# HEAD
	while ( $line = shift @$article ) {
		unless ( $line =~ /\{\{-.+?-[\|\}]/ ) {
			push @{$sections->{'head'}}, $line ;
		} else {
			last ;
		}
	}
	
	# ETYM, TYPES?
	my $level = '' ;
	my $num = '' ;
	if ($line and ($line =~ /\{\{-(.+?)-[\|\}]/ or $line =~ /\{\{-(.+?)-\|.+[\|\}]/)) {
		$level = $1 ;
		if ( $line =~ /\|num=([0-9]+)[\|\}]/ ) {
			$num = '-'.$1 ;
		} else {
			$num = '' ;
		}
		if ( exists $level3->{$level} ) {
			$sections->{$level3->{$level}} = () ;
		} elsif ( exists $word_type->{$level} ) {
			$sections->{type}->{$level.$num} = () ;
		} else {
			print STDERR "[[$title]]	Level3 inexistant :\t$level\t$title\n" ;
		}
	} else {
		# This article does not contain any level3 section
		return $sections ;
	}
	
	# continue to retrieve the sections
	while ( $line = shift @$article ) {
		my $num = '' ;
		# Another section?
		if ( $line and ($line =~ /{{-(.+?)-[\|\}]/ or $line =~ /\{\{-(.+?)-\|.+[\|\}]/)) {
			my $templevel = $1 ;
			
			if ( $line =~ /\|num=([0-9]+)[\|\}]/ ) {
				$num = '-'.$1 ;
			}
			if ( exists $level3->{$templevel} ) {
				$level = $templevel ;
				$sections->{$level3->{$level}} = () ;
				next ;
			}
			elsif ( exists $word_type->{$templevel} ) {
				$level = $templevel ;
				$sections->{type}->{$level.$num} = () ;
				next ;
			}
		}
		
		# Continue this language
		if ( exists $level3->{$level} ) {
			push @{$sections->{$level3->{$level}}}, $line ;
		}
		elsif ( exists $word_type->{$level} ) {
			push @{$sections->{type}->{$level.$num}}, $line ;
		}
	}
	
	# Clean up
	if ( $sections->{'etymologie'} and $#{$sections->{'etymologie'}} == 0 and ${$sections->{'etymologie'}}[0] =~ /\{\{ébauche-étym/ ) {
		delete $sections->{'etymologie'} ;
	}
	
	return $sections ;
}

sub printLanguage
{
	my $sections = shift ;
	
	if ( $#{$sections->{'head'}} > -1 ) {
		step( "\n=== HEAD ===" ) ;
		foreach ( @{$sections->{'head'}} ) {
			step( $_ ) ;
		}
	}
	
	if ( $#{$sections->{'etymologie'}} > -1 ) {
		step( "\n=== ÉTYMOLOGIE ===" ) ;
		foreach ( @{$sections->{'etymologie'}} ) {
			step( $_ ) ;
		}
	}
	
	# TYPES
	foreach my $type ( sort keys %{$sections->{'type'}} ) {
	step( "\n=== TYPE: $type ===" ) ;
		if ( ref($sections->{'type'}->{$type}) eq 'ARRAY' ) {
			foreach ( @{$sections->{'type'}->{$type}} ) {
				step( $_ ) ;
			}
		} elsif ( ref($sections->{'type'}->{$type}) eq 'HASH' ) {
			printType( $sections->{'type'}->{$type} ) ;
		}
	}
	
	if ( $#{$sections->{'prononciation'}} > -1 ) {
		step( "\n=== PRONONCIATION ===" ) ;
		foreach ( @{$sections->{'prononciation'}} ) {
			step( $_ ) ;
		}
	}
	
	if ( $#{$sections->{'voir'}} > -1 ) {
		step( "\n=== VOIR AUSSI ===" ) ;
		foreach ( @{$sections->{'voir'}} ) {
			step( $_ ) ;
		}
	}
	
	if ( $#{$sections->{'references'}} > -1 ) {
		step( "\n=== RÉFÉRENCES ===" ) ;
		foreach ( @{$sections->{'references'}} ) {
			step( $_ ) ;
		}
	}
	
}


sub parseType
{
	my ($article, $title) = @_ ;
	die "Not an array (parseType)\n" if not ref($article) eq 'ARRAY' ;
	die "Empty array (parseType)\n" if $#{$article} == -1 ;
	die "Not a text (parseType)\n" if not ref($title) eq '' ;
	die "No title (parseType)\n" if not $title ;
	
	# Extract the main sections:
	my $sections = {} ;
	$sections->{'head'} = () ;
	
	my $line ;
	
	# HEAD
	while ( $line = shift @$article ) {
		unless ( $line =~ /\{\{-.+?-[\|\}]/ ) {
			push @{$sections->{'head'}}, $line ;
		} else {
			last ;
		}
	}
	
	# OTHER SUB SECTIONS
	my $level = '' ;
	my $num = '' ;
	if ( $line and $line =~ /\{\{-(.+?)-[\|\}]/ ) {
		my $templevel = $1 ;
		if ( exists $level4->{$templevel} ) {
			$level = $templevel ;
			$sections->{$level} = () ;
		} else {
			print "[[$title]]	Level4:\t$templevel\t$title\n" ;
		}
	} else {
		# This article does not contain any level4 section
		return $sections ;
	}
	
	# continue to retrieve the sections
	while ( $line = shift @$article ) {
		
		# Another section?
		if ( $line =~ /{{-(.+?)-[\|\}]/ ) {
			my $templevel = $1 ;
			if ( exists $level4->{$templevel} ) {
				$level = $templevel ;
				$sections->{$level} = () ;
				next ;
			} else {
				print "[[$title]]	Level4\t$templevel\t$title\n" ;
			}
		}
		
		# Continue this language
		if ( exists $level4->{$level} ) {
			push @{$sections->{$level}}, $line ;
		}
	}
	
	return $sections ;
}

sub printType
{
	my $sections = shift ;
	
	# HEAD
	step( "\n---- head ----" ) ;
	foreach ( @{$sections->{head}} ) {
		step( $_ ) ;
	}
	
	# TYPES
	foreach my $sec ( sort keys %$sections ) {
		next if $sec eq 'head' ;
		step( "\n---- $sec ----" ) ;
			foreach ( @{$sections->{$sec}} ) {
				step( $_ ) ;
			}
	}
}

sub is_gentile
{
	my ($lines) = @_ ;
	my $gent = 0 ;
	
	foreach my $line (@$lines) {
		if ($line =~ /\{\{note-gentilé/ or $line =~ /# ?\[?\[?Habitant\]?\]? (de|du|d'|d’)/ or $line =~ /# Relatif (à|au) .+?, (commune|ville|village|région|pays|continent)/ or $line =~ /# (Relatif à la|Relatif au|Qui concerne) [A-ZÉÈ].+? ses habitants/) {
			$gent = 1 ;
			last ;
		}
	}
	
	return $gent ;
}

1 ;


__END__

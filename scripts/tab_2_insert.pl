#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Std;

our %opt;
my %tables = (
	'articles'	=> "titre,r_titre,titre_plat,r_titre_plat,transcrit_plat,r_transcrit_plat,anagramme_id",
	'mots'		=> "titre,langue,type,pron,pron_simple,r_pron_simple,num,flex,loc,gent,rand",
	'langues'	=> "langue,num,num_min",
);
my @tables_names = keys(%tables);

#################################################
# Message about this program and how to use it
sub usage
{
        print STDERR "[ $_[0] ]\n" if $_[0] ;
        print STDERR << "EOF";

        This script converts a tabulated anagrimes list into an sql insert command list.

        usage: $0 [-h] -t tablename

        -h        : this (help) message

        -t <str>  : registered table name (to get the fields names)

        tables available: @tables_names
EOF
        exit ;
}

##################################
# Command line options processing
sub init()
{
        getopts('ht:', \%opt) or usage();
        usage() if $opt{h};

        usage("Table needed (-t)") unless $opt{t};
}

###################################
# MAIN
init();

my $tabletype = $opt{t};
$tabletype =~ s/_.+$//g;
print STDERR "Convert for $opt{t} (type $tabletype)\n";

my $fields_list = $tables{ $tabletype };
my $nfields = split(/,/, $fields_list);
my $n = 0;
while(<>) {
	chomp;
	my $values_list = $_;
	my $nvalues = split(/","/);
	if ($nvalues != $nfields) {
		die "$nvalues != $nfields: $values_list | $fields_list\n";
	}
	$n++;
	print "INSERT INTO $opt{t} ($fields_list) VALUES ($values_list);\n";
}
print STDERR "$n lines converted\n";

__END__

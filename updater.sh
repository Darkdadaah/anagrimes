#! /bin/sh
#$ -S /bin/sh
#$ -N anagrimes
#$ -m e
#$ -e $HOME/logs/table_extractor/update_db.e
#$ -o $HOME/logs/table_extractor/update_db.o
#$ -V
#$ -l sqlprocs-s1=1
#$ -v LANG=fr_FR.UTF-8

PERL5LIB=$PERL5LIB:$HOME/bin/lib
PERL5LIB=$PERL5LIB:$HOME/scripts/anagrimes
export PERL5LIB

date=`date +%F`
export date

if [ -z $date ] ; then
        echo "No date"
	exit
fi
if [ -z $1 ] ; then
        echo "No input file"
	exit
fi

# Reinit logs
echo '' > $HOME/logs/table_extractor/update_db.e
echo '' > $HOME/logs/table_extractor/update_db.o

# Create the files
cd $HOME/scripts/anagrimes/scripts
/usr/bin/perl $HOME/scripts/anagrimes/scripts/table_extractor.pl -i $HOME/data/dump/$1 -o $HOME/data/tables/fr-wikt_current -l $HOME/logs/table_extractor/log_
7z a $HOME/data/tables/fr-wikt_$date.7z $HOME/data/tables/fr-wikt_*.csv

# Update the database
sql u_darkdadaah < $HOME/scripts/anagrimes/updater.sql

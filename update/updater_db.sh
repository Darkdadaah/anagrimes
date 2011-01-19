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

# Reinit logs
echo '' > $HOME/logs/table_extractor/update_db.e
echo '' > $HOME/logs/table_extractor/update_db.o

# Update the database
sql u_darkdadaah < $HOME/scripts/anagrimes/update/updater.sql

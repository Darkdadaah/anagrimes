#! /bin/sh
#$ -S /bin/sh
#$ -N diff_wikt
#$ -m e
#$ -e $HOME/logs/diff/diff.e
#$ -o $HOME/logs/diff/diff.o
#$ -V

PERL5LIB=$PERL5LIB:$HOME/bin/lib
export PERL5LIB

date=`date +%F`
export date

if [ -z $date ] ; then
        echo "No date"
	exit
fi

# Reinit logs
echo '' > $HOME/logs/diff/diff.e
echo '' > $HOME/logs/diff/diff.o

cd $HOME/scripts/anagrimes/scripts
frfile=$HOME/data/dump/frwiktionary-20100330-pages-articles.xml
enfile=$HOME/data/dump/enwiktionary-20100403-pages-articles.xml
$HOME/scripts/anagrimes/scripts/diff.pl -i $frfile -I $enfile -l fr -L en -c en -o $HOME/data/listes/en_in_fr.txt

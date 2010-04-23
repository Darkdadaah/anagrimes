#!/usr/bin/perl -w

use Digest::MD5;

my $racine = 'http://download.wikimedia.org' ;
my $langue = 'fr' ;
my $projet = 'wiktionary' ; 

sub check_sum($$)
{
	my ($file, $sum) = @_ ;
	open(FILE, $file) or die("Impossible d'ouvrir '$file': $!") ;
	binmode(FILE) ;
	my $fichiersum = Digest::MD5->new->addfile(*FILE)->hexdigest ;
	close(FILE) ;
	
	if ($fichiersum ne $sum) {
		return "$fichiersum\n$sum\n" ;
	} else {
		return 0 ;
	}
}

chdir('/home/darkdadaah/data/dump/') or die() ;

# 1) Vérifie si une dernière version du dump est dispo
my $release = 'release.txt' ;
{
my $url = "$racine/$langue$projet" ;
`wget -O $release $url` ;
}

# 2) Vérification de la dernière version connue
open(T, $release) or die("$!") ;
$date = 0 ;
while(<T>) {
	if (/href="([0-9]{8})\/"/) {
		$date = $1 ;
	}
}
close(T) ;

# 3) Compare avec la dernière version téléchargée
open(T, 'last.txt') or die("$!") ;
my $old = 0 ;
chomp($old = <T>) ;
$old =~ s/[^0-9]+//g ;
close(T) ;

# 4) Compare
if ($date ~~ $old) {
	print STDERR "Pas de nouvelle version ($date)\n" ;
	exit 0 ;
} else {
	print STDERR "Nouvelle version ! ($date > $old)\n" ;
}

# 5) Récupère le dernier dump
my $fichierbz = "$langue$projet-$date-pages-articles.xml.bz2" ;
my $url = "$racine/$langue$projet/$date/$fichierbz" ;

# D'abord récupère la somme de contrôle MD5
my $md5url = "$racine/$langue$projet/$date/$langue$projet-$date-md5sums.txt" ;
my $fichiermd5 = 'md5.txt' ;
print STDERR "Téléchargement de la somme de contrôle ($fichiermd5)...\n" ;
`wget -O $fichiermd5 $md5url` ;

if (not -e $fichiermd5) {
        print STDERR "Pas de somme de contrôle téléchargée (le fichier n'est peut-être pas encore disponible...)\n" ;
        exit ;
}

open(MD5, $fichiermd5) or die("Impossible d'ouvrir $fichiermd5 : $!") ;
my $md5sum = '' ;
while(<MD5>) {
	if (/^([a-z0-9]+)\s+$fichierbz$/) {
		$md5sum = $1 ;
		last ;
	}
}
close(MD5) ;

if (not $md5sum) {
	print STDERR "Pas de somme de contrôle trouvée dans le fichier (le dump n'est peut-être pas encore disponible...)\n" ;
        exit ;
}

# Téléchargement du fichier si il est bien complet
print STDERR "Téléchargement de $fichierbz...\n" ;
`wget -O $fichierbz $url` ;

if (not -e $fichierbz) {
	print STDERR "Pas de dump téléchargé (le dump n'est peut-être pas encore disponible...)\n" ;
	exit ;
}

# Contrôle
my $status = check_sum($fichierbz, $md5sum) ;
if ($status) {
        print STDERR "Somme de contrôle incorrecte :\n$status\n" ;
        exit ;
}

# 6) Décompresse
print STDERR "Décompression de $fichierbz...\n" ;
`bzip2 -dv $fichierbz` ;
my $fichier = $fichierbz ;
$fichier =~ s/\.bz2// ;

# 7) Enlève la dernière version des listes de mots
`mv /home/darkdadaah/data/tables/*.csv /home/darkdadaah/tmp/trash/` ;

# 8) Lance la création des fichiers
print STDERR "Extraction des données et mise à jour de la base\n" ;
`qsub -sync yes -cwd /home/darkdadaah/scripts/anagrimes/updater.sh $fichier` ;

# 9) Update the "last updated" in the html files


# 10) Recompresse le dump
`bzip2 $fichier` ;

# FIN Change la version
open(T, ">last.txt") or die("$!") ;
print T $date ;
close(T) ;
print STDERR "Version mise à jour\n" ;

exit 0 ;

#!/usr/bin/perl -w

use Digest::MD5;

my $optlangue = $ARGV[0] ;
my $download = 1 ;
my $updateserver = 1 ;

my @langues = qw(fr en it de es) ;
my $langue = 'fr' ;
my $racine = 'http://download.wikimedia.org' ;
my $toolserver = 'willow.toolserver.org' ;
my $projet = 'wiktionary' ;
my $log = "$langue$projet"."_log.txt" ;
my $datadir = "$ENV{HOME}/Documents/Travaux/wiktio/data" ;
my $logdir =  "$ENV{HOME}/Documents/Travaux/wiktio/log" ;
my $workdir = "$ENV{HOME}/Documents/Travaux/wiktio/scripts/anagrimes/scripts" ;
my $tabledir = 'tables';
my $outputs = 'fr-wikt_'.$ENV{date} ;
my $output7z = "$outputs.7z" ;

if ($optlangue) {
	if ($optlangue ~~ @langues) {
		$langue = $optlangue ;
	} else {
		die("Unknown language: $optlangue\n") ;
	}
}

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

chdir($datadir) or die("No $datadir") ;
`echo '' > $log` ;

# 1) Vérifie si une dernière version du dump est dispo
my $release = "$langue$projet"."_release.txt" ;
{
print STDERR "Vérification de la dernière version...\n" ;
my $url = "$racine/$langue$projet" ;
`wget -O $release $url 2>> $log` ;
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
my $last_file = "$langue$projet"."_last.txt" ;

if (-s $last_file) {
	open(T, $last_file) or die("$last_file: $!") ;
	chomp($old = <T>) ;
	close(T) ;
} else {
	$old = 'new' ;
}

# 4) Compare
if ($date ~~ $old) {
	print STDERR "Pas de nouvelle version ($date)\n" ;
	exit 0 ;
} elsif (not $date) {
	print STDERR "Impossible de trouver la dernière version. Le serveur est peut-être KO\n" ;
	print STDERR "Vérifier : http://download.wikimedia.org/frwiktionary/\n" ;
	exit 0 ;
} else {
	print STDERR "Nouvelle version ! ($date > $old)\n" ;
	system("mkdir -p $logdir/$date") ;
}

# 5) Récupère le dernier dump
my $fichierbz = "$langue$projet-$date-pages-articles.xml.bz2" ;
my $url = "$racine/$langue$projet/$date/$fichierbz" ;
my $md5url = "$racine/$langue$projet/$date/$langue$projet-$date-md5sums.txt" ;
my $fichiermd5 = "$langue$projet"."_md5.txt" ;

if ($download) {
	# D'abord récupère la somme de contrôle MD5
	print STDERR "Téléchargement des sommes de contrôle ($fichiermd5)...\n" ;
	`wget -O $fichiermd5 $md5url 2>> $log` ;

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
		print STDERR "Pas de somme de contrôle trouvée pour le dernier dump (le dump n'est peut-être pas encore disponible...)\n" ;
			exit ;
	}

	# Téléchargement du fichier si il est bien complet
		print STDERR "Téléchargement de $fichierbz...\n" ;
		system("wget -O $fichierbz $url") ;

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
	system("bzip2 -dv $fichierbz") ;
}
my $fichier = $fichierbz ;
$fichier =~ s/\.bz2// ;

# 7) Extraction des tables de données
print STDERR "Extraction des données\n" ;

chdir($workdir) ;
`dico-table.pl -i $datadir/$fichier -o $datadir/$tabledir/$outputs -l $logdir/$date/log_$date` ;
chdir($datadir) ;

# 8) Archivage 7z
print STDERR "\nArchivage 7z\n" ;
 print STDERR "7z a $tabledir/$output7z $tabledir/$outputs*.csv\n" ;
 `7z a $tabledir/$output7z $tabledir/$outputs*.csv` ;

exit(0) if not $updateserver ;

############################################################################################
# TOOLSERVER
my $datadir_t = 'data/tables' ;

# 9) Copy data to toolserver
print STDERR "Copie archive serveur\n" ;
system("scp $datadir/$tabledir/$output7z darkdadaah\@$toolserver:$datadir_t") and die() ;

# 10) clean toolserver before update
print STDERR "Décompression archive serveur\n" ;
system("ssh darkdadaah\@$toolserver bash -c \"pwd ; rm -f -v ".$datadir_t."/*.csv\"") and die() ;
system("ssh darkdadaah\@$toolserver bash -c \"pwd ; 7z e -o$datadir_t $datadir_t/$output7z\"") and die() ;
system("ssh darkdadaah\@$toolserver bash -c \"pwd ; cd $datadir_t && pwd && /home/darkdadaah/bin/rename s/_.+_/_current_/ *.csv\"") and die() ;

# 11) Update toolserver databases
print STDERR "Mise à jour base de données du serveur\n" ;
system("ssh darkdadaah\@$toolserver bash -c \"scripts/update_anagrimes/update_db.sh\"") ;

sleep 1000 ;

############################################################################################
# 12) Update lists
system("ssh darkdadaah\@$toolserver bash -c \"source /sge62/default/common/settings.sh ; qsub scripts/journaux/extrait_mots.qsub\"") ;

# FIN Change la version
open(T, ">$last_file") or die("$!") ;
print T $date ;
close(T) ;
print STDERR "Version mise à jour\n" ;

# Cleaning
`rm -f $release $fichiermd5 $log` ;


exit 0 ;


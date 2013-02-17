#!/usr/bin/perl -w

use LWP::Simple;	# get

my $language = 'fr';
my $project = 'wiktionary';
my $root='http://download.wikimedia.org';
my $dump_root = "/mnt/user-store/dumps/store";
my $dump_dir = "$dump_root/$language$project";
my $tables_dir = "/mnt/user-store/anagrimes/tables";
my $logs_dir = "/mnt/user-store/anagrimes/logs";
my $scripts_dir = "$ENV{HOME}/scripts/anagrimes/scripts";
my $dico_tables_script = "$scripts_dir/dico-table.pl";
my $sql_update = "$scripts_dir/anagrimes_updater_import.sql";
my $db = 'u_darkdadaah';
my @dico_tables = qw(articles mots langues redirects);

#####################################################
sub get_dump($$)
{
	my ($language, $project) = @_;
	my $dump = '';
	
	print STDERR "Check latest release";
	
	# Check latest release: get latest date
	my $url = "$root/$language$project";
	my $url_handle = get $url;
	open(RELEASE, '<', \$url_handle) or die("Couldn't open $url_handle: $!");
    my $date = 0 ;
    while(<RELEASE>) {
		if (/href="([0-9]{8})\/"/) {
			$date = $1 ;
		}
	}
	
	print STDERR "Latest release date was: $date\n";
	
	# Check if a file already exists
	my $latest_file = "$dump_dir/$language$project-$date-pages-meta-current.xml";
	if (-s $latest_file) {
		print STDERR "Using latest release file available: $latest_file\n";
		return ($latest_file, $date);
	} else {
		die("The latest release is not available, please download: $latest_file\n");
	}
}

sub create_table_files($$)
{
	my ($dump, $date) = @_;
	
	print STDERR "Create anagrimes tables\n";
	my $tables = "$tables_dir/$date";
	my $logs = "$logs_dir/$date";
	`$dico_tables_script -i $dump -o $tables -l $logs`;
	
	# Change current tables releases
	foreach my $t (@dico_tables) {
		my $new = $date.'_'.$t.'.csv';
		my $cur = $tables_dir.'/current_'.$t.'.csv';
		`ln -sf $new $cur`;
	}
	return $tables;
}

sub import_tables($$$)
{
	my ($tables, $date, $db) = @_;
	
	`sql $db < $sql_update`;
}

sub archive_tables($)
{
	my ($tables, $date) = @_;
	
	# Change current tables releases
	foreach my $t (@dico_tables) {
		my $new = $tables.'_'.$t.'.csv';
		push @to_archive, $new;
	}
	my $files_to_archive = join(' ', @to_archive);
	`7zip a $date.7z $files_to_archive`;
}

#####################################################
# MAIN

# 1) Check latest file (download if needed)
my ($dump, $date) = get_dump($language, $project);

# 2) Read this file and create tables with anagrimes
my $tables = create_table_files($dump, $date);

# 3) Import the new tables in the database
import_tables($tables, $date, $db);

# 4) archive files
#archive_tables($tables, $date);

# 5) Update various lists
#`source /sge62/default/common/settings.sh`;
`$ENV{HOME}/scripts/journaux/extrait_mots.qsub`;

__END__

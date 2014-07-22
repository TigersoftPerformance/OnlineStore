#!/usr/bin/perl -w

use strict;
use DBI;
use LWP::Simple;
use WWW::Mechanize::Firefox;

my $mech = WWW::Mechanize::Firefox->new();

my ($marca,$make,$modid,$model);
my $content;
my $url = 'http://au.bmcairfilters.com';
use constant LOG => "./scrape_mods_log";

open (my $logfh, ">", LOG) or die "cannot open " . LOG; 

#
# Connect to database
# mysql_enable_utf8 enables to store data as UT8
# we also need to ensure that our DB or DB tables 
# are configured to use UTF8
my $driver = "mysql";   # Database driver type
my $my_cnf = '~/.my.cnf';
my $dsn = "DBI:$driver:;" . "mysql_read_default_file=$my_cnf";
my $dbh = DBI->connect($dsn, undef, undef,
	{
	RaiseError => 1, PrintError => 1, mysql_enable_utf8 => 1
	}
) or die $DBI::errstr;

#
# load BMCmod
#
my $loadmodth = $dbh->prepare("
	SELECT * FROM BMCmods where modid =?
") or die $dbh->errstr;

#
# update BMCmod
#
my $updmodth = $dbh->prepare("
	UPDATE BMCmods 
	 SET make = ?, marca = ?, model = ?
	 WHERE modid = ?
") or die $dbh->errstr;

#
# Insert a new row into BMCmod
#
my $insbmcmodth = $dbh->prepare("
	INSERT into BMCmods (make,marca,model,modid) VALUES (?,?,?,?)
") or die $dbh->errstr;


my $retries = 5;
# Try a few times in case of failure
while ($retries && !($content = get $url))
	{
	$retries --;
	}
die "Couldn't get $url" if (!$retries);

#
# collecting marca for all makes
#
$content =~ /<option value="0">(.*?)<\/select>/s;
my $part = $1;

#
# looping through each marcas
#
while ($part =~ /<option value="(\d+)">(.*?)<\/option>/gi)
	{
	$marca = $1;
	$make  = $2;	
	printf "%-20s %s", "marca: $make", " => $marca\n";
	printf $logfh "%-20s %s", "marca: $make", " => $marca\n";

	#
	# here we scrape marca site
	#
	my $marca_url = 'http://au.bmcairfilters.com/search_a.aspx?marca=' . $marca . '&lng=2';
	$retries = 5;
	# Try a few times in case of failure
	while ($retries && !($mech->get($marca_url)))
		{
		$retries --;
		}
	die "Couldn't get $marca_url" if (!$retries);	

	#
	# get marcas content to get modids
	#
	my $marca_content = $mech->content();

	$marca_content =~ /id="ComboModelli" name="ComboModelli"><(.*?)<\/select>/s;
	my $part2 = $1;

	#
	# looping through mods
	#
	while ($part2 =~ /<option value="(\d+)">(.*?)\s*<\/option>/gi)
		{
		$modid = $1;
		$model = $2;	
		&do_db($make,$marca,$model,$modid);
		}
	}
print "\n\t##############################";
print "\n\t####        Done !        ####";
print "\n\t##############################\n\n";

close $logfh;

sub do_db
###################################
# Updates data if needed in BMCmods
# Inserts new row if new in BMCmods
################################### 
{
	my ($maketh,$marcath,$modelth,$modth) = @_;	
	my $need_update = 0;
	my $row;

	$loadmodth->execute($modth) or die $dbh->errstr;

	if ($row = $loadmodth->fetchrow_hashref)
		{
		if ($row->{make} ne $maketh)
			{
			$need_update++;	
			print "Make is different $maketh: $row->{make}\n";	
			print $logfh "Make is different $maketh: $row->{make}\n";	
			}	
		if ($row->{marca} != $marcath)
			{
			$need_update++;	
			print "Marca is different $marcath: $row->{marca}\n";	
			print $logfh "Marca is different $marcath: $row->{marca}\n";	
			}
		if ($row->{model} ne $modelth)
			{
			$need_update++;	
			print "Model is different $modelth: $row->{model}\n";	
			print $logfh "Model is different $modelth: $row->{model}\n";	
			}	
		}
	else
		{
		$insbmcmodth->execute($maketh,$marcath,$modelth,$modth) or die $dbh->errstr;
		print "\tNew mod added: $modth\n";	
		print $logfh "\tNew mod added: $modth\n";	
		}	
	if ($need_update>0)
		{
		$updmodth->execute($maketh,$marcath,$modelth,$modth) or die $dbh->errstr;
		print "\tThis $modth needs $need_update update!\n";	
		print $logfh "\tThis $modth needs $need_update update!\n";	
		}	
}











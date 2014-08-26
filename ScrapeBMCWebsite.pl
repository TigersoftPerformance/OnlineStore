#!/usr/bin/perl -w
#####################################################################################
# Scrape BMC Website script
# First of all, it scrapes all of the Cars that it can find from the website
# And then scrapes all of the products and category information
# There are 3 tables used in the database:
# BMCCars holds all of the information about the cars described on the BMC Website
# BMCProducts holds all of the information about the products listed
# BMCFitment holds the relationships between Cars and Products.
####################################################################################
use strict;
use DBI;
use LWP::Simple;
use feature 'say';
use WWW::Mechanize::Firefox;
use Text::Unidecode;
use utf8;
use English;


my $url = 'http://au.bmcairfilters.com';
use constant LOG => "./Logs/ScrapeBMCWebsite.log";
open (my $logfh, ">", LOG) or die "cannot open " . LOG; 

#
# Connect to database
# mysql_enable_utf8 enables to store data as UT8
# we also need to ensure that our DB or DB tables 
# are configured to use UTF8
my $driver = "mysql";   # Database driver type
my $my_cnf = '~/.my.cnf';
my $dsn = "DBI:$driver:;" . "mysql_read_default_file=$my_cnf" . ";mysql_read_default_group=TigersoftPerformance";
my $dbh = DBI->connect($dsn, undef, undef,
	{
	RaiseError => 1, PrintError => 1, mysql_enable_utf8 => 1
	}
) or die $DBI::errstr;


#######################################################################
# Code starts here
#######################################################################

my $mech = WWW::Mechanize::Firefox->new();
my ($makeid,$make,$modelid, $model);
my $content;


# This will get the front page of the website
# Try a few times in case of failure
my $retries = 5;
while ($retries && !($content = get $url))
	{
	$retries --;
	}
die "Couldn't get $url" if (!$retries);

#
# collecting makeid for all makes
#
$content =~ /<option value="0">(.*?)<\/select>/s;
my $temp1 = $1;

#
# looping through each makeids
#
while ($temp1 =~ /<option value="(\d+)">(.*?)<\/option>/gi)
	{
	$makeid = $1;
	$make  = $2;	
	say "makeid: $make", " => $makeid";
	printf $logfh "%-20s %s", "makeid: $make", " => $makeid\n";

	#
	# This is where we get the content from the wesbite for the specific make
	#
	my $make_url = 'http://au.bmcairfilters.com/search_a.aspx?marca=' . $makeid . '&lng=2';
	# Try a few times in case of failure
	$retries = 5;
	while ($retries && !($mech->get($make_url, no_cache=>1)))
		{
		$retries --;
		}
	die "Couldn't get $make_url" if (!$retries);	

	#
	# get makeids content to get modids
	#
	#sleep (1);
	my $makeid_content = $mech->content();
	$makeid_content =~ /id="ComboModelli" name="ComboModelli"><(.*?)<\/select>/s;
	my $temp2 = $1;

	#
	# Now loop through the page looking for all of the models listed for this make
	# Note that the list on the website is populated via some ajax calls, which is why
	# Dave used Firefox::Mechanize
	#
	while ($temp2 =~ /<option value="(\d+)">(.*?)\s*<\/option>/gi)
		{
		$modelid = $1;
		$model = $2;
		say " >modelid: $model", " => $modelid";
		
		my $model_url = 'http://au.bmcairfilters.com/search_a.aspx?marca=' . $makeid . '&mod=' . $modelid . '&lng=2';
		# Try a few times in case of failure
		$retries = 5;
		while ($retries && !($mech->get($model_url, no_cache=>1)))
			{
			$retries --;
			}
		die "Couldn't get $model_url" if (!$retries);	
		
		#
		# Now go and get the page for the specified model
		#
		my $modelid_content = $mech->content();

		$modelid_content =~ /<div id="risultati">/s;
		while ($modelid_content =~ /<strong>(.+)<\/strong>/gi)
			{
			my $category = $1;
			say $category;
			}
		my $table_cols = qr/<th scope="col">Model<\/th>\s*<th scope="col">HP<\/th>\s*<th scope="col">Year<\/th>\s*<th scope="col">ID\/Chassis<\/th>\s*<th scope="col">Engine Code<\/th>\s*<th scope="col">Shape<\/th>\s*<th scope="col">Code<\/th>/;
		if ($modelid_content !~ /$table_cols/)
			{
			say "Can't find correct columns!";
			}
		}
	}


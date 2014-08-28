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

		# Scan the page for tables of variants of the specified model 
		# There will be one table per BMC product. 
		# The table will have the product type (eg CAR FILTERS, or CDA - CARBON DYNAMIC AIRBOX)
		# within <strong> tags and then the table will follow
		while ($modelid_content =~ /<strong>(.*?)<\/strong>.*?<table class="gradient-style2"(.*?)<\/table>/sg)
			{
			my $product_type = $1, my $model_table = $2;
			say "  >Found table for $product_type";
			
			# so now we have just the structure of one table with its product type, 
			# so we can parse the table header to see what columns we are dealing with.
			# Need to come up with a strategy for dealing with these better than just counting them
			my $table_header = $1 if $model_table =~ /<thead>(.*?)<\/thead/sg;
			last if (!defined $table_header);
			my @column_names = ();
			while ($table_header =~ /<th scope="col">(.*?)<\/th>/sg)
				{
				push (@column_names, $1);
				#say "   >Found Column Name " . $column_names[scalar (@column_names) - 1];
				}
			

			# Now we have to read each row of data from the table
			# first thing is to isolate just the table data
			my $table_data = $1 if $model_table =~ /<tbody>(.*?)<\/tbody/sg;
			last if (!defined $table_data);
			my @column_values = ();
			# Now loop through each row in the table. There is one row per variant
			while ($table_data =~ /<tr>(.*?)<\/tr>/sg)
				{
				my $table_row = $1;
				@column_values = ();
				#print "   >Found Row ";
				while ($table_row =~ /<td.*?>(.*?)<\/td>/sg)
					{
					push (@column_values, $1);
					#print ":" . $column_values [scalar (@column_values) - 1];
					}
				#say ":\n\n";
				&add_new_variant ($product_type, \@column_names, \@column_values);
				}
			}
		}
	}

sub add_new_variant
	{
	my $product_type = $_[0];
	my @column_names = @{$_[1]};
	my @column_values = @{$_[2]};

	# Column Names for CAR FILTERS are:
	# Model, HP, Year, ID/Chassis, Engine Code, Shape, Code
	# So 7 columns in total
	if ($product_type eq "CAR FILTERS")
		{
		if (scalar (@column_names) != 7 || scalar (@column_values) != 7)
			{
			&wrong_columns ($product_type, \@column_names, \@column_values);
			return -1;
			}
		return 0;
		}
		
	# Column Names for CDA - CARBON DYNAMIC AIRBOX are:
	# Model, Mounting Note, Components List
	# So 3 columns in total
	if ($product_type eq "CDA - CARBON DYNAMIC AIRBOX")
		{
		if (scalar (@column_names) != 3 || scalar (@column_values) != 3)
			{
			&wrong_columns ($product_type, \@column_names, \@column_values);
			return -1;
			}
		return 0;
		}

	# Column Names for OTA - OVAL TRUMPET AIRBOX are:
	# Model, HP, Year, ID/Chassis, Engine Code, Shape, Code
	# So 7 columns in total
	if ($product_type eq "OTA - OVAL TRUMPET AIRBOX")
		{
		if (scalar (@column_names) != 7 || scalar (@column_values) != 7)
			{
			&wrong_columns ($product_type, \@column_names, \@column_values);
			return -1;
			}
		return 0;
		}

	say "ERROR! Unknown Product Type!";
	say "$product_type";
	say "---------------------------------";
	say "@column_names\n";
	say "---------------------------------";
	say "@column_values\n";
	say "---------------------------------";
	return -1;
	}
	
sub wrong_columns
	{
	my $product_type = $_[0];
	my @column_names = @{$_[1]};
	my @column_values = @{$_[2]};
	
	say "ERROR! Mismatch of Columns!";
	say "$product_type";
	say "---------------------------------";
	say "@column_names\n";
	say "---------------------------------";
	say "@column_values\n";
	say "---------------------------------";
	return -1;
	}
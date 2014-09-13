#!/usr/bin/perl -w
#####################################################################################
# Scrpe BMC Categories script - Dave M, July 2014
# Updated and modified by John Robinson, August 2014
####################################################################################
use strict;
use DBI;
use LWP::Simple;
use feature 'say';
use Text::Unidecode;
use utf8;
use English;
use Encode;
use IO::Handle;


my $content;
my $url = 'http://au.bmcairfilters.com';
use constant LOG => "./Logs/ScrapeBMCCategories.log";
open (my $logfh, ">", LOG) or die "cannot open LOG $!"; 
$logfh->autoflush;

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

#
# This selects a row based on part from BMCAirProducts
#
my $existsbmcairth = $dbh->prepare("
	SELECT * FROM BMCProducts WHERE bmc_part_id = ?
") or die $dbh->errstr;

#
# Insert a new row into BMCProducts
#
my $insbmcairth = $dbh->prepare("
	INSERT into BMCProducts (type, bmc_part_id, product_url, active) VALUES (?,?,?,?)
") or die $dbh->errstr;


#
# This select is only used to see if Category exists or not
#
my $existsbmccatth = $dbh->prepare("
	SELECT * FROM Categories WHERE shortname = ?
") or die $dbh->errstr;

#
# Update existing row in Categories
#
my $updbmccatth = $dbh->prepare("
	UPDATE Categories SET longname = ?, image = ?, description = ? WHERE shortname = ?
") or die $dbh->errstr;



######################################################################################
# Code starts here
######################################################################################

# Read the main page of the website. Try a few times in case of failure
my $retries = 5;
# Try a few times in case of failure
while ($retries && !($content = get $url))
	{
	$retries --;
	}
die "Couldn't get $url" if (!$retries);
$content = decode_utf8 ($content);
$content =~ s/,/&#44;/g;

my $top_cat = "BMC";
my ($curr_url,$abs_url,$cat_name,$cat_container);


# Look for main categories
while ($content =~ /<li\s+class=\"bar.*?>(.*?)<\/li>/gi)
	{
	$cat_container = $1;

	# Find the names and links of the categories
	if ($cat_container =~/<a href=\"(.*?)\">(.*?)<\/a>/)
		{
		$curr_url = $1;
		$cat_name = $2;
		# I have no idea what this is doing, top cat should be equal to "BMC"!
		$top_cat =~ s/(.*)(\^.*?)$/$1/g if $cat_name=~/(WASHING KITS|MERCHANDISING)/i;
		$top_cat .= "^$cat_name";				
		}
	else
		{
		$top_cat = "BMC";	
		if ($cat_container =~/REPLACEMENT FILTERS/i)
			{
			$top_cat .=	"^REPLACEMENT FILTERS";	
			next;
			}
		elsif ($cat_container=~/AIR INTAKE SYSTEMS/i)	
			{
			$top_cat .=	"^AIR INTAKE SYSTEMS";

			# For air intake category
			parse_categories('http://au.bmcairfilters.com/air-intake-systems_pag_ib3_2.aspx',$top_cat);
			next;
			}	
		}	
	# Absolute link of the current category	
	$abs_url = $url . $curr_url;	

	# Go deep into the current category tree
	# and look for sub categories and products
	parse_categories($abs_url,$top_cat);
	
	$top_cat =~ s/(.*)(\^.*?)$/$1/g;
	}


close $logfh;


##############################################
############  End of main program  ###########
##############################################


sub parse_categories 
#####################################
#
# Sub o_categorization
# Arg1 = Category url
# Arg2 = Category
#
#####################################
{
	my ($c_url,$c_name) = @_;
	my ($c_cont,$c_list,$c_plist);

	  
	$retries = 5;
	# Try a few times in case of failure
	while ($retries && !($c_cont = get $c_url))
		{
		$retries --;
		}
	die "Couldn't get $c_url" if (!$retries);
	$c_cont = decode_utf8 ($c_cont);
	$c_cont =~ s/,/&#44;/g;

	if ($c_cont =~ /<div\s*id=\"cont-page\">
				(.*?)
				<div\s*class=\"productbox\"(.*?)<\/div>
			   /xsgi
		  )	
		{

		# Product list container
		$c_plist = $2;

		# Loop through product lists
		while ($c_plist=~/<a href=\"(.*?)\".*?>(.*?)<\/a>/sgi)
			{
			$c_name .= "^" . $2;	

			parse_categories ($url . $1,$c_name);
			$c_name =~ s/(.*)(\^.*?)$/$1/g;
			}

		}
	# Get the div id="cont-page" content
	elsif ($c_cont =~ /<div\s*id=\"cont-page\">
				(.*?)
				<\/div>
				(.*?)<input\s*type=\"hidden\"
			   /xsgi   )	 
		{  

		# This part contains Product lists if any
		$c_list = $2;

		# Looping through Product lists' tables	
		while ($c_list=~/<table summary=\"Products List\"(.*?)<\/table>/sgi)
			{
			# Parse Product lists' tables 
			# and do db things
			parse_product_list($c_name,$1);
			}
		}	
}


sub parse_product_list
#####################################
#
# Sub o_categorization
# Arg1 = Category path
# Arg2 = Html part 
#
#####################################
{
	my ($c_name,$p_list) = @_;
	my ($c_short,$p_desc,$p_image,$p_note,$p_code,$p_url)=('')x6;
	my (@arr,$p_part1);
	my $fl = 0;

	# Category longname
	$c_name =~ /(.*\^)(.*?)$/;
	# Category shortname
	$c_short = $2;

	while ($p_list =~ /<tr>(.*?)<\/tr>/sgi)
		{
		# Table row container	
		$p_part1 = $1;	

		# Check to see table type (2 column/4 column)
		while ($p_part1 =~ /<th.*?>(.*?)<\/th>\s*/sgi) 
			{
			push @arr, $1;
			}

		# Check to see if we have subcategory	
		if (scalar @arr == 4)
			{
			$c_name .= "^" . $arr[0];
			@arr = ();	
			$fl = 1;
			next;
			}
		# Skip to the next rules 
		# when table header 	
		elsif (scalar @arr == 2)
			{
			@arr = ();	
			next;	
			}	
				
		# Parsing data	
		while ($p_part1 =~ /<td.*?
							(valign=\"top\")? 		   # image or note
							>
							(<img.*\/(.*\.jpg))?	   # image
							(<a\s*href=\"(.*?)\".*?>(.*?)<\/a>)? # url, code
							(.*?)
							<\/td>
						   /xsgi
			)
			{
				
			# Main image of the current table	
			$p_image = $3 if $1 && $2;

			# Note of the current table
			$p_note = $6 if $1 && !$2;	

			# Remove <p> tags from Note, we may need that though
			$p_note =~ s/<\/?p>//gi if defined $p_note;

			# BMC product url
			$p_url = $5 if $5;

			# BMC product code
			$p_code = $6 if $6;

			}

			# Add current BMC product code to the 
			# BMCAirProduct table if not exists
			# ScrapeBMCAirProducts.pl should be run after this
			# to scrape data for the BMC product Code
			$existsbmcairth->execute($p_code);
			my $prd_table = $existsbmcairth->fetchrow_hashref;
			unless (defined ($prd_table))
				{
				$insbmcairth->execute($c_short,$p_code,$p_url,"Y"); 
				&screen("\t\tNew Product: $c_short : $p_code");
				}
			else
				{
				&screen("\tProduct $c_short : $p_code");	
				}	
			
		}
}


sub screen
	{
	my $line = shift;
	say $line;
	say $logfh $line;
	}
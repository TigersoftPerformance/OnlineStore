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
# Insert a new row into BMCAirProducts
#
my $insbmcairth = $dbh->prepare("
	INSERT into BMCProducts (category,bmc_part_id,active) VALUES (?,?,?)
") or die $dbh->errstr;

#
# Insert a new row into Categories
#
my $ins_bmccat_sth = $dbh->prepare("
	INSERT INTO Categories (longname, shortname, image, description, active) VALUES (?,?,?,?,?)
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
	UPDATE Categories SET longname = ?, image = ?,
	 description = ?	
		WHERE shortname = ?
") or die $dbh->errstr;

#
# load BMCmod
#
# my $loadmodth = $dbh->prepare("
	# SELECT * FROM BMCmods
# ") or die $dbh->errstr;
# $loadmodth->execute();


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
		# $top_cat =~ s/(.*)(\^.*?)$/$1/g if $cat_name=~/(WASHING KITS|MERCHANDISING)/i;
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
			do_categorization('http://au.bmcairfilters.com/air-intake-systems_pag_ib3_2.aspx',$top_cat);
			next;
			}	
		}	
	# Absolute link of the current category	
	$abs_url = $url . $curr_url;	

	# Go deep into the current category tree
	# and look for sub categories and products
	do_categorization($abs_url,$top_cat);
	
	$top_cat =~ s/(.*)(\^.*?)$/$1/g;
	}

########################
#
# Scrape CAR FILTERS 
#
########################

# $url = 'http://au.bmcairfilters.com/ajax/auto.aspx?mod=';
# my ($code,$modid_url,@cf,$selected_div,$first_el);
# my $product_name = 'BMC^REPLACEMENT FILTERS^CAR FILTERS';

# while (my $md = $loadmodth->fetchrow_hashref)
	# {
	# $modid_url = $url . $md->{modid};

	# my $retries = 5;
	# # Try more times in case of failure
	# while ($retries && !($content = get $modid_url))
		# {
		# $retries --;
		# }
	# die "Couldn't get $modid_url" if (!$retries);		
			
	# # If we have Car Filters in this page		
	# if ($content =~ /id="model-table"(.*?)CAR FILTERS(.*?)<\/div>/sgi)
		# {
		# $selected_div = $2;
		# @cf =();
		# while ($selected_div =~/<a href=.*?>\s*(.*?)\s*<\/a>/sgi) 
			# {
			# # Product Code	
			# $code = $1;	
			# $first_el = $cf[0] || "";

			# # Get rid of repeated codes
			# next if $code eq $first_el;	
			# unshift @cf, $code;
			# }

		# # Add Product Codes into BMCAirProduct table	
		# for (@cf)
			# {
			# $existsbmcairth->execute($_);
			# my $prd_table = $existsbmcairth->fetchrow_hashref;
			# unless (defined ($prd_table))
				# {
				# $insbmcairth->execute($product_name,$_,"Y"); 
				# &screen("\t\tNew Product: $product_name : $_");
				# }
			# else
				# {
				# &screen("\t$product_name : $_");	
				# }	

			# }	

		# }
	# else
		# {
		# next;	
		# }	
	
	# }

close $logfh;


##############################################
############  End of main program  ###########
##############################################


sub do_categorization
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
	my ($c_short,$c_desc,$c_image,$c_note) = ('')x4;

	# Category longname
	$c_name =~ /(.*\^)(.*?)$/;

	# Category shortname
	$c_short = $2;
	  
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

		# Description of the Category (with images)
		$c_desc = $1;

		# Product list container
		$c_plist = $2;

		# Semicolon replacement with html entity
		$c_desc =~ s/\;/\&#59;/g;

		# Comma replacement
		$c_desc =~ s/,/\&#44;/g;

		# Add new or Update existing category 
		do_db($c_name,$c_short,$c_desc,$c_image,$c_note);	

		# Loop through product lists
		while ($c_plist=~/<a href=\"(.*?)\".*?>(.*?)<\/a>/sgi)
			{
			$c_name .= "^" . $2;	

			do_categorization($url . $1,$c_name);
			$c_name =~ s/(.*)(\^.*?)$/$1/g;
			}

		}
	# Get the div id="cont-page" content
	elsif ($c_cont =~ /<div\s*id=\"cont-page\">
				(.*?)
				<\/div>
				(.*?)<input\s*type=\"hidden\"
			   /xsgi
	   )	 
		{  

		# Description of the Category (with images)
		$c_desc = $1;

		# This part contains Product lists if any
		$c_list = $2;

		# Semicolon replacement with html entity
		$c_desc =~ s/\;/\&#59;/g;

		# Add new or Update existing category 
		do_db($c_name,$c_short,$c_desc,$c_image,$c_note);

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
	my ($p_name,$p_list) = @_;
	my ($p_short,$p_desc,$p_image,$p_note,$p_code)=('')x5;
	my (@arr,$p_part1);
	my $fl = 0;

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
			$p_name .= "^" . $arr[0];
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
							(<a\s*href.*?>(.*?)<\/a>)? # code
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
			$p_note =~ s/<\/?p>//gi;

			# BMC product code
			$p_code = $5 if $5;

			}

			# Add current BMC product code to the 
			# BMCAirProduct table if not exists
			# ScrapeBMCAirProducts.pl should be run after this
			# to scrape data for the BMC product Code
			$existsbmcairth->execute($p_code);
			my $prd_table = $existsbmcairth->fetchrow_hashref;
			unless (defined ($prd_table))
				{
				$insbmcairth->execute($p_name,$p_code,"Y"); 
				&screen("\t\tNew Product: $p_name : $p_code");
				}
			else
				{
				&screen("\tProduct $p_name : $p_code");	
				}	
			
		}

	$p_name =~ s/(ACCESSORIES)/BMC $1/;

	# Category longname
	$p_name =~ /(.*\^)(.*?)$/;

	# Category shortname
	$p_short = $2;	

	# Add new or Update existing category if subcategory
	do_db($p_name,$p_short,$p_desc,$p_image,$p_note) if $fl;
}


sub do_db
#############################
# Add new or Update existing 
# category in Categories
#############################
{
	my ($name,$short,$desc,$image,$note) = @_;
	$desc ||= $note;
	# Add current Category data to the 
	# Categories table if not exists
	$existsbmccatth->execute($short);
	my $cat_table = $existsbmccatth->fetchrow_hashref;
	unless (defined ($cat_table))
		{	
		$ins_bmccat_sth->execute($name,$short,$image,$desc,"Y"); 
		&screen("\tNew Category : $name");
		}
	# Look for changes if any	
	elsif ( $cat_table->{longname} ne $name ||
			$cat_table->{description} ne $desc ||
			$cat_table->{image} ne $image
	  	  )
		{
		$updbmccatth->execute($short,$image,$desc,$name);
		&screen("Updated category $name");	
		}
	else	
		{
		&screen("Category $name");	
		}
}


sub screen
	{
	my $line = shift;
	say $line;
	say $logfh $line;
	}
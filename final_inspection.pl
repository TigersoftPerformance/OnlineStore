#!/usr/bin/perl -w

use strict;
use DBI;
use LWP::Simple;
use feature 'say';

my $driver = "mysql";   # Database driver type
my $database = "TP";    # Database name
my $user = "root";      # Database user name
my $password = "doover11";      # Database user password

my $content;  # will store content of http://www.finalinspection.com.au/
my $content2; # will store content of http://www.finalinspection.com.au/90mm-medium-cutting-pad-orange-hd
my $url = 'http://www.finalinspection.com.au/';

use constant LOG => "./finalinspection";

# Open log file to log data
open (my $logfh, ">", LOG) or die "cannot open " . LOG; 

#
# Connect to database
# mysql_enable_utf8 enables to store data as UT8
# we also need to ensure that our DB or DB tables 
# are configured to use UTF8
my $dbh = DBI->connect(
"DBI:$driver:$database", $user, $password,
	{
	RaiseError => 1, PrintError => 1, mysql_enable_utf8 => 1
	}
) or die $DBI::errstr;

#
# Load FI items based on category and name
#
my $loadfith = $dbh->prepare("
	SELECT * FROM FI where 
	category =? AND name =?
") or die $dbh->errstr;

#
# Update FI row 
#
my $updfith = $dbh->prepare("
	UPDATE FI SET overview =?,price =?,
	images =?,videos =?,description =? WHERE 
	category =? AND name =? 
") or die $dbh->errstr;

#
# Insert a new row into FI
#
my $insfith = $dbh->prepare("
	INSERT into FI (category,name,overview,price,
	images,videos,description) 
	VALUES (?,?,?,?,?,?,?)
") or die $dbh->errstr;

my $retries = 5;
# Try a few times in case of failure
while ($retries && !($content = get $url ))
	{
	$retries --;
	}
die "Couldn't get $url" if (!$retries);

my ($category,$name,$item_url,$url_cont) = ('')x4;

#
# Extract all categories and urls of all products
# so that we use those urls to exatrct each product's data
#
while ($content =~ /<ul>\s*<li class="finavtitle">(.*?)<\/li>\s*(.*?)<\/ul>/gms)
	{
	$category = $1; # Category name
	$url_cont = $2; # This store a chunk of HTML which will further parsed to get products' urls

	&screen("Category $category");

	#
	# Extract product's actual urls and get data of each products
	#
	while ($url_cont =~/<a href=\"\/(.*?)\">(.*?)<\/a><\/li>/g)
		{
		$item_url = $url . $1; # Forms an absolute link of products like http://www.finalinspection.com.au/90mm-medium-cutting-pad-orange-hd
		$name 	  = $2; # Product's name like '90MM Ø Medium Cutting Pad - Orange (HD)'
		
		$retries = 5;
		# Try a few times in case of failure
		while ($retries && !($content2 = get $item_url ))
			{
			$retries --;
			}
		die "Couldn't get $item_url" if (!$retries);


		my ($images_cont,$overview_price_cont,$desc_cont,$video_cont) = ('')x4;
		my ($images,$overview,$price,$description,$video) = ('')x5;


		$content2 =~ /
					<div\sclass=\"more-views.*?>(.*?)<\/div>\s*<\/div>.*?				   # $1 images container
					<div\sclass=\"white-back\">(.*?)<\/div>\s*<div\sclass=\"product_.*?	   # $2 Overview + Prcie + name container
					<div\sclass=\"product-tabs-content\"\sid=\"
					product_tabs_description_contents\">.*?<div.*?>(.*?)<\/div>.*?		   # $3 Descrption	
					<div\sclass=\"product-tabs-content\"\sid=\"
					product_tabs_additional_contents\">.*?<td\sclass=\"data.*?>(.*?)<\/td> # $4 Video links container
					/xms;

		$images_cont			= $1;
		$overview_price_cont	= $2;
		$desc_cont 				= $3;
		$video_cont				= $4;

		# Collecting all images in the slide part
		# We collect all full sized images here instead of
		# thumbnails, though those are also available to extract
		# if needed
		while ($images_cont =~/href=\"(.*?)\"/g)
			{
			$images .= $1 . "\n";	
			}

		# Collecting all videos
		if ($video_cont =~ /No/i)	
			{
			$video = 'No';	
			}
		else
			{
			while ($video_cont =~ /src=\"\/\/(.*?)\"/g)
				{
				$video .= $1 . "\n";
				}	
			}	

		# Remove new line at the end	
		chomp ($video,$images);

		# Description for the item
		# Description is extracted with their html tags 
		# tags can be removed whenever we want
		$description = $desc_cont;	


		# 'Overview' of the product
		if ($overview_price_cont =~/<div\sclass=\"std\">(.*?)<\/div>/ms)	
			{
			$overview = $1;
			}	

		#
		# In this condition we check to see if the product
		# has a multiple offered options and we take each
		# offer as a separate product	 
		if ($overview_price_cont !~ /product name/i)
			{
			if ($overview_price_cont =~/<span\sclass=\"price\">\$(.*?)<\/span>/)
				{
				$price = $1;

				# do database part
				&do_db($category,$name,$overview,$price,$images,$video,$description);
				}

			}
		else
			{
			while ($overview_price_cont =~ /<td>(.*?)<\/td>\s*<td class=\"a-right\">.*?<span class=\"price\">\$(.*?)<\/span>/gms)	
				{
				$name  = $1;
				$price = $2;

				# do database part
				&do_db($category,$name,$overview,$price,$images,$video,$description);
				}
			}	
		}
		
	}

close $logfh;

sub do_db
######################################
# Updates data if needed in FI
# Inserts new row if new in FI
######################################
{
	my ($cat_c,$name_c,$over_c,$price_c,$img_c,$video_c,$desc_c) = @_;	
	my $need_update = 0;
	my $row;

	$loadfith->execute($cat_c,$name_c) or die $dbh->errstr;

	#
	# If row exists in FI table
	if ($row = $loadfith->fetchrow_hashref)
		{
		#
		# Check to see if price changed
		if ($row->{price} ne $price_c)
			{
			$need_update++;	
			&screen(" Need update for price $cat_c : $name_c ");
			}
		#
		# Check to see if images changed
		if ($row->{images} ne $img_c)
			{
			$need_update++;	
			&screen(" Need update for images $cat_c : $name_c ");
			}
		#	
		# Check to see if videos changed
		if ($row->{videos} ne $video_c)
			{
			$need_update++;	
			&screen(" Need update for videos $cat_c : $name_c ");
			}	
		#	
		# Check to see if description changed
		if ($row->{description} ne $desc_c)
			{
			$need_update++;	
			&screen(" Need update for description $cat_c : $name_c  ");
			}			
		# If nothing is modified then just 
		# log data from FI table	
		else
			{
			&screen("\t$cat_c : $name_c : $price_c  ");
			}		
		}
	# Insert a new row and log data	
	else
		{
		$insfith->execute($cat_c,$name_c,$over_c,$price_c,$img_c,$video_c,$desc_c) or die $dbh->errstr;
		&screen(" New FI item => $cat_c : $name_c : $price_c ");
		}	
	# Update data in FI table if needed	
	if ($need_update>0)
		{
		$updfith->execute($over_c,$price_c,$img_c,$video_c,$desc_c,$cat_c,$name_c) or die $dbh->errstr;
		&screen(" Updated: $cat_c : $name_c");
		}	
}

# This subroutine prints to the screen
# also logs whatever passed to it
sub screen
	{
	my $line = shift;
	say $line;
	say $logfh $line;
	}

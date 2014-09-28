#!/usr/bin/perl
# Format FI Store Descriptions:
# This script reads the descriptions that have been scraped from the FI Store, does some
# Basic conversions on the html/css code, and then writes it to a HTML file that can 
# then be checked for spelling errors etc.
#######################################################

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use LWP::Simple;

use constant LOG => "./Logs/FormatFIStoreDescriptions.log";
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

#
# Update the description in the FIProducts table
#
my $upd_fiproduct_sth = $dbh->prepare("
	UPDATE TP.FIProducts SET description = ? WHERE partid = ?
") or die $dbh->errstr;

#
# Select all rows from FIWebsite
#
my $get_fiwebsite_sth = $dbh->prepare("
	SELECT * FROM TP.FIWebsite
") or die $dbh->errstr;
$get_fiwebsite_sth->execute() or die $dbh->errstr;



my $fiwebsite = {};
while ($fiwebsite = $get_fiwebsite_sth->fetchrow_hashref)
	{
	my $description = '';
	
	# Read the part id from the scraped record from the FI Website and make sure that it is valid
	my $partid = $fiwebsite->{partid};
	say "Part: $partid. $fiwebsite->{name}";

	if (!defined ($partid))
		{
		say "No Part ID for $fiwebsite->{name} in $fiwebsite->{category}";
		next;
		}
		
	# Write some wrappers around the description
	$description = '<div class="infobox_container fiproductdescription"><div class="infobox fullbox">';
	$description .= "<h1>$fiwebsite->{name}</h1><hr />";
		
	# Read the descrption from the FI Website row, and do some processing on it
	my $desc = $fiwebsite->{description};
	
	# Download all images that we can find.
	while ($desc =~ m/src=\"(http:\/\/www.finalinspection.com.au\/media\/wysiwyg\/FIPhotos)\/(.+?\..+?)\"/g)
		{
		my $url = $1 . "/" . $2;
		my $file = "FIPhotos/" . $2;
		say "Downloading $url to $file";
		unless ( -e $file)
			{
			getstore ($url, $file);
			}
		}

	# This changes image paths from those on the FI server to our server
	$desc =~ s/src=\"http:\/\/www.finalinspection.com.au\/media\/wysiwyg\/FIPhotos\/(.+\..+)\"/src="images\/FIStore\/$1"/g;
	
	# This adds the class of rightPhoto or centrePhoto to images
	$desc =~ s/<img/<img class="rightPhoto"/g;
	
	# This deletes the empty emphasised <br /> statements
	$desc =~ s/<p><strong>\s*<br \/>\s*<\/strong><\/p>//g;
	
	# This deletes the empty <p> </p> statements
	$desc =~ s/<p>\&nbsp\;<\/p>//g;
	
	# This changes the many headings to h2
	my $lastpos = pos;
	
	while ($desc =~ m/<p><strong>(.+?)<\/strong><\/p>/g)
		{
		pos $lastpos;
		if (length $1 < 64)
			{
			$desc =~ s/<p><strong>(.+?)<\/strong><\/p>/<\/div><div class="infobox fullbox"><h2>$1<\/h2><hr \/>/
			}
		else
			{
			$desc =~ s/<p><strong>(.+?)<\/strong><\/p>/<p>$1<\/p>/
			}
		my $lastpos = pos;
		}
		
	$desc =~ s/<p><strong>(.+?)<\/strong><\/p>/<\/div><div class="infobox fullbox"><h2>$1<\/h2><hr \/>/g;
	
	# Now write the updated description to the output file
	$description .= $desc;
	
	# Close out the wrappers around the description
	$description .= "</div></div>";
	$upd_fiproduct_sth->execute($description, $fiwebsite->{partid}) or die $dbh->errstr;
	}
exit 0;	
	

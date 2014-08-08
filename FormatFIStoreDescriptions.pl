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

use constant LOG => "./Logs/FormatFIStoreDescriptions.log";
open (my $logfh, ">", LOG) or die "cannot open " . LOG; 

use constant FIDESCDIR => "FIStoreDescriptions";
use constant HTMLBEGIN => "./" . FIDESCDIR . "/StoreTestPageBegin.html";
use constant HTMLEND => "./" . FIDESCDIR . "/StoreTestPageEnd.html";

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
# Select all rows from FIWebsite
#
my $get_fiwebsite_sth = $dbh->prepare("
	SELECT * FROM TP.FIWebsite WHERE partid LIKE 'W%'
") or die $dbh->errstr;
$get_fiwebsite_sth->execute() or die $dbh->errstr;


my $fiwebsite = {};
while ($fiwebsite = $get_fiwebsite_sth->fetchrow_hashref)
	{
	# Read the part id from the scraped record from the FI Website and make sure that it is valid
	my $partid = $fiwebsite->{partid};
	if (!defined ($partid))
		{
		say "No Part ID for $fiwebsite->{name} in $fiwebsite->{category}";
		next;
		}
		
	# If we have a valid partid, then we can open the output file
	my $outfile = "./" . FIDESCDIR . "/StoreTest" . $partid . ".html";
	open (my $outfh, ">", $outfile) or die "cannot open " . $outfile; 
		
	# Now read the beginning part of the Store Test Page, and write it to the output
	open (my $htmlbeginfh, "<", HTMLBEGIN) or die "cannot open " . HTMLBEGIN; 
	while (<$htmlbeginfh>)
		{
		print $outfh "$_\n";
		}
	close ($htmlbeginfh);
	
	# Write some wrappers around the description
	printf $outfh '<div class="tigFIProductDescription">' . "\n";
	print $outfh "<h1>$fiwebsite->{name}</h1>";
		
	# Read the descrption from the FI Website row, and do some processing on it
	my $desc = $fiwebsite->{description};
	
	# This changes image paths from those on the FI server to our server
	$desc =~ s/src=\"http:\/\/www.finalinspection.com.au\/media\/wysiwyg\/FIPhotos\/(.+\..+)\"/src="images\/FIStore\/$1"/g;
	
	# This adds the class of rightPhoto or centrePhoto to images
	$desc =~ s/<img/<img class="rightPhoto"/g;
	
	# This deletes the empty emphasised <br /> statements
	$desc =~ s/<p><strong>\s*<br \/>\s*<\/strong><\/p>//g;
	
	# This deletes the empty <p> </p> statements
	$desc =~ s/<p>\&nbsp\;<\/p>//g;
	
	# This changes the many headings to h2
	$desc =~ s/<p><strong>(.+)<\/strong><\/p>/<h2>$1<\/h2>/g;
	
	# Now write the updated description to the output file
	print $outfh "$desc\n";
	
	# Close out the wrappers around the description
	printf $outfh "</div>\n";
		
	# Now read the End part of the Store Test Page, and write it to the output
	open (my $htmlendfh, "<", HTMLEND) or die "cannot open " . HTMLEND; 
	while (<$htmlendfh>)
		{
		print $outfh "$_\n";
		}
	close ($htmlendfh);
	close ($outfile);
	
	}
exit 0;	
	

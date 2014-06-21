#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';

my $driver = "mysql";   # Database driver type
my $database = "TP";    # Database name
my $user = "root";      # Database user name
my $password = "doover11";      # Database user password


use constant CSV => "./CategoryMeta-EPTigersoft.csv";
open (my $categories, ">", CSV) or die "Cannot open " . CSV;

die "Please pass input CSV file!\n" unless $ARGV[0];
use constant IN_CSV => $ARGV[0];
open (my $input_csv, "<", IN_CSV) or die "Cannot open " . IN_CSV;

$OFS = ',';

#
# Connect to database
#
my $dbh = DBI->connect(
"DBI:$driver:$database", $user, $password,
	{
	RaiseError => 1, PrintError => 1,
	}
) or die $DBI::errstr;

#
# Select a row from Categories based on calculated
#
my $get_cat_sth = $dbh->prepare("
	SELECT * FROM Categories WHERE shortname = ? AND Active = 'Y'
") or die $dbh->errstr;

#
# This is where the grunt work happens

#
# Here we fill Categories.csv with all data
#
print $categories 'v_categories_id,v_categories_image,v_categories_name_1,v_categories_description_1,v_metatags_title_1,v_metatags_keywords_1,v_metatags_description_1' . "\n";

while (my $line = <$input_csv>) 
	{	
	$line =~ s/\"|\'//gi;
	my ($catid,$catimg,$catname,$catdesc,$cattitle,$catkey,$catmetdesc) = split ',' , $line;

	# skip if empty category name
	next if $catname eq '';
	$get_cat_sth->execute($catname);
	my $cat_table = $get_cat_sth->fetchrow_hashref;
	unless (defined ($cat_table))
		{
		print "Can't find Category for $catname\n";
		next;
		}

	print $categories $catid, $cat_table->{image}, $catname, $cat_table->{description}, "", "", "" . "\n";
	}	


#
# Disconnect from database
#
$get_cat_sth->finish;
$dbh->disconnect;

close $categories;
exit 0;

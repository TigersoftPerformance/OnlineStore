#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use TP;

use constant CSV => "./CategoryMeta-EPTigersoft.csv";
open (my $categories, ">", CSV) or die "Cannot open " . CSV;

die "Please pass input CSV file!\n" unless $ARGV[0];
use constant IN_CSV => $ARGV[0];
open (my $input_csv, "<", IN_CSV) or die "Cannot open " . IN_CSV;

$OFS = ',';

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
# Select a row from Categories based on calculated
#
my $get_cat_sth = $dbh->prepare("
	SELECT * FROM Categories WHERE shortname = ? AND active = 'Y'
") or die $dbh->errstr;

#
# This is where the grunt work happens

#
# Here we fill Categories.csv with all data
#
print $categories 'v_categories_id,v_categories_image,v_categories_name_1,v_categories_description_1,v_metatags_title_1,v_metatags_keywords_1,v_metatags_description_1,v_sort_order' . "\n";

while (my $line = <$input_csv>) 
	{	
	$line =~ s/\"|\'//gi;
	my ($catid,$catimg,$catname,$catdesc,$cattitle,$catkey,$catmetdesc,$sort_order) = split ',' , $line;

	# skip if empty category name
	next if $catname eq '';
	&debug ("Looking for Category for <$catname>\n");
	$get_cat_sth->execute($catname);
	my $cat_table = $get_cat_sth->fetchrow_hashref;
	unless (defined ($cat_table))
		{
		&screen ("Can't find Category for <$catname>\n");
		next;
		}

	my $description = $cat_table->{description};
	$description =~ s/\"/\"/g;
	$description =~ s/,/&#44;/g;
	$description =~ s/\R//g;
	
	print $categories $catid, $cat_table->{image}, $catname, $description, $cat_table->{metatags_title}, $cat_table->{metatags_keywords}, $cat_table->{metatags_description}, $cat_table->{sort_order} . "\n";
	}	


#
# Disconnect from database
#
$get_cat_sth->finish;
$dbh->disconnect;

close $categories;
exit 0;

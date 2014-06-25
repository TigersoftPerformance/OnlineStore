#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';

use constant CSV => "./Categories.csv";
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
my $dsn = "DBI:$driver:;" . "mysql_read_default_file=$my_cnf";
my $dbh = DBI->connect($dsn, undef, undef,
	{
	RaiseError => 1, PrintError => 1, mysql_enable_utf8 => 1
	}
) or die $DBI::errstr;

#
# forming quesry based on command arguments
#
my $cars_query = "SELECT * FROM Cars WHERE active = 'Y'";
#if (defined $ARGV[0])
#{
#	$cars_query = "$cars_query AND make ='$ARGV[0]'";
#	if (defined $ARGV[1])
#	{
#		$cars_query = "$cars_query AND model ='$ARGV[1]'";
#	}
#}

my $sth = $dbh->prepare($cars_query) or die $dbh->errstr;
$sth->execute() or die $dbh->errstr;

#
# Select a row from Categories based on calculated
#
my $get_cat_sth = $dbh->prepare("
	SELECT * FROM Categories WHERE calculated = ?
") or die $dbh->errstr;

#
# Select a row from SuperchipsMakes based on make
#
my $get_make_sth = $dbh->prepare("
	SELECT * FROM SuperchipsMakes WHERE make = ?
") or die $dbh->errstr;

#
# Insert a new row into Categories
#
my $ins_cat_sth = $dbh->prepare("
	INSERT INTO Categories (name, calculated, image, description, active) VALUES (?,?,?,?,?)
") or die $dbh->errstr;


#
# This is where the grunt work happens
# This main loop reads each row from the Cars table
#
#print $categories 'v_categories_id,v_categories_image,v_categories_name_1,v_categories_description_1,v_metatags_title_1,v_metatags_keywords_1,v_metatags_description_1' . "\n";
#print $categories '38086,#N/A,Select My Car,#N/A,,,\n';


my $category_id = 0;
my ($modelCode,$idCars,$make);
my $car_data = {};

# Loop through every entry in the Cars Table
while ($car_data = $sth->fetchrow_hashref)
	{	
	$modelCode = 0;	
	$idCars = $car_data->{idCars};
	$make = $car_data->{make} . " " . $car_data->{model};

	# Check to see if this car has a model code
	$modelCode = 1 if $car_data->{model_code};

	# Build the "head" of the category
	my $v_categories_name_1 = "Find Stuff For My Car!^" . $car_data->{make} . "^" . $car_data->{model};
	if (length ($car_data->{model_code}))
		{
		$v_categories_name_1 = $v_categories_name_1 . "^" . $car_data->{model_code};
		}

	# Now build the Short Date
	my $start_year = substr ($car_data->{start_date}, 0, 4);
	my $end_year = substr ($car_data->{end_date}, 0, 4);
	my $start_part = ($start_year eq 1970) ? "upto" : substr ($start_year, 2, 2);
	my $middle_part = "-";
	my $end_part = ($end_year eq 2050 || $end_year eq "0000") ? "on" : substr ($end_year, 2, 2);
	my $short_date = ($start_year eq 1970 && $end_year eq 2050) ? "" : " (". $start_part . $middle_part . $end_part . ")";
	my $carkw = ($car_data->{original_kw} ? " " . $car_data->{original_kw} . "kW": "");

	$v_categories_name_1 = $v_categories_name_1 . "^" . (length ($car_data->{variant}) ? $car_data->{variant} : "All Models") . $carkw . $short_date;
	$v_categories_name_1 = &get_updated_category ($v_categories_name_1);

	print "\t$v_categories_name_1\n" if $v_categories_name_1;

	}

say "*"x50;


#
# Here we fill Categories.csv with all data
#
my $q = '';
my ($catid,$catimg,$catname,$catdesc,$cattitle,$catkey,$catmetdesc)= ("")x7;
LP:
while (my $line = <$input_csv>) 
	{	
		$line =~ s/\"|\'//gi;

	my $flag = 0;	
	($catid,$catimg,$catname,$catdesc,$cattitle,$catkey,$catmetdesc) = split ',' , $line;

	# skip if empty category name
	next if $catname eq '';	
	if ($q =~ /\(|\)/)
		{
		$q =~ s/(^.*)(\^.+)$/$1/g ;		
		}
	if ($catname !~ /\(|\)/)
		{
		$get_make_sth->execute($catname) or die $dbh->errstr;
		if (my $make = $get_make_sth->fetchrow_hashref)
			{
			$q = 'Find Stuff For My Car!^' . $catname;	
			}
		else
			{
			$q .= '^' . $catname;	
			}	
		}
	else
		{
		$q .= '^' . $catname;	
		}	

		
	#$cat_name = $1 if $current_calculated =~ /^.*\^(.+?)$/;

	my $count = () = $q =~ /\^/gi;

	# if category has lack of data in a row
	if ($catimg eq '' && $catdesc eq '')
		{
		$get_cat_sth->execute($q) or die "Failed to execute SQL Category request";
		if (my $cat = $get_cat_sth->fetchrow_hashref)
			{
			print $categories "$catid\,$cat->{image}\,$catname\,$cat->{description}\,\,\, \n";	
			$flag++;	
			}
		elsif ($flag == 0 && $count > 2)
			{

			$q =~ s/(^.*)(\^.+)(\^.+)$/$1$3/ ;

			$get_cat_sth->execute($q) or die "Failed to execute SQL Category request";	
			if (my $cat2 = $get_cat_sth->fetchrow_hashref)
				{
				print $categories "$catid\, $cat2->{image}\,$catname\,$cat2->{description}\,\,\, \n";	
				}
			else
				{
				print "Could not find category for ID:$catid name:$catname\n";	
				}	

			}	

		else
			{
			print "Could not find category for ID:$catid name:$catname\n";		
			next LP;
			}
		}
	# copy that line	
	else
		{	
		print $categories $line;
		}	

	}	


#
# Disconnect from database
#
$sth->finish;
$get_cat_sth->finish;
$ins_cat_sth->finish;
$dbh->disconnect;

close $categories;
exit 0;


sub get_updated_category
##########################
# Updates Categories data 
# in Categories table and
# in Categories.csv
##########################
{	
	my $calculated = shift;
	my $image = "";
	my $cur_image = "";
	my $active = "Y";
	my $cat_name = "";
	
	my @calc_elements = split(/\^/, $calculated);
	# remove the heading My Car
	shift @calc_elements;

	my $current_calculated = "Find Stuff For My Car!";
	my $counter = 0;
	for (@calc_elements)
		{
		my $description = "";	
		$cur_image .= $_; 
		$current_calculated = $current_calculated . "^" . $_;	

		$counter++;
		my $category_hr = $get_cat_sth->execute($current_calculated) or die "Failed to execute SQL Category request";
		unless ($category_hr = $get_cat_sth->fetchrow_hashref)
			{
			$category_id++;	
			$cat_name = $1 if $current_calculated =~ /^.*\^(.+?)$/;
			$cat_name = $current_calculated;
			if ($counter == 1)
				{
				$description = "Please select your Vehicle's Model from the list below:";
				$image = "Cat1" . $cur_image;		
				}
			if ($modelCode == 1)
				{
				if ($counter == 2)	
					{
					$image = "Cat2" . $cur_image;		
					$description = "Please select your Vehicle's Model Code from the list below:";	
					}
				if ($counter == 3)	
					{
					$image = "Cat3" . $cur_image;	
					$description = "Please select your Vehicle's Variant from the list below:";	
					}
				if ($counter == 4)
					{
					$image = sprintf ("TPC%06d", $idCars);	
					$description = "Items for your $make are listed below:";		
					}
				}
			else	
				{
				if ($counter == 2)	
					{
					$image = "Cat2" . $cur_image;
					$description = "Please select your Vehicle's Variant from the list below:";	
					}
				if ($counter == 3)
					{
					$image = sprintf ("TPC%06d", $idCars);	
					$description = "Items for your $make are listed below:";		
					}	
				}
			
			$image =~ s/\s+//g;	
			$image = $image . '.jpg';	
			
			$ins_cat_sth->execute($cat_name, $current_calculated, $image, $description, $active) or die $dbh->errstr;
			#print $categories ",$image,$cat_name,$description,,,\n";
			}	
		}
	return $cat_name;		
}

	

#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use TP;

use constant ROOT_CATEGORY => "Find Stuff For My Car";
use constant IMAGE_DIR => "/StorePics/";

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
# forming quesry based on command arguments
#
my $cars_query = "SELECT * FROM Cars WHERE active = 'Y'";

my $sth = $dbh->prepare($cars_query) or die $dbh->errstr;
$sth->execute() or die $dbh->errstr;

#
# read a row from Categories
#
my $get_cat_sth = $dbh->prepare("
	Select * From Categories where shortname = ? and partid = ?
") or die $dbh->errstr;

#
# Insert a new row into Categories
#
my $ins_cat_sth = $dbh->prepare("
	INSERT IGNORE INTO Categories (longname, shortname, partid, image, description, sort_order, active) VALUES (?,?,?,?,?,?,?)
") or die $dbh->errstr;


#
# This is where the grunt work happens
# This main loop reads each row from the Cars table
#

my $car_data = {};

# Loop through every entry in the Cars Table
while ($car_data = $sth->fetchrow_hashref)
	{	
	# OK, first we have to build a top level category for the Make
	my $shortname = $car_data->{make};
	my $longname = ROOT_CATEGORY . "^" . $shortname;
	my $image = "Cat1" . $car_data->{make} . ".jpg";
	$image =~ s/[ \/]+//g;
	$image = IMAGE_DIR . $image;
	my $description = INFOBOX_START . INFOBOX_FULL . "<h3>Please select the MODEL of your " . $car_data->{make} . " from the list below</h3>" . INFOBOX_END;
	write_db_record ($longname, $shortname, 0, $image, $description, 0, "Y");
	
	# Now we have to build a second level category for the Model
	$shortname = $car_data->{model};
	$longname = $longname . "^" . $shortname;
	$image = "Cat2" . $car_data->{make} . $car_data->{model} . ".jpg";
	$image =~ s/[ \/]+//g;
	$image = IMAGE_DIR . $image;
	if (length($car_data->{model_code}))
		{
		$description = INFOBOX_START . INFOBOX_FULL . "<h3>Please select the MODEL CODE of your " . $car_data->{make} . " " . $car_data->{model} . " from the list below" . INFOBOX_END;
		}
	else
		{
		$description = INFOBOX_START . INFOBOX_FULL . "<h3>Please select the VARIANT of your " . $car_data->{make} . " " . $car_data->{model} . " from the list below" . INFOBOX_END;
		}
	write_db_record  ($longname, $shortname, 0, $image, $description, 0, "Y");
	
	# If the model_code exists then we need to build a 3rd level category for that as well.
	if (length($car_data->{model_code}))
		{
		if ($car_data->{model_code} =~ m/$car_data->{model}/)
			{
			$shortname = $car_data->{model_code};
			}
		else
			{
			$shortname = $car_data->{model} . " " . $car_data->{model_code};
			}
		
		$longname = $longname . "^" . $shortname;
		$image = "Cat3" . $car_data->{make} . $car_data->{model} . $car_data->{model_code} . ".jpg";
		$image =~ s/[ \/]+//g;
		$image = IMAGE_DIR . $image;
		$description = INFOBOX_START . INFOBOX_FULL . "<h3>Please select the variant of your " . $car_data->{make} . " " . $car_data->{model} . " " . $car_data->{model_code} . " from the list below" . INFOBOX_END;
		write_db_record ($longname, $shortname, 0, $image, $description, 0, "Y");
		}
	
	# Finally, we can build the low level category
	# First build the Short Date
	my $start_year = substr ($car_data->{start_date}, 0, 4);
	my $end_year = substr ($car_data->{end_date}, 0, 4);
	my $start_part = ($start_year eq 1970) ? "upto" : substr ($start_year, 2, 2);
	my $middle_part = "-";
	my $end_part = ($end_year eq 2050 || $end_year eq "0000") ? "on" : substr ($end_year, 2, 2);
	my $short_date = ($start_year eq 1970 && ($end_year eq 2050 || $end_year eq "0000")) ? "" : "[". $start_part . $middle_part . $end_part . "]";

	my $model_code = "";
	if (length ($car_data->{model_code}))
		{
		$model_code = $car_data->{model_code};
		$model_code =~ s/$car_data->{model} //;
		$model_code = " (" . $model_code . ")";
		}

        my $sort_order;
        if ($car_data->{fuel_type} eq TURBODIESEL)
		{
		$sort_order = 1000;
		}
        elsif ($car_data->{fuel_type} eq TURBOPETROL)
		{
		$sort_order = 2000;
		}
        elsif ($car_data->{fuel_type} eq SUPERCHARGED)
		{
		$sort_order = 3000;
		}
        elsif ($car_data->{fuel_type} eq TWINCHARGER)
		{
		$sort_order = 4000;
		}
        elsif ($car_data->{fuel_type} eq NONTURBO)
		{
		$sort_order = 5000;
		}
        else
		{
		alert ("ERROR: Unknown Fuel Type $car_data->{fuel_type}");
		}


	# And then add the power figure in kW
	my $carkw = ($car_data->{original_kw} ? $car_data->{original_kw} . "kW" : "");
	$sort_order += ($car_data->{original_kw} ? $car_data->{original_kw} : 0);

	$shortname = $car_data->{model} . $model_code;
	if (length ($car_data->{variant}))
		{
		$shortname = $shortname . " " . $car_data->{variant};
		}
	$shortname = $shortname . " " . $carkw . " " . $short_date;
	$longname = $longname . "^" . $shortname;
	$image = sprintf ("TPC%06d.jpg", $car_data->{idCars});
	$image = IMAGE_DIR . $image;
	$description = INFOBOX_START . INFOBOX_FULL . "<h3>Products available for your " . $car_data->{make} . " " . $car_data->{model} . " " . $car_data->{model_code} . " are listed below" . INFOBOX_END;
	write_db_record ($longname, $shortname, $car_data->{idCars}, $image, $description, $sort_order, "Y");

	debug ("\t$longname");

	}


#
# Disconnect from database
#
$sth->finish;
$ins_cat_sth->finish;
$dbh->disconnect;

exit 0;


sub write_db_record
	{
	my ($longname, $shortname, $partid, $image, $description, $sort_order, $active) = @_;

	$get_cat_sth->execute ($shortname, $partid) or die "Could not execute Get Cat";
	my $cat = $get_cat_sth->fetchrow_hashref;
	if (defined $cat)
		{
		if ($partid)
			{
			screen ("This product record already exists! $shortname, $partid");
			}
		else
			{
			# debug ("This category record already exists: $shortname, $partid");
			}
		}
			
	$ins_cat_sth->execute ($longname, $shortname, $partid, $image, $description, $sort_order, $active) or die "Could not insert $longname";
	if (defined $dbh->err)
		{
		debug ("Error: $dbh->err, $dbh->errstr");
		}
	}
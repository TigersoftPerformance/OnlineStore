#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';

use constant ROOT_CATEGORY => "Find Stuff For My Car!";

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
# Insert a new row into Categories
#
my $ins_cat_sth = $dbh->prepare("
	INSERT INTO Categories (longname, shortname, idCars, image, description, active) VALUES (?,?,?,?,?,?) ON DUPLICATE KEY UPDATE description = values (description)
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
	my $description = "Please select the model of your " . $car_data->{make} . " from the list below";
	$ins_cat_sth->execute ($longname, $shortname, 0, $image, $description, "Y") or die "Could not insert $longname";
	
	# Now we have to build a second level category for the Model
	$shortname = $car_data->{model};
	$longname = $longname . "^" . $shortname;
	$image = "Cat2" . $car_data->{make} . $car_data->{model} . ".jpg";
	$image =~ s/[ \/]+//g;
	if (length($car_data->{model_code}))
		{
		$description = "Please select the model code of your " . $car_data->{make} . " " . $car_data->{model} . " from the list below";
		}
	else
		{
		$description = "Please select the variant of your " . $car_data->{make} . " " . $car_data->{model} . " from the list below";
		}
	$ins_cat_sth->execute ($longname, $shortname, 0, $image, $description, "Y") or die "Could not insert $longname";
	
	# If the model_code exists then we need to build a 3rd level category for that as well.
	if (length($car_data->{model_code}))
		{
		$shortname = $car_data->{model} . " " . $car_data->{model_code};
		$longname = $longname . "^" . $shortname;
		$image = "Cat3" . $car_data->{make} . $car_data->{model} . $car_data->{model_code} . ".jpg";
		$image =~ s/[ \/]+//g;
		$description = "Please select the variant of your " . $car_data->{make} . " " . $car_data->{model} . " " . $car_data->{model_code} . " from the list below";
		$ins_cat_sth->execute ($longname, $shortname, 0, $image, $description, "Y") or die "Could not insert $longname";
		}
	
	# Finally, we can build the low level category
	# First build the Short Date
	my $start_year = substr ($car_data->{start_date}, 0, 4);
	my $end_year = substr ($car_data->{end_date}, 0, 4);
	my $start_part = ($start_year eq 1970) ? "upto" : substr ($start_year, 2, 2);
	my $middle_part = "-";
	my $end_part = ($end_year eq 2050 || $end_year eq "0000") ? "on" : substr ($end_year, 2, 2);
	my $short_date = ($start_year eq 1970 && ($end_year eq 2050 || $end_year eq "0000")) ? "" : "(". $start_part . $middle_part . $end_part . ")";
	
	# And then add the power figure in kW
	my $carkw = ($car_data->{original_kw} ? $car_data->{original_kw} . "kW" : "");

	$shortname = $car_data->{model};
	if (length ($car_data->{variant}))
		{
		$shortname = $shortname . " " . $car_data->{variant};
		}
	$shortname = $shortname . " " . $carkw . " " . $short_date;
	$longname = $longname . "^" . $shortname;
	$image = sprintf ("TPC%06d.jpg", $car_data->{idCars});
	$description = "Products available for your " . $car_data->{make} . " " . $car_data->{model} . " " . $car_data->{model_code} . " are listed below";
	$ins_cat_sth->execute ($longname, $shortname, $car_data->{idCars}, $image, $description, "Y") or die "Could not insert $longname";

	print "\t$longname\n" if $longname;

	}

say "*"x50;


#
# Disconnect from database
#
$sth->finish;
$ins_cat_sth->finish;
$dbh->disconnect;

exit 0;


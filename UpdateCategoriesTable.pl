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
	INSERT IGNORE INTO Categories (longname, shortname, partid, image, description, metatags_title, metatags_keywords, metatags_description, sort_order, active) VALUES (?,?,?,?,?,?,?,?,?,?)
") or die $dbh->errstr;


#
# This is where the grunt work happens
# This main loop reads each row from the Cars table
#
my $metatags_title = "";
my $metatags_keywords = "";
my $metatags_description = "";
my $model_code;
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
	my $description = INFOBOX_CONTAINER . INFOBOX_START . INFOBOX_FULL . "<h3>Please select the MODEL of your " . $car_data->{make} . " from the list below</h3>" . INFOBOX_END . INFOBOX_CONTAINER_END;

	$metatags_title = &create_metatags_title ($car_data->{make});
	$metatags_keywords = &create_metatags_keywords ($car_data->{make});
	$metatags_description = &create_metatags_description ($car_data->{make});
	
	write_db_record ($longname, $shortname, 0, $image, $description, 
	 $metatags_title, $metatags_keywords, $metatags_description, 0, "Y");
	
	# Now we have to build a second level category for the Model
	$shortname = $car_data->{model};
	$longname = $longname . "^" . $shortname;
	$image = "Cat2" . $car_data->{make} . $car_data->{model} . ".jpg";
	$image =~ s/[ \/]+//g;
	$image = IMAGE_DIR . $image;
	if (length($car_data->{model_code}))
		{
		$description = INFOBOX_CONTAINER . INFOBOX_START . INFOBOX_FULL . "<h3>Please select the MODEL CODE of your " . $car_data->{make} . " " . $car_data->{model} . " from the list below" . INFOBOX_END . INFOBOX_CONTAINER_END;
		}
	else
		{
		$description = INFOBOX_CONTAINER . INFOBOX_START . INFOBOX_FULL . "<h3>Please select the VARIANT of your " . $car_data->{make} . " " . $car_data->{model} . " from the list below" . INFOBOX_END . INFOBOX_CONTAINER_END;
		}
	my $makemodel = "$car_data->{make} $car_data->{model}";
	$metatags_title = &create_metatags_title ($makemodel);
	$metatags_keywords = &create_metatags_keywords ($makemodel);
	$metatags_description = &create_metatags_description ($makemodel);

	write_db_record ($longname, $shortname, 0, $image, $description, 
	 $metatags_title, $metatags_keywords, $metatags_description, 0, "Y");
	
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


		$model_code = "";
		if (length ($car_data->{model_code}))
			{
			$model_code = $car_data->{model_code};
			$model_code =~ s/$car_data->{model} //;
			$model_code = " (" . $model_code . ")";
			}
		my $makemodel = "$car_data->{make} $car_data->{model} $model_code";
		$description = INFOBOX_CONTAINER . INFOBOX_START . INFOBOX_FULL;
		$description .= "<h3>Please select the variant of your $makemodel from the list below</h3>";
		$description .= "<p>PLEASE NOTE: The variants listed below are not in alphabetical order. They are sorted first by Engine Type (Turbo Diesel, Turbo Petrol, Non Turbo Petrol etc), and then by the original power (highlighted in red). If you are unable to find your car listed below, please feel free to <a href='ContactUs'>contact us</a> to see what we can do</p>";		
		
		$description .= INFOBOX_END . INFOBOX_CONTAINER_END;
		$description =~ s/,/&#44;/g;
		$metatags_title = &create_metatags_title ($makemodel);
		$metatags_keywords = &create_metatags_keywords ($makemodel);
		$metatags_description = &create_metatags_description ($makemodel);

		write_db_record ($longname, $shortname, 0, $image, $description, 
		 $metatags_title, $metatags_keywords, $metatags_description, 0, "Y");
		}
	
	# Finally, we can build the low level category
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


	$sort_order += ($car_data->{original_kw} ? $car_data->{original_kw} : 0);

	my $completename = &get_complete_model ($car_data);
	$shortname = $completename;
	$shortname =~ s/^$car_data->{make} //;
	$longname = $longname . "^" . $shortname;
	$image = sprintf ("TPC%06d.jpg", $car_data->{idCars});
	$image = IMAGE_DIR . $image;
	$description = INFOBOX_CONTAINER . INFOBOX_START . INFOBOX_FULL . "<h3>Products available for your " . $car_data->{make} . " " . $car_data->{model} . " " . $car_data->{model_code} . " are listed below" . INFOBOX_END . INFOBOX_CONTAINER_END;


	$metatags_title = &create_metatags_title ($completename);
	$metatags_keywords = &create_metatags_keywords ($completename);
	$metatags_description = &create_metatags_description ($completename);

	write_db_record ($longname, $shortname, $car_data->{idCars}, $image, $description, 
	 $metatags_title, $metatags_keywords, $metatags_description, $sort_order, "Y");

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
	my ($longname, $shortname, $partid, $image, $description, $metatags_title, $metatags_keywords, $metatags_description, $sort_order, $active) = @_;

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
			
	$ins_cat_sth->execute ($longname, $shortname, $partid, $image, $description, $metatags_title, $metatags_keywords, $metatags_description, $sort_order, $active) or die "Could not insert $longname";
	if (defined $dbh->err)
		{
		debug ("Error: $dbh->err, $dbh->errstr");
		}
	}
	
sub create_metatags_title
	{
	my ($complete_model) = @_;
	
	return "All Products to suit $complete_model at Tigersoft Performance Cheltenham Melbourne Australia"
	}

sub create_metatags_keywords
	{
	my ($complete_model) = @_;
	
	return "$complete_model performance tune - $complete_model performance tuning - $complete_model bluefin tune - $complete_model bluefin tuning - $complete_model superchips tune - $complete_model superchips tuning - $complete_model fuel economy - $complete_model save fuel - performance tune - tigersoft performance - $complete_model BC Forged Wheels - $complete_model BC Racing Coilovers -  complete_model BMC Air Filters - $complete_model BMC Cold Air Intake - $complete_model BC Forged Wheels";
	}

sub create_metatags_description
	{
	my ($complete_model) = @_;
	
	return "All Products to suit $complete_model at Tigersoft Performance Cheltenham Melbourne Australia"
	}

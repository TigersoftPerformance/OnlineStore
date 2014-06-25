#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';

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
# prepare the sql statements
# This is for the main loop, we will read every entry with a model code
my $carsth = $dbh->prepare("
	SELECT * FROM Cars WHERE active = 'Y' AND model_code != ''
") or die $dbh->errstr;
$carsth->execute() or die $dbh->errstr;

# Now to select a matching entry from model_code
my $selmdlth = $dbh->prepare("
	SELECT * FROM ModelCodes WHERE make = ? AND model = ? AND model_code = ?
") or die $dbh->errstr;

# Insert new row into model_code
my $insmdlth = $dbh->prepare("
		INSERT into ModelCodes (make, model, model_code, start_date, end_date) VALUES (?,?,?,?,?)
") or die $dbh->errstr;

# Update existing row into model_code
my $updmdlth = $dbh->prepare("
		UPDATE ModelCodes SET start_date = ?, end_date = ? WHERE make = ? AND model = ? AND model_code = ?
") or die $dbh->errstr;

# Update existing row into Cars
my $updcarth = $dbh->prepare("
		UPDATE Cars SET start_date = ?, end_date = ? WHERE idCars = ?
") or die $dbh->errstr;

while (my $car_data = $carsth->fetchrow_hashref)
	{
# fields includes in $car_data are  idCars, make, model, model_code, variant, fuel_type, start_date, end_date, capacity, cylinders, original_bhp, original_kw, original_nm, superchips_tune, superchips_stage2, superchips_stage3, superchips_stage4, bmc_airfilter, bc_racing_coilovers
	my $carid = $car_data->{idCars};
	my $make = $car_data->{make};
	my $model = $car_data->{model};
	my $model_code = $car_data->{model_code};
	my $variant = $car_data->{variant};
	$selmdlth->execute($make, $model, $model_code) or die $dbh->errstr;
	
	if (my $model_code_data = $selmdlth->fetchrow_hashref)
		{
		my $model_start_year = substr ($model_code_data->{start_date}, 0, 4);
		my $model_end_year = substr ($model_code_data->{end_date}, 0, 4);
		my $car_start_year = substr ($car_data->{start_date}, 0, 4);
		my $car_end_year = substr ($car_data->{end_date}, 0, 4);
		my $start_year = 0;
		my $end_year = 0;

		if ($car_start_year < $model_start_year || $car_end_year > $model_end_year)
			{
			say "Car: $carid $make $model ($model_code) $variant $car_start_year to $car_end_year";
			say "\tModel: $model_code $model_start_year $model_end_year";
			}

		if ($car_end_year == 2050 && $model_end_year < 2050)
			{
			$end_year = $model_end_year;
			$updcarth->execute($car_data->{start_date}, sprintf ("%4s-12-31", $end_year), $car_data->{idCars}) or die $dbh->errstr;
			}
			
		# only do the updates if the years have changed
		# $updmdlth->execute(sprintf ("%4s", $start_year), sprintf ("%4s", $end_year), $make, $model, $model_code) or die $dbh->errstr;
		}
	else
		{
		say "Need to add record for " . $model_code;
		$insmdlth->execute($car_data->{make}, $car_data->{model}, $car_data->{model_code}, substr ($car_data->{start_date}, 0, 4), substr ($car_data->{end_date}, 0, 4)) or die $dbh->errstr;
		}
	}


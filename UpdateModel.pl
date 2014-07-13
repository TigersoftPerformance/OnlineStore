#!/usr/bin/perl
####################################################
# This script fetches Cars table and based on that
# updates data in ModelCodes table, by inserting 
# new Models and expanding date range in ModelCodes 
# tablerange if needed
####################################################

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
my $dsn = "DBI:$driver:;" . "mysql_read_default_file=$my_cnf" . ";mysql_read_default_group=TigersoftPerformance";
my $dbh = DBI->connect($dsn, undef, undef,
	{
	RaiseError => 1, PrintError => 1, mysql_enable_utf8 => 1
	}
) or die $DBI::errstr;

#
# prepare the sql statements
# This is for the main loop, we will read every entry with a model code
my $carsth = $dbh->prepare("
	SELECT * FROM Cars WHERE active = 'Y' AND model_code = ''
") or die $dbh->errstr;
$carsth->execute() or die $dbh->errstr;

# Now to select a matching entry from model_code
my $selmdlth = $dbh->prepare("
	SELECT * FROM ModelCodes WHERE make = ? AND model = ? AND model_code = ''
") or die $dbh->errstr;

# Insert new row into model_code
my $insmdlth = $dbh->prepare("
		INSERT into ModelCodes (make, model, model_code, start_date, end_date, active) VALUES (?,?,?,?,?,?)
") or die $dbh->errstr;

# Update existing row into model_code
my $updmdlth = $dbh->prepare("
		UPDATE ModelCodes SET start_date = ?, end_date = ? WHERE make = ? AND model = ?
") or die $dbh->errstr;

while (my $car_data = $carsth->fetchrow_hashref)
	{
# fields includes in $car_data are  idCars, make, model, model_code, variant, fuel_type, start_date, end_date, capacity, cylinders, original_bhp, original_kw, original_nm, superchips_tune, superchips_stage2, superchips_stage3, superchips_stage4, bmc_airfilter, bc_racing_coilovers
	my $carid = $car_data->{idCars};
	my $make = $car_data->{make};
	my $model = $car_data->{model};
	my $model_code = $car_data->{model_code};
	my $variant = $car_data->{variant};
	$selmdlth->execute($make, $model) or die $dbh->errstr;
	
	if (my $model_data = $selmdlth->fetchrow_hashref)
		{
		my $model_start_year = substr ($model_data->{start_date}, 0, 4);
		my $model_end_year = substr ($model_data->{end_date}, 0, 4);
		my $car_start_year = substr ($car_data->{start_date}, 0, 4);
		my $car_end_year = substr ($car_data->{end_date}, 0, 4);
		my $start_year = 0;
		my $end_year = 0;
		my $need_change = 0;

		if ($car_start_year < $model_start_year)
			{
			$need_change++;	
			$model_start_year = $car_start_year;
			}

		if ($car_end_year > $model_end_year)
			{
			$need_change++;
			$model_end_year = $car_end_year;	
			}

		if ($need_change > 0)
			{
			say "Updated date range $model_start_year - $model_end_year for Car: $carid $make $model ";
			$updmdlth->execute($model_start_year, $model_end_year, $make, $model) or die $dbh->errstr;
			}
		}

	else
		{
		say "\tNeed to add record for $make $model";
		$insmdlth->execute($car_data->{make}, $car_data->{model}, $car_data->{model_code}, substr ($car_data->{start_date}, 0, 4), substr ($car_data->{end_date}, 0, 4), "Y") or die $dbh->errstr;
		}
	}


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
	SELECT * FROM Cars WHERE active='Y'
") or die $dbh->errstr;
$carsth->execute() or die $dbh->errstr;

# In this section, we will do Sanity checks on the cars table only, including:
# Make sure that the Dates are in order
my $car_data = {};
while ($car_data = $carsth->fetchrow_hashref)
	{
	my $car_start_year = substr ($car_data->{start_date}, 0, 4);
	my $car_end_year = substr ($car_data->{end_date}, 0, 4);
	
	if ($car_start_year < $car_end_year)
		{
		next;
		}
	if ($car_start_year == $car_end_year)
		{
		my $car_start_month = substr ($car_data->{start_date}, 5, 2);
		my $car_end_month = substr ($car_data->{end_date}, 5, 2);
		
		if ($car_start_month <= $car_end_month)
			{
			next;
			}
		}
	say "Dates wrong for car $car_data->{idCars} - $car_data->{make} - $car_data->{model} - $car_data->{variant}"; 
	}


# In this section, we compare data in the Cars Table, to that in the SuperchipsWebsite table, including:
# Are the dates the same?
# Is the engine capacity the same?
# Are the engine power and torque figures the same?
# Are there Superchips tunes that do not have an entry in the cars table?
# Are there Cars in the Cars table pointing to a Superchips tune that does not exist?




# In this section, we compare the Cars table to the ModelCodes tables


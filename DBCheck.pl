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

my $carsth = $dbh->prepare("
	SELECT * FROM Cars WHERE active='Y'
") or die $dbh->errstr;
$carsth->execute() or die $dbh->errstr;

my $scwth = $dbh->prepare("
	SELECT * FROM SuperchipsWebsite WHERE active='Y'
") or die $dbh->errstr;
$scwth->execute() or die $dbh->errstr;

my $getcarsth = $dbh->prepare("
	SELECT * FROM Cars WHERE superchips_tune=?
") or die $dbh->errstr;

my $fixstartth = $dbh->prepare("
	UPDATE Cars
	 SET start_date = ?
	 WHERE superchips_tune = ?
") or die $dbh->errstr;

my $fixendth = $dbh->prepare("
	UPDATE Cars
	 SET end_date = ?
	 WHERE superchips_tune = ?
") or die $dbh->errstr;


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

my $scvariant = {};
while ($scvariant = $scwth->fetchrow_hashref)
	{
	# say "superchips_tune = $scvariant->{variant_id}";
	my ($retval, $scstartdate, $scenddate) = &parse_superchips_date ($scvariant->{year});
	if ($retval)
		{
		say "Can't understand date: $scvariant->{year} for variant $scvariant->{variant_id} in SuperchipsWebsite";
		next;
		}

	$getcarsth->execute($scvariant->{variant_id}) or die $dbh->errstr;
	my $carslist = {};
	while ($carslist = $getcarsth->fetchrow_hashref)
		{
		if ($scstartdate ne $carslist->{start_date} && $scstartdate ne "1970-01-01")
			{
			say "Car: $carslist->{idCars}: $carslist->{make} $carslist->{model} $carslist->{model_code} $carslist->{variant}. Superchips year is $scvariant->{year}. Start date should be $scstartdate, but is $carslist->{start_date}";
			$fixstartth->execute($scstartdate, $carslist->{superchips_tune}) or die;
			}
		
		if ($scenddate ne $carslist->{end_date} && $scenddate ne "2050-12-31")
			{
			say "Car: $carslist->{idCars}: $carslist->{make} $carslist->{model} $carslist->{model_code} $carslist->{variant}. Superchips year is $scvariant->{year}. End date should be $scenddate, but is $carslist->{end_date}";
			$fixendth->execute($scenddate, $carslist->{superchips_tune}) or die;
			}
		}		
	}

# In this section, we compare the Cars table to the ModelCodes tables



sub parse_superchips_date {
	my $superchips_year = $_[0];
	
	my $start_day = "01";
	my $start_month = "01";
	my $start_year = "1970";
	my $end_day = "31";
	my $end_month = "12";
	my $end_year = "2050";
	my $baddate = 1;
	
	# Blank Date
	if ($superchips_year eq "")
		{
		$baddate = 0;
		}

	# 2008 onwards
	if ($superchips_year =~ /^(\d{4}) onwards$/)
		{
		$start_year = $1;
		$baddate = 0;
		}

	# 9/2008 onwards
	if ($superchips_year =~ /^(\d{1,2})\/(\d{4}) onwards$/)
		{
		$start_month = $1;
		$start_year = $2;
		$baddate = 0;
		}

	# up to 1998
	if ($superchips_year =~ /^up to (\d{4})$/)
		{
		$end_year = $1;
		$baddate = 0;
		}

	# up to 9/1998
	if ($superchips_year =~ /^up to (\d{1,2})\/(\d{4})$/)
		{
		$end_month = $1;
		$end_year = $2;
		$baddate = 0;
		}

	# 1997 - 1998
	if ($superchips_year =~ /^(\d{4}) - (\d{4})$/)
		{
		$start_year = $1;
		$end_year = $2;
		$baddate = 0;
		}

	# 1997 - 9/1998
	if ($superchips_year =~ /^(\d{4}) - (\d{1,2})\/(\d{4})$/)
		{
		$start_year = $1;
		$end_month = $2;
		$end_year = $3;
		$baddate = 0;
		}

	# 3/1997 - 1998
	if ($superchips_year =~ /^(\d{1,2})\/(\d{4}) - (\d{4})$/)
		{
		$start_month = $1;
		$start_year = $2;
		$end_year = $3;
		$baddate = 0;
		}

	# 3/1997 - 9/1998
	if ($superchips_year =~ /^(\d{1,2})\/(\d{4}) - (\d{1,2})\/(\d{4})$/)
		{
		$start_month = $1;
		$start_year = $2;
		$end_month = $3;
		$end_year = $4;
		$baddate = 0;
		}
		
	if ($end_month == 2)
		{
		$end_day = "28";
		}
	if ($end_month == 4 || $end_month == 6 || $end_month == 9 || $end_month == 11)
		{
		$end_day = "30";
		}

	my $start_date = sprintf ("%4s-%02s-%02s", $start_year, $start_month, $start_day);
	my $end_date = sprintf ("%4s-%02s-%02s", $end_year, $end_month, $end_day);
	return ( $baddate, $start_date, $end_date);
}


#!/usr/bin/perl -w
#####################################################################################
# MatchCars.pl script - John Robinson, September 2014
# This script attempts to match the cars listed in the Cars table with the appropriate 
# cars listed in the BMC Cars Table
# It loops through all of the cars in the Cars table (restricted by the command line
# arguments) and for every car, it does the following:
# - Finds all of the cars in the BMCCars table that match on Make or Make Alias, and 
#   store them in an array 
# - Erase all of the records that do not match on Model or Model Alias
# - Erase all of the records that do not match on ModelCode or ModelCode Alias
# - 
#####################################################################################

use strict;
use DBI;
use LWP::Simple;
use feature 'say';
use Text::Unidecode;
use utf8;
use English;
use Encode;
use IO::Handle;
use Storable qw(dclone);
use Data::Dumper;

my $url = 'http://au.bmcairfilters.com';
use constant LOG => "./Logs/MatchCars.log";
open (my $logfh, ">", LOG) or die "cannot open " . LOG; 
$logfh->autoflush;

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
# This selects all rows based on make from BMCCars
#
my $get_bmccars_by_make_sth = $dbh->prepare("
	SELECT * FROM BMCCars WHERE make = ?
") or die $dbh->errstr;

#
# This selects all rows based on make from AliasMake
#
my $get_make_alias_sth = $dbh->prepare("
	SELECT * FROM AliasMake WHERE make = ?
") or die $dbh->errstr;

#
# This selects all rows based on make and model from AliasModel
#
my $get_model_alias_sth = $dbh->prepare("
	SELECT * FROM AliasModel WHERE make = ? AND model = ?
") or die $dbh->errstr;

#
# This selects all rows based on make, model and modelcode from AliasModelCode
#
my $get_modelcode_alias_sth = $dbh->prepare("
	SELECT * FROM AliasModelCode WHERE make = ? AND model = ? AND model_code = ?
") or die $dbh->errstr;

# Usage: MatchCars.pl [MAKE [MODEL]]
# Restrict the main loop query based on the passed command line arguments
my $cars_query = "SELECT * FROM Cars WHERE active = 'Y'";
if (defined $ARGV[0])
{
	$cars_query = "$cars_query AND make ='$ARGV[0]'";
	if (defined $ARGV[1])
	{
		$cars_query = "$cars_query AND model ='$ARGV[1]'";
	}
}
my $sth = $dbh->prepare($cars_query) or die $dbh->errstr;
$sth->execute() or die $dbh->errstr;

# This array will hold all of the matchs found based on make, and then gradually whittle away the 
# cars that do not match
my @match_list = ();
my @match_score = ();

# This is the main loop. We are going to read through our own Cars table, car by cars
# and then compile a list of possible matches in the BMCCars table.
my $car_data = {};
while ($car_data = $sth->fetchrow_hashref)
	{
	@match_list = ();
	@match_score = ();
	say "$car_data->{make} $car_data->{model}";
	&load_bmccars_by_make ($car_data->{make});
	say "Found " . scalar (@match_list) . " Cars that match the make $car_data->{make}";

	&erase_non_matching_models ($car_data->{make}, $car_data->{model});
	say "Found " . scalar (@match_list) . " Cars that match the model $car_data->{model}";
	
	# Now zero out the match score array
	foreach my $i (0 .. scalar (@match_list) - 1)
		{
		push (@match_score, 0);
		}

	&score_matching_model_codes ($car_data->{make}, $car_data->{model}, $car_data->{model_code});
	say "Found " . scalar (@match_list) . " Cars that match the model_code $car_data->{model_code}";

	&score_matching_capacity ($car_data->{capacity});
	say "Found " . scalar (@match_list) . " Cars that match the capacity $car_data->{capacity}";
	
	&score_matching_cylinders ($car_data->{cylinders});
	say "Found " . scalar (@match_list) . " Cars that match the cylinders $car_data->{cylinders}";

	&score_matching_dates ($car_data->{start_date}, $car_data->{end_date});
	say "Found " . scalar (@match_list) . " Cars that match the date range $car_data->{start_date} - $car_data->{end_date}";

	#
	# We should also attempt to match the variant string
	#
	
	
	# Do a simple bubble sort of the results
	foreach (0 .. $#match_list - 1)
		{
		foreach my $j (0 .. $#match_list - 1)
			{
			if ($match_score[$j] < $match_score[$j + 1])
				{
				my $tmp = $match_score[$j];
				$match_score[$j] = $match_score[$j + 1];
				$match_score[$j + 1] = $tmp;
				
				my $hashtmp = {};
				$hashtmp = $match_list[$j];
				$match_list[$j] = $match_list[$j + 1];
				$match_list[$j + 1] = $hashtmp;
				}
			}
		}
	
	say "Top 3 results are:";
	my $index = 0;
	while ($index < 3 && $index <= $#match_list)
		{
		my $bmccar = {};
		$bmccar = $match_list[$index];

		say "BMC Car $bmccar->{idBMCCars}\tScore $match_score[$index]";
		$index ++;
		}
			
	}
	
#############################################################################################
# load_bmccars_by_make
# Loads all of the cars in the BMCCars table that match the make (or make alias) of the 
# make of the car from the Cars table. It store them in the match_list array
#############################################################################################

sub load_bmccars_by_make
	{
	# Create a makes array, and store the passed make as the first element
	my @makes = ();
	push (@makes, $_[0]);
	
	# Now go and find all of the alias makes listed in the make alias table, and add them to the array
	$get_make_alias_sth->execute($makes[0]) or die $dbh->errstr;
	my $aliasmake = {};
	while ($aliasmake = $get_make_alias_sth->fetchrow_hashref)
		{
		push (@makes, $aliasmake->{alias});
		}	
	
	# Now that we have our array of makes and make alias', find all of the matching cars in the 
	# BMCCars table and store the hashref to them in the match_list array
	foreach (@makes)
		{
		$get_bmccars_by_make_sth->execute($_) or die $dbh->errstr;
		my $bmccars = {};
		while ($bmccars = $get_bmccars_by_make_sth->fetchrow_hashref)
			{
			push (@match_list, $bmccars);
			}
		}
	}

#############################################################################################
# erase_non_matching_models
# This sub simply goes through the loaded match_list array, and deletes all of those entries
# that do not match the model or model alias of the car from the Cars table
#############################################################################################
sub erase_non_matching_models
	{
	my ($make, $model) = @_;

	# Create an array of models, and load the passed model, and the list of model aliases.
	my @models = ();
	push (@models, $model);
	$get_model_alias_sth->execute($make, $model) or die $dbh->errstr;
	my $aliasmodel = {};
	while ($aliasmodel = $get_model_alias_sth->fetchrow_hashref)
		{
		push (@models, $aliasmodel->{alias});
		}	
	
	# Now we cycle through each entry in the match_list array
	my $index = 0;
	while ($index <= $#match_list)
		{
		my $bmccar = {};
		$bmccar = $match_list[$index];

		my $match_found = 0;
		# and we try and match each each of the models or model alias' with the model field
		foreach my $j (0 .. scalar (@models) - 1)
			{
			if ($bmccar->{model} =~ m/$models[$j]/i)
				{
				$match_found = 1;
				last;
				}
			}
		# and then if we don't find a match, then we delete this entry
		if (!$match_found)
			{
			splice (@match_list, $index, 1);
			}
		else
			{
			$index ++
			}
		}
	}
	
#############################################################################################
# score_matching_model_codes
# This sub simply goes through the loaded match_list array, and scores all of those entries
# that match the model_code or model_code alias of the car from the Cars table
#############################################################################################
sub score_matching_model_codes
	{
	my ($make, $model, $model_code) = @_;

	# If the passed model_code is null, then just return without trying to match anything. 
	if (!length $model_code)
		{
		return;
		}
		
	# Create an array of model_codes, and load the passed model_code, and the list of model_code aliases.
	my @model_codes = ();
	push (@model_codes, $model_code);
	$get_modelcode_alias_sth->execute($make, $model, $model_code) or die $dbh->errstr;
	my $aliasmodelcode = {};
	while ($aliasmodelcode = $get_modelcode_alias_sth->fetchrow_hashref)
		{
		push (@model_codes, $aliasmodelcode->{alias});
		}	
	
	# Now we cycle through each entry in the match_list array
	my $index = 0;
	while ($index <= $#match_list)
		{
		my $bmccar = {};
		$bmccar = $match_list[$index];

		# and we try and match each of the model_codes or model_code alias' with BOTH
		# the model field and the model_code field
		my $match_found = 0;
		foreach my $j (0 .. scalar (@model_codes) - 1)
			{
			if ($bmccar->{model} =~ m/$model_codes[$j]/i || $bmccar->{model_code} =~ m/$model_codes[$j]/i)
				{
				$match_found = 1;
				last;
				}
			}
		# and then if we find a match, then give this entry a 10
		if ($match_found)
			{
			$match_score[$index] += 10;
			}
		$index ++;
		}
	}
	
sub score_matching_capacity
	{
	my $capacity = $_[0];
	
	# if the passed capacity is zero, then just return
	if (!$capacity)
		{
		return 0;
		}
	
	# now loop through the match_list and score all of the entries
	my $index = 0;
	while ($index <= $#match_list)
		{
		my $bmccar = {};
		$bmccar = $match_list[$index];

		# if the capacity of the BMC Car is not specified, then we can't match, so just skip to the next car
		if (!$bmccar->{capacity})
			{
			$index ++;		
			next;
			}
			
		# If the difference in capacity is too big, then delete this record and move on
		if (abs ($bmccar->{capacity} - $capacity) > 0.1)
			{
			splice (@match_list, $index, 1);
			splice (@match_score, $index, 1);
			next;
			}

		# If we have a perfect match, score it a 10, otherwise a 5
		if (!abs ($bmccar->{capacity} - $capacity))
			{
			$match_score[$index] += 10;
			}		
		else
			{
			$match_score[$index] += 5;
			}
		$index ++;		
		}	
	}
	
sub score_matching_cylinders
	{
	my $cylinders = $_[0];
	# if the passed cylinders is zero, then just return
	if (!$cylinders)
		{
		return 0;
		}
	
	# now loop through the match_list and score all of the entries
	my $index = 0;
	while ($index <= $#match_list)
		{
		my $bmccar = {};
		$bmccar = $match_list[$index];

		# if the cylinders of the BMC Car is not specified, then we can't match, so just skip to the next car
		if (!$bmccar->{cylinders})
			{
			$index ++;		
			next;
			}
			
		# If there is any difference in cylinders then delete this record and move on
		if (!abs ($bmccar->{cylinders} - $cylinders))
			{
			splice (@match_list, $index, 1);
			splice (@match_score, $index, 1);
			next;
			}

		$match_score[$index] += 10;
		$index ++;		
		}	
	}
	
sub score_matching_dates
	{
	my $start_date = $_[0];
	my $end_date = $_[1];

	my $start_year = substr ($start_date, 4, 0);
	my $end_year = substr ($end_date, 4, 0);
	
	# OK, so from this point on, lets treat the dates as numbers, 
	# represnting the number fo years since 1970
	$start_year -= 1970; 
	$start_year = 0 if $start_year < 0;
	$end_year -= 1970; 
	$end_year = 80 if $end_year > 0;
	
	my $span = $end_year - $start_year;
	my $ave_year = $end_year + $start_year / 2;
	
	# return if we have no dates to play with
	return 0 if (!$start_year && !$end_year);

	# now loop through the match_list and score all of the entries
	my $index = 0;
	while ($index <= $#match_list)
		{
		my $bmc_start_year = 0;
		my $bmc_end_year = 0;
		my $bmccar = {};
		$bmccar = $match_list[$index];

		# Now check the year and skip if we dont have one
		if (!length $bmccar->{year})
			{
			$index ++;
			next;
			}
			
		$bmccar->{year}	=~ s/&gt;/>/;
		if ($bmccar->{year} =~ m/^(.+)>(.+)$/)
			{
			$bmc_start_year = $1;
			$bmc_end_year = $2;
			}
		elsif ($bmccar->{year} =~ m/^(.+)>$/)
			{
			$bmc_start_year = $1;
			$bmc_end_year = 50; # At this point, the BMC dates have not been normalised from 1970, so 50 means 2050
			}
		else
			{
			$bmc_start_year = $bmccar->{year};
			$bmc_end_year = 50; # At this point, the BMC dates have not been normalised from 1970, so 50 means 2050
			}
		$bmc_start_year = $1 if $bmc_start_year =~ m/\d{1,2}\/\d{1,2}/;
		$bmc_start_year -= 70; $bmc_start_year += 100 if $bmc_start_year < 0;
		$bmc_end_year -= 70; $bmc_end_year += 100 if $bmc_end_year < 0;

		my $bmc_span = $bmc_end_year - $bmc_start_year;
		my $bmc_ave_year = $bmc_end_year + $bmc_start_year / 2;
		
		# OK, now that the dates have all been parsed and normalised, we can start doing some comparisons
		

		}
	}
	

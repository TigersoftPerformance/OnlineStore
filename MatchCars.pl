#!/usr/bin/perl
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
use feature 'say';

use utf8;
use English;
use Encode;
use Storable qw(dclone);
use Data::Dumper;
use IO::Handle;
use LWP::Simple;
use Set::Scalar;
use Text::Unidecode;

my $url = 'http://au.bmcairfilters.com';
use constant LOGFILE    => "./Logs/MatchCars.log";
use constant ALERTFILE  => "./Logs/MatchCars.alert";
use constant DEBUGFILE  => "./Logs/MatchCars.debug";


use constant MODELCODEWEIGHT => 30;
use constant VARIANTWEIGHT => 20;
use constant YEARWEIGHT => 40;
use constant HPWEIGHT => 60;
use constant CYLINDERSWEIGHT => 15;
use constant CAPACITYWEIGHT => 15;
use constant FUELTYPEWEIGHT => 30;



open(my $logfh, ">", LOGFILE)     or die "cannot open LOGFILE $!";
open(my $alertfh, ">", ALERTFILE) or die "cannot open ALERTFILE $!";
open(my $debugfh, ">", DEBUGFILE) or die "cannot open DEBUGFILE $!";
$logfh->autoflush;
$alertfh->autoflush;
$debugfh->autoflush;

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

#
# This selects all rows based on make and fuel from AliasFuelType
#
my $get_fueltype_alias_sth = $dbh->prepare("
	SELECT * FROM AliasFuelType WHERE make = ? and fuel_type = ?
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
my $matches;

my $stats_make = '';
my $stats_model = '';
my $stats_perfect = 0;
my $stats_low = 0;
my $stats_clear = 0;
my $stats_cant_decide = 0;
my $stats_nomatch = 0;



# This is the main loop. We are going to read through our own Cars table, car by cars
# and then compile a list of possible matches in the BMCCars table.
my $car_data = {};
while ($car_data = $sth->fetchrow_hashref)
	{
	@match_list = ();
	@match_score = ();
	
	#############################################################
	# This stuff takes care of statistics for each model_code
	#############################################################
	if ($stats_make ne $car_data->{make} || $stats_model ne $car_data->{model})
		{
		if ($stats_make)
			{
			&screen ("Match Stats for $stats_make $stats_model:");
			&screen ("  > $stats_perfect Perfect Matches");
			&screen ("  > $stats_clear Clear Matches");
			&screen ("  > $stats_low Low Scores");
			&screen ("  > $stats_cant_decide Can't decide");
			&screen ("  > $stats_nomatch Failed to match");
			}
		$stats_make = $car_data->{make};
		$stats_model = $car_data->{model};
		$stats_perfect = 0;
		$stats_low = 0;
		$stats_clear = 0;
		$stats_cant_decide = 0;
		$stats_nomatch = 0;
		}	
	
	
	&log ("CAR $car_data->{idCars}: =$car_data->{make}=$car_data->{model}=($car_data->{model_code})=$car_data->{variant}=$car_data->{fuel_type}=$car_data->{original_bhp}=$car_data->{start_date}=$car_data->{end_date}=$car_data->{capacity}=$car_data->{cylinders}");
	&load_bmccars_by_make ($car_data->{make});
	$matches = $#match_list + 1; &debug ("Found $matches Cars that match the make $car_data->{make}");

	&erase_non_matching_models ($car_data->{make}, $car_data->{model}) if $matches;
	$matches = $#match_list + 1; &debug ("Found $matches Cars that match the model $car_data->{model}");
	
	# Now zero out the match score array
	foreach my $i (0 .. scalar (@match_list) - 1)
		{
		push (@match_score, 0);
		}

	if ($matches)
		{
		&score_matching_model_codes ($car_data->{make}, $car_data->{model}, $car_data->{model_code});
		}
	$matches = $#match_list + 1;
	my $list = '';
	if ($matches)
		{
		&debug ("Found $matches Cars that match the model_code $car_data->{model_code}");
		&list_cars ();	
		&score_matching_dates ($car_data->{start_date}, $car_data->{end_date});
		}
	$matches = $#match_list + 1; 
	
	if ($matches)
		{
		&debug ("Found $matches Cars that match the date range $car_data->{start_date} - $car_data->{end_date}");
		&list_cars ();	
		&score_matching_power ($car_data->{original_bhp});
		}
	$matches = $#match_list + 1; 

	if ($matches)
		{
		&debug ("Found $matches Cars that match the horsepower $car_data->{original_bhp}");
		&list_cars ();	
		&score_matching_capacity ($car_data->{capacity});
		}
	$matches = $#match_list + 1;

	if ($matches)
		{
		&debug ("Found $matches Cars that match the capacity $car_data->{capacity}");
		&list_cars ();	
		&score_matching_cylinders ($car_data->{cylinders});
		}
	$matches = $#match_list + 1; 
	
	if ($matches)
		{
		&debug ("Found $matches Cars that match the cylinders $car_data->{cylinders}");
		&list_cars ();	
		&score_matching_variants ($car_data->{variant});
		}
	$matches = $#match_list + 1; 
		
	if ($matches)
		{
		&debug ("Found $matches Cars that match the variant $car_data->{variant}");
		&list_cars ();	
		&score_matching_fueltypes ($car_data->{make}, $car_data->{fuel_type});
		}
	$matches = $#match_list + 1; 
	&debug ("Found $matches Cars that match the fuel_type $car_data->{fuel_type}");
	&list_cars ();	
	
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
	
	# If $#match_list is negative, then we found no matches
	if ($#match_list < 0)
		{
		&log (" *** No Matches Found! ***");
		$stats_nomatch ++;
		}

	# If $#match_list is zero, then we found exactly one match
	elsif ($#match_list == 0)
		{
		&log (" Perfect Match! :");
		$stats_perfect ++;
		if ($match_score[0] < 90)
			{
			&log (" *** Low Score! ***");
			$stats_low ++;
			}
		}
	elsif ($match_score[0] > $match_score[1] + 15)
		{
		&log (" Clear Match! :");
		$stats_clear ++;
		if ($match_score[0] < 90)
			{
			&log (" *** Low Score! ***");
			$stats_low ++;
			}
		}
	else	
		{
		&log (" *** Can't Decide! *** Found " . scalar (@match_list) . " possible matches:");
		$stats_cant_decide ++;
		}
		
	my $index = 0;
	while ($index < 5 && $index <= $#match_list)
		{
		my $bmccar = {};
		$bmccar = $match_list[$index];

		&log ("  Score $match_score[$index]. BMC CAR =$bmccar->{make}=$bmccar->{model}=($bmccar->{model_code})=$bmccar->{variant}=$bmccar->{hp}=$bmccar->{year}=$bmccar->{capacity}=$bmccar->{cylinders}=");
		$index ++;
		}

	}

if ($stats_make)
	{
	&screen ("Match Stats for $stats_make $stats_model:");
	&screen ("  > $stats_perfect Perfect Matches");
	&screen ("  > $stats_clear Clear Matches");
	&screen ("  > $stats_low Low Scores");
	&screen ("  > $stats_cant_decide Can't decide");
	&screen ("  > $stats_nomatch Failed to match");
	}





sub list_cars
	{
	my $list = ' >'; 
	for my $k (0 .. $#match_list)
		{
		$list = $list . $match_list[$k]->{idBMCCars} . "(" . $match_score[$k] . ") ";
		}
	&debug ($list);
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
		if (defined $aliasmodel->{alias} && length ($aliasmodel->{alias}))
			{
			push (@models, $aliasmodel->{alias});
			}
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

	my $weighting = MODELCODEWEIGHT;
	my $any_matches = 0;
	
	# If the passed model_code is null, then just return without trying to match anything. 
	if (!length $model_code)
		{
		return;
		}
		
	# Create an array of model_codes, and load the passed model_code, and the list of model_code aliases.
	my @model_codes = ();
	if ($model_code =~ m/^(.+)\s*\/\s*(.+)$/)
		{
		push (@model_codes, $1);
		push (@model_codes, $2);
		}
	else
		{
		push (@model_codes, $model_code);
		}
		
	$get_modelcode_alias_sth->execute($make, $model, $model_code) or die $dbh->errstr;
	my $aliasmodelcode = {};
	while ($aliasmodelcode = $get_modelcode_alias_sth->fetchrow_hashref)
		{
		if (defined $aliasmodelcode->{alias} && length ($aliasmodelcode->{alias}))
			{
			push (@model_codes, $aliasmodelcode->{alias});
			}
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
				&debug ("Found match for model code $model_codes[$j]");
				$match_found = 1;
				$any_matches = 1;
				last;
				}
			}
		# and then if we find a match, then give this entry a 10
		if ($match_found)
			{
			$match_score[$index] += $weighting;
			}
		$index ++;
		}

	# if we found any matches, then go and remove any that didn't match
	if ($any_matches)
		{
		$index = 0;
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

			if (!$match_found)
				{
				splice (@match_list, $index, 1);
				splice (@match_score, $index, 1);
				next;
				}
			$index ++;
	
			}
		}
	}
	
sub score_matching_power
	{
	my $power = $_[0];
	
	my $weighting = HPWEIGHT;
	
	# if the passed power is zero, then just return
	if (!$power)
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
		if (!$bmccar->{hp})
			{
			$index ++;		
			next;
			}
			
		# Sometimes the HP power figure quoted on the BMC website is in PS rather than HP
		# so we need to check both
		# my $hppowerdiff = abs ($bmccar->{hp} - $power);
		# my $pspowerdiff = abs ($bmccar->{hp} - ($power / 0.985));
		# my $powerdiff = ($hppowerdiff < $pspowerdiff) ? $hppowerdiff : $pspowerdiff;
		my $powerdiff = abs ($bmccar->{hp} - ($power / 0.985));
		# If the difference in capacity is too big, then delete this record and move on
		if ($powerdiff > 5)
			{
			splice (@match_list, $index, 1);
			splice (@match_score, $index, 1);
			next;
			}

		# So if we get here, give it a score based on how far away it is
		$match_score[$index] += ((10 - ($powerdiff * 2)) / 10) * $weighting;
		$index ++;		
		}	
	}


sub score_matching_capacity
	{
	my $capacity = $_[0];
	my $weighting = CAPACITYWEIGHT;
	
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
			$match_score[$index] += $weighting;
			}		
		else
			{
			$match_score[$index] += $weighting / 2;
			}
		$index ++;		
		}	
	}

	
sub score_matching_cylinders
	{
	my $cylinders = $_[0];
	my $weighting = CYLINDERSWEIGHT;
	
	# if the passed cylinders is zero, then just return
	&debug ("Looking for matches with $cylinders cylinders");
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

		&debug ("car $bmccar->{idBMCCars} has $bmccar->{cylinders} cylinders");

		# if the cylinders of the BMC Car is not specified, then we can't match, so just skip to the next car
		if (!$bmccar->{cylinders})
			{
			$index ++;		
			next;
			}
			
		# If there is any difference in cylinders then delete this record and move on
		if ($bmccar->{cylinders} != $cylinders)
			{
			splice (@match_list, $index, 1);
			splice (@match_score, $index, 1);
			next;
			}

		$match_score[$index] += $weighting;
		$index ++;		
		}	
	}
	
sub score_matching_dates
	{
	my $start_date = $_[0];
	my $end_date = $_[1];

	my $weighting = YEARWEIGHT;
	my $start_year = substr ($start_date, 0, 4);
	my $end_year = substr ($end_date, 0, 4);
	
	# OK, so from this point on, lets treat the dates as numbers, 
	# represnting the number fo years since 1970
	&debug ("Date Range of Car: $start_year - $end_year");
	$start_year -= 1970; 
	$start_year = 0 if $start_year < 0;
	$end_year -= 1970; 
	#
	# NOTE: Setting this to 50 sets the max year to 2020, which is fine in 2014
	#
	$end_year = 45 if $end_year > 45;
	&debug ("Date Range of Car: $start_year - $end_year");
	
	# return if we have no dates to play with
	return 0 if (!$start_year && !$end_year);

	# now loop through the match_list and score all of the entries
	my $index = 0;
	while ($index <= $#match_list)
		{
		my $bmc_start_year = 0;
		my $bmc_end_year = 0;
		my $bmccar = {};
		my $date_score;
		$bmccar = $match_list[$index];

		# Now check the year and skip if we dont have one
		if (!length $bmccar->{year})
			{
			$index ++;
			next;
			}
			
		$bmccar->{year}	=~ s/&gt;/>/;
		&debug ("  BMC Year: $bmccar->{year} ");
		if ($bmccar->{year} =~ m/^(.+)>(.+)$/)
			{
			$bmc_start_year = $1;
			$bmc_end_year = $2;
			}
		elsif ($bmccar->{year} =~ m/^(.+)>$/)
			{
			$bmc_start_year = $1;
			#
			# NOTE: Setting this to 20 sets the max year to 2020, which is fine in 2014
			#
			$bmc_end_year = 15; # At this point, the BMC dates have not been normalised from 1970, so 50 means 2050
			}
		else
			{
			$bmc_start_year = $bmccar->{year};
			#
			# NOTE: Setting this to 20 sets the max year to 2020, which is fine in 2014
			#
			$bmc_end_year = 15; # At this point, the BMC dates have not been normalised from 1970, so 50 means 2050
			}
		$bmc_start_year = $1 if $bmc_start_year =~ m/\d{1,2}\/(\d{1,2})/;
		$bmc_end_year = $1 if $bmc_end_year =~ m/\d{1,2}\/(\d{1,2})/;
		&debug ("Date Range of BMCCar: $bmc_start_year - $bmc_end_year");

		$bmc_start_year -= 70; $bmc_start_year += 100 if $bmc_start_year < 0;
		$bmc_end_year -= 70; $bmc_end_year += 100 if $bmc_end_year < 0;

		&debug ("Date Range of BMCCar: $bmc_start_year - $bmc_end_year");

		# OK, now that the dates have all been parsed and normalised, we can start doing some comparisons
		my $date_range = Set::Scalar->new ($start_year .. $end_year);
		my $bmc_date_range = Set::Scalar->new ($bmc_start_year .. $bmc_end_year);

		&debug ("    date_range = " . $date_range);
		&debug ("    BMC date_range = " . $bmc_date_range);
		
		# if the 2 sets are disjoint, then delete this record and move on
		if ($date_range != $bmc_date_range)
			{
			splice (@match_list, $index, 1);
			splice (@match_score, $index, 1);
			&debug ("      sets are disjoint");
			next;
			}
			
		# if the 2 sets are subset/superset, then score 10 and move on
		if ($date_range <= $bmc_date_range || $date_range >= $bmc_date_range)
			{
			my $size_diff = abs ($date_range->size - $bmc_date_range->size);
			$date_score = $weighting - ($size_diff * $weighting) / 10;
			$match_score[$index] += $date_score;
			$index ++;
			&debug ("      sets are subset/superset, score is $date_score");
			next;
			}

		my $total_size = $date_range->size + $bmc_date_range->size;
		my $intersection = $date_range * $bmc_date_range;
						
			
		# If we get here, then we have intersecting sets. So base the score on the 
		# amount of intersection
		
		# If we only have an intersection of 1, but both sets are greater than 1 element long, then
		# it is likely that we have 2 not equal sets such as 02-07 and 07-11.
		if ($intersection == 1 && $date_range->size > 1 && $bmc_date_range->size > 1)
			{
			splice (@match_list, $index, 1);
			splice (@match_score, $index, 1);
			&debug ("      sets are probably disjoint");
			next;
			}
		
		
		my $date_score += ($intersection->size * $weighting) / $total_size;
		$match_score[$index] += $date_score;
		&debug ("      sets are intersecting, score is $date_score");
		$index ++;
		}
	}
	
sub score_matching_variants
	{
	my $variant = $_[0];
	my $weighting = VARIANTWEIGHT;
	my @var_words = split (/ /, $variant);

	&debug ("  trying to match variant " . $variant);
	my $index = 0;
	while ($index <= $#match_list)
		{
		my $bmccar = {};
		$bmccar = $match_list[$index];
		my $var_word_score = 0;
		my $variant = $bmccar->{variant};
		$variant =~ s/\s+//g;
		
		for my $i (0 .. $#var_words)
			{
			&debug ("  trying to match var_word " . $var_words[$i]);
			if ($variant =~ m/$var_words[$i]/)
				{
				&debug ("  Matched var_word " . $var_words[$i]);
				$var_word_score ++;
				}
			}		
		
		if ($var_word_score)
			{
			my $score = ($var_word_score / ($#var_words + 1)) * $weighting;
			$match_score[$index] += $score;
			&debug ("   variant score for variant =" . $bmccar->{variant} . "= is " . $score);
			}
		$index ++;
		}
	}
	
sub score_matching_fueltypes
	{
	my $make = $_[0];
	my $fuel_type = $_[1];
	
	my $weighting = FUELTYPEWEIGHT;
	my @fueltypes = ();
	
	# Now go and find all of the fueltype makes listed in the fueltype alias table, and add them to the array
	my $fuel;
	$fuel = "Petrol" if ($fuel_type =~ m/Non-Turbo Petrol|Turbocharged Petrol|Supercharged|Twincharger/);
	$fuel = "Diesel" if ($fuel_type =~ m/Turbo-Diesel/);
	if (!defined $fuel)
		{
		&screen ("ERROR: Unknown Fuel Type $fuel_type");
		exit;
		}

	$get_fueltype_alias_sth->execute($make, $fuel) or die $dbh->errstr;
	my $aliasfueltype = {};
	while ($aliasfueltype = $get_fueltype_alias_sth->fetchrow_hashref)
		{
		push (@fueltypes, $aliasfueltype->{alias});
		}	

	# if ($#fueltypes == -1)
		# {
		# &debug ("No Fuel Type Aliases found for $make, $fuel");
		# return -1;
		# }
		
	# Now we cycle through each entry in the match_list array
	my $index = 0;
	while ($index <= $#match_list)
		{
		my $bmccar = {};
		$bmccar = $match_list[$index];

		# and we try and match each of the fueltypes with the variant field
		foreach my $j (0 .. $#fueltypes)
			{
			my $variant = $bmccar->{variant};
			$variant =~ s/\s//g;
			if ($variant =~ m/$fueltypes[$j]/i)
				{
				&debug ("Found match for fuel_type $fuel_type with $fueltypes[$j]");
				my $score = $weighting;
				$match_score[$index] += $score;
				&debug ("   fuel_type score for fuel_type $fuel_type with $fueltypes[$j] is " . $score);
				next;
				}
			}
		$index++;
		}
	return 0;
	}
	
sub screen
	{
	my $line = shift;
	say $line;
	&alert ($line);
	}
	
sub alert
	{
	my $line = shift;
	say $alertfh $line;
	&log ($line);
	}
	
sub log
	{
	my $line = shift;
	say $logfh $line;
	&debug ($line);
	}

sub debug
	{
	my $line = shift;
	say $debugfh $line;
	}
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

use utf8;
use English;
use Encode;
use Storable qw(dclone);
use Data::Dumper;
use IO::Handle;
use LWP::Simple;
use Set::Scalar;
use Text::Unidecode;
use TP;
use MatchCars;

use constant MODELCODEWEIGHT =>		15;
use constant VARIANTWEIGHT =>		10;
use constant YEARWEIGHT =>			30;

use constant TOTALWEIGHT => MODELCODEWEIGHT + VARIANTWEIGHT + YEARWEIGHT;

use constant LOWSCORETHRESHOLD => TOTALWEIGHT * 0.5;
use constant CLEARMATCHTHRESHOLD => TOTALWEIGHT * 0.75;
use constant PERFECTMATCHTHRESHOLD => TOTALWEIGHT * 0.9;
use constant CLEARMATCHGAP => TOTALWEIGHT * 0.15;

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
# This selects all rows based on make from BCRacingCoilovers
#
my $get_bccars_by_make_sth = $dbh->prepare("
	SELECT * FROM BCRacingCoilovers WHERE make = ?
") or die $dbh->errstr;

#
# This updates a row in the cars table, setting the bc_racing_coilovers field
#
my $upd_cars_sth = $dbh->prepare("
	UPDATE Cars SET bc_racing_coilovers = ? WHERE idCars = ?
") or die $dbh->errstr;


# Usage: MatchBCRacingCars.pl [MAKE [MODEL]]
# Restrict the main loop query based on the passed command line arguments
my $cars_query = "SELECT * FROM Cars WHERE active = 'Y'";
if (defined $ARGV[0])
{
	$cars_query = "$cars_query AND make like '$ARGV[0]%'";
	if (defined $ARGV[1])
	{
		$cars_query = "$cars_query AND model LIKE '$ARGV[1]%'";
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

my $records_updated = 0;


# This is the main loop. We are going to read through our own Cars table, car by cars
# and then compile a list of possible matches in the BCRacingCoilovers table.
my $car_data = {};
while ($car_data = $sth->fetchrow_hashref)
	{
	@match_list = ();
	@match_score = ();

	############################################################
	# This stuff takes care of statistics for each model_code
	#############################################################
	if ($stats_make ne $car_data->{make} || $stats_model ne $car_data->{model})
		{
		if ($stats_make)
			{
			&log ("Match Stats for $stats_make $stats_model:");
			&log ("  > $stats_perfect Perfect Matches");
			&log ("  > $stats_clear Clear Matches");
			&log ("  > $stats_low Low Scores");
			&log ("  > $stats_cant_decide Can't decide");
			&log ("  > $stats_nomatch Failed to match");


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
	&load_bccars_by_make ($car_data->{make});
	$matches = $#match_list + 1; &debug ("Found $matches Cars that match the make $car_data->{make}");

	&erase_non_matching_models ($car_data->{make}, $car_data->{model}, \@match_list) if $matches;
	$matches = $#match_list + 1; &debug ("Found $matches Cars that match the make $car_data->{make} $car_data->{model}");

	# Now zero out the match score array
	foreach my $i (0 .. scalar (@match_list) - 1)
		{
		push (@match_score, 0);
		}

	if ($matches)
		{
		&score_matching_model_codes ($car_data->{make}, $car_data->{model}, $car_data->{model_code}, 
		 MODELCODEWEIGHT, \@match_list, \@match_score);
		}
	$matches = $#match_list + 1;
	my $list = '';
	if ($matches)
		{
		&debug ("Found $matches Cars that match the model_code $car_data->{model_code}");
		&list_cars ();
		&score_matching_dates ($car_data->{start_date}, $car_data->{end_date}, YEARWEIGHT);
		}
	$matches = $#match_list + 1;


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
		&log (" *** No Matches Found! *** $car_data->{make} $car_data->{model} ($car_data->{model_code})");
		$stats_nomatch ++;
		}

	# If the first match is below the low score threshold, then we have no confidence in the score.
	elsif ($match_score[0] < LOWSCORETHRESHOLD)
		{
		&log (" *** Low Score! ***");
		$stats_low ++;
		}

	# If $#match_list is zero (and to get here, we must be above the low score threshold), then we found exactly one match
	elsif ($#match_list == 0)
		{
		&log (" Perfect Match! :");
		$stats_perfect ++;
		&update_cars_table ($car_data->{idCars}, $match_list[0]->{idBCRacingCoilovers});
		}

	# If we get here, then we have multiple choices, and we have to sort out which ones are genuine, and which aren't
	# Check to see if we had any "perfect" matches
	elsif ($match_score[0] >= PERFECTMATCHTHRESHOLD)
		{
		my $i = 0;
		while ($i <= $#match_list && $match_list[$i] >= PERFECTMATCHTHRESHOLD)
			{
			$i ++;
			&log (" Perfect Match # $i! :");
			}
		if ($i > 1)
			{
			screen ("$i matches for car $car_data->{idCars}");
			}
		$stats_clear ++;
		&update_cars_table ($car_data->{idCars}, $match_list[0]->{idBCRacingCoilovers});
		}

	# So next thing to do is to see if we have a clear winner
	elsif ($match_score[0] > $match_score[1] + CLEARMATCHGAP)
		{
		&log (" Clear Match! :");
		$stats_clear ++;
		&update_cars_table ($car_data->{idCars}, $match_list[0]->{idBCRacingCoilovers});
		}

	# If we get here, then we cant decide between 2 or more different BMC Cars
	# So, we will look at the products, and as long as there is no conflicts in products, then we are good to go!
	else
		{

		}

	my $index = 0;
	while ($index < 5 && $index <= $#match_list)
		{
		my $bmccar = {};
		$bmccar = $match_list[$index];

		&log ("  Score " . sprintf ("%3.1f", $match_score[$index] * 100 / TOTALWEIGHT) . ": BMC CAR =$bmccar->{make}=$bmccar->{model}=($bmccar->{model_code})=$bmccar->{variant}=$bmccar->{hp}=$bmccar->{year}=$bmccar->{capacity}=$bmccar->{cylinders}=");
		$index ++;
		}

	}

if ($stats_make)
	{
	&log ("Match Stats for $stats_make $stats_model:");
	&log ("  > $stats_perfect Perfect Matches");
	&log ("  > $stats_clear Clear Matches");
	&log ("  > $stats_low Low Scores");
	&log ("  > $stats_cant_decide Can't decide");
	&log ("  > $stats_nomatch Failed to match");

	&screen ("There were $records_updated records updated in the cars table");
	}


sub update_cars_table
	{
	my ($car, $bccar) = @_;

#	$upd_cars_sth->execute ($bccar, $car) or die "Could not update Cars table";
	&debug ("Updated Car $car with BC Car $bccar");
	$records_updated ++;
	}


sub list_cars
	{
	my $list = ' >';
	for my $k (0 .. $#match_list)
		{
		$list = $list . $match_list[$k]->{idBCRacingCoilovers} . "(" . $match_score[$k] . ") ";
		}
	&debug ($list);
	}




#############################################################################################
# load_bccars_by_make
# Loads all of the cars in the BMCCars table that match the make (or make alias) of the
# make of the car from the Cars table. It store them in the match_list array
#############################################################################################

sub load_bccars_by_make
	{
	return &load_cars_by_make ($_[0], $get_bccars_by_make_sth, \@match_list);
	}


sub parse_bcracing_date
	{
	my ($year) = @_;
	
	if ($year =~ m/(\d\d)-(\d\d)/)
		{
		debug ("Start Year = $1, End Year = $2");
		}
	if ($year =~ m/(\d\d)\+/)
		{
		debug ("Start Year = $1, End Year = Nothing");
		}
	else
		{
		screen ("Unknown date format: $year");
		}
	
	}


sub score_matching_dates
	{
	my ($start_date, $end_date, $weighting) = @_;

	my $start_year = substr ($start_date, 0, 4);
	my $end_year = substr ($end_date, 0, 4);

	# OK, so from this point on, lets treat the dates as numbers,
	# represnting the number of years since 1970
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
		my $bc_start_year = 0;
		my $bc_end_year = 0;
		my $bccar = {};
		my $date_score;
		$bccar = $match_list[$index];

		# Now check the year and skip if we dont have one
		if (!length $bccar->{year})
			{
			$index ++;
			next;
			}

		&debug ("  BC Year: $bccar->{year} ");
		if ($bccar->{year} =~ m/^(.+)-(.+)$/)
			{
			$bc_start_year = $1;
			$bc_end_year = $2;
			}
		elsif ($bccar->{year} =~ m/^(.+)+$/)
			{
			$bc_start_year = $1;
			#
			# NOTE: Setting this to 20 sets the max year to 2020, which is fine in 2014
			#
			$bc_end_year = 15; # At this point, the BMC dates have not been normalised from 1970, so 50 means 2050
			}
		else
			{
			$bc_start_year = $bccar->{year};
			#
			# NOTE: Setting this to 20 sets the max year to 2020, which is fine in 2014
			#
			$bc_end_year = 15; # At this point, the BMC dates have not been normalised from 1970, so 50 means 2050
			}
		$bc_start_year = $1 if $bc_start_year =~ m/\d{1,2}\/(\d{1,2})/;
		$bc_end_year = $1 if $bc_end_year =~ m/\d{1,2}\/(\d{1,2})/;
		&debug ("Date Range of BCCar: $bc_start_year - $bc_end_year");

		$bc_start_year -= 70; $bc_start_year += 100 if $bc_start_year < 0;
		$bc_end_year -= 70; $bc_end_year += 100 if $bc_end_year < 0;

		&debug ("Date Range of BCCar: $bc_start_year - $bc_end_year");

		# OK, now that the dates have all been parsed and normalised, we can start doing some comparisons
		my $date_range = Set::Scalar->new ($start_year .. $end_year);
		my $bc_date_range = Set::Scalar->new ($bc_start_year .. $bc_end_year);

		&debug ("    date_range = " . $date_range);
		&debug ("    BC date_range = " . $bc_date_range);

		# if the 2 sets are disjoint, then delete this record and move on
		if ($date_range != $bc_date_range)
			{
			splice (@match_list, $index, 1);
			splice (@match_score, $index, 1);
			&debug ("      sets are disjoint, record removed");
			next;
			}

		# if the 2 sets are subset/superset, then score 10 and move on
		if ($date_range <= $bc_date_range || $date_range >= $bc_date_range)
			{
			my $size_diff = abs ($date_range->size - $bc_date_range->size);
			$date_score = $weighting - $size_diff;
			$match_score[$index] += $date_score;
			$index ++;
			&debug ("      sets are subset/superset, score is $date_score");
			next;
			}

		my $intersection = $date_range * $bc_date_range;
		my $union = $date_range + $bc_date_range;

		# If we get here, then we have intersecting sets. So base the score on the
		# amount of intersection

		# If we only have an intersection of 1, but both sets are greater than 1 element long, then
		# it is likely that we have 2 not equal sets such as 02-07 and 07-11.
		if ($intersection->size == 1 && $date_range->size > 1 && $bc_date_range->size > 1)
			{
			splice (@match_list, $index, 1);
			splice (@match_score, $index, 1);
			&debug ("      sets are probably disjoint");
			next;
			}


		my $date_score += ($intersection->size * $weighting) / $union->size;
		$match_score[$index] += $date_score;
		&debug ("      sets are intersecting, score is $date_score");
		$index ++;
		}
	}

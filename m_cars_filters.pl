#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use LWP::Simple;
use Text::Fuzzy;
use POSIX;
use Date::Parse;
use Data::Dumper;


my $url = 'http://au.bmcairfilters.com/ajax/auto.aspx?mod=';
use constant LOGFILE    => "./m_cars_filters.log";
use constant ALERTFILE  => "./m_cars_filters.alert";
use constant DEBUGFILE  => "./m_cars_filters.debug";

my $driver = "mysql";   # Database driver type
my $database = "TP";    # Database name
my $user = "root";      # Database user name
my $password = "";      # Database user password

# 
# Open log/aler/debug files
#
open(my $logfh, ">", LOGFILE)     or die "cannot open LOGFILE $!";
open(my $debugfh, ">", DEBUGFILE) or die "cannot open DEBUGFILE $!";

#
# Connect to database
#
my $dbh = DBI->connect(
"DBI:$driver:$database", $user, $password,
	{
	RaiseError => 1, PrintError => 1, mysql_enable_utf8 => 1
	}
) or die "Cannot connect to database!\n";


#
# prepare the sql statements
# This is for the main loop, we will read every entry with a model code
my $carsth = $dbh->prepare("
	SELECT * FROM Cars WHERE active = 'Y'
") or die $dbh->errstr; #make = 'Audi' AND model_code != ''
$carsth->execute() or die $dbh->errstr;

#
# Now to select a matching entry from model_code
#
#my $selmdlth = $dbh->prepare("
#	SELECT * FROM ModelCodes WHERE make = ? AND model_code = ?
#") or die $dbh->errstr;


#
# Now to select a matching entry from carfilters
#
my $selcfth = $dbh->prepare("
	SELECT * FROM CarFilters WHERE carID = ?
") or die $dbh->errstr;

#
# Insert a new row into CarFilters
#
my $inscfth = $dbh->prepare("
	INSERT into CarFilters (carID) VALUES (?)
") or die $dbh->errstr;

#
# This selects a row based on part from BMCAirFilters
#
my $existsbmcairth = $dbh->prepare("
	SELECT * FROM BMCAirFilters WHERE part = ?
") or die $dbh->errstr;

#
# Insert a new row into BMCAirFilters
#
my $insbmcairth = $dbh->prepare("
	INSERT into BMCAirFilters (part,active) VALUES (?,?)
") or die $dbh->errstr;

my $selmdlth;

#http://au.bmcairfilters.com/ajax/auto.aspx?mod=11680
LP1:
while (my $car = $carsth->fetchrow_hashref)
	{
	my ($content, $modid_url);
	my $filters = {};
	my $carid = $car->{idCars};
	my $make = $car->{make};
	my $model = $car->{model};
	my $model_code = $car->{model_code} || '';
	my $variant_car = $car->{variant} || '';
	my $car_hp = $car->{original_bhp} || 0;
	my $car_start_date = $car->{start_date};
	my $car_end_date = $car->{end_date};
	my $bmc_modid = '';

	print "Car: $carid : $make : $model : $model_code : $variant_car : $car_hp : $car_start_date to $car_end_date\n";
	print $logfh "Car: $carid : $make : $model : $model_code : $variant_car : $car_hp : $car_start_date to $car_end_date\n";

	# if model_codes exists then pull data based on that
	if ($model_code)
		{
		$selmdlth = $dbh->prepare("
			SELECT * FROM ModelCodes WHERE make = ? AND model_code = ?
		") or die $dbh->errstr;
		$selmdlth->execute($make,$model_code) or die $dbh->errstr;
		}
	# pull from ModelCode based on make &model	
	else
		{
		$selmdlth = $dbh->prepare("
		SELECT * FROM ModelCodes WHERE make = ? AND model = ?
		") or die $dbh->errstr;
		$selmdlth->execute($make,$model) or die $dbh->errstr;	
		}	

	if (my $mc = $selmdlth->fetchrow_hashref())
		{
		# if modid is nor present in this row	
		unless (defined($mc->{modID}))
			{
			print "\n\tCould not find modid in ModelCodes table row $make:$model:$model_code: $mc->{BMCModel}\n\n";		
			print $debugfh "\n\tCould not find modid in ModelCodes table row $make:$model:$model_code: $mc->{BMCModel}\n\n";	
			goto LP1;
			}
		$bmc_modid = $mc->{modID};
		}
	else
		{
		print "Could not find this row in ModelCodes table $make:$model:$model_code\n";	
		print $debugfh "Could not find this row in ModelCodes table $make:$model:$model_code\n";
		next;
		}	

	$filters = &findCar($variant_car,$car_hp,$car_start_date,$car_end_date,$bmc_modid,$url);

	if (%{$filters})
		{
		# add carid to CarFilters table if not exists	
		$selcfth->execute($carid) or die $dbh->errstr;
		$inscfth->execute($carid) unless ($selcfth->fetchrow_hashref());

		my $f_code = '';
		for my $k (sort keys $filters)
			{
			# taking the filter which has upmost matchscore among others
			my $f_code = (sort  { $filters->{$k}->{$b} <=> $filters->{$k}->{$a} } keys %{ $filters->{$k} })[0];


			print $f_code . "\n"; # further removed

			$f_code =~ s/.*?::(.*)/$1/gi;

			

			#
			# Update existing row into model_code
			#
			my $updcfth = $dbh->prepare("
				UPDATE CarFilters SET $k = ? WHERE carID = ?
				") or die $dbh->errstr;

			
			# select a row from BMCAirFilter if any
			$existsbmcairth->execute($f_code) or die $dbh->errstr;
			if (my $bmccars = $existsbmcairth->fetchrow_hashref())
				{
				# updating carfilters with new filter part_ids	
				$updcfth->execute($bmccars->{part_id},$carid) or die $dbh->errstr;	
				print "\tUpdating carfilters with part_id of $k => $f_code\n";	
				print $logfh "\tUpdating carfilters with part_id of $k => $f_code\n";
				}
			else
				{
				# adding this filter code to BMCAirFilter table	
				$insbmcairth->execute($f_code,"Y") or die $dbh->errstr;
				print "\tAdd new filter code into BMCAirFilter table: $f_code\n";
				print $logfh "\tAdd new filter code into BMCAirFilter table: $f_code\n";
				}	
			#printf "\t%s %-50s %+5s\n", $k, $mod_code;	
			}
		}
	# no carfilters selected for this item	
	else
		{
		next LP1;	
		}		
		
	}

close $logfh;
close $debugfh;


##############################################
############  End of main program  ###########
##############################################


sub findCar
######################################
#
# returns the best matched bmc filter
#
######################################
{
	my ($variant_car, $hp_car, $car_start_date, $car_end_date, $mod, $url) = @_;
	my ($content,$selected_div,$selected_tr) = ('')x3;	
	my ($hp_score, $diff, $date_score, $match_score, $variant_score);
	my ($hp_bmc, $f_type, $cda, $first_hp_diff, $second_hp_diff);
	my $variant_bmc = '';
	my $year_bmc    = 0 ;
	my $code_bmc    = '';
	my @data;
	my %matches = ();
	my @ids = split ':', $mod;

	# looping through mod_ids
	for my $mdid (@ids) 
		{
		next if $mdid eq '';		
		my $modid_url = $url . $mdid;

		my $retries = 5;
		# Try more times in case of failure
		while ($retries && !($content .= get $modid_url))
			{
			$retries --;
			}
		die "Couldn't get $url" if (!$retries);		
		
		}


	while ($content =~ /id="model-table"(.*?)<\/div>/sgi)
		{
		$selected_div = $1;
		# CRF :: CARBON RACING FILTERS
		if ($selected_div =~ /CARBON RACING FILTERS/i)	
			{
			$f_type = 'CRF';	
			}
		# CR :: CAR FILTERS	
		elsif ($selected_div =~ /CAR FILTERS/i)	
			{
			$f_type = 'CR';		
			}
		# OTA :: OVAL TRUMPET AIRBOX	
		elsif ($selected_div =~ /OVAL TRUMPET AIRBOX/i)	
			{
			$f_type = 'OTA';		
			}
		# CDA :: CARBON DYNAMIC AIRBOX	
		elsif ($selected_div =~ /CARBON DYNAMIC AIRBOX/i)
			{
			$f_type = 'CDA';
			}	
		# SPK :: SPECIFIC KITS	
		elsif ($selected_div =~ /SPECIFIC KITS/i)
			{
			$f_type = 'SPK';
			}	
		# anything else	..
		else
			{
			print $debugfh "New type of data: $selected_div\n";	
			next;	
			}	
		
		while ($selected_div =~/<tr>(.*?)<\/tr>/sgi) 
			{
			$selected_tr = $1;
			@data = ();
			$hp_score   = 0;
			$hp_bmc     = 0;
			$date_score = 0;
			$match_score= 0;
			$variant_score=0;
			#
			# collecting bmc data from table
			while ($selected_tr =~ /<td.*?>(.*?)<\/td>/sgi)
				{
				push @data, $1;
				}
			if (@data) 
				{
				if ($f_type eq 'CDA')	
					{
					# skip if inadequate data for CDA extraction	
					next if scalar @data < 3;
					$cda = $data[0];
					$code_bmc = $data[2];
					#
					# expected data from CDA
					#
					if ($cda =~ /(.*?)(\d+)\s?(HP\s+)?(\d+?\s?>\s?(\d+)?)/i)
						{
						$variant_bmc = $1;
						$hp_bmc    ||= $2;
						$year_bmc    = $4;
						$code_bmc =~ s/<a.*?>(.*?)<\/a>/$1/g;
						}
					else
						{
						print "bad CDA data: $cda\n";	
						print $debugfh "bad CDA data $cda\n";
						next;		
						}	
					}
				else
					{
					# taking desired data from the bmc site	
					$variant_bmc = $data[0];
					$hp_bmc      = $data[1] || 0;
					$year_bmc    = $data[2];
					$code_bmc    = $data[6];
					$code_bmc =~ s/<a.*?>(.*?)<\/a>/$1/g;
					}

				#
				# hp matching score
				#
				# if 124/126 case
				# chose the closest hp
				if ($hp_bmc =~ /(\d+)\s?\/\s?(\d+)/)
					{
					$first_hp_diff = abs($hp_car - $1);
					$second_hp_diff = abs($hp_car - $2); 	
					$diff = ( $first_hp_diff > $second_hp_diff ? $second_hp_diff : $first_hp_diff);	
					}
				else
					{
					$diff = abs($hp_car - $hp_bmc);	
					}	
	
				# skip if hps are too different
				next if $diff > 10;

				if ($diff < 10)
					{
					$hp_score = 100 - ($diff * 10);
					$match_score += $hp_score;
					}
				
				#
				# dates matching score
				#	
				$date_score = &compare_dates($car_start_date, $car_end_date, $year_bmc);

				# skip if years do not overlap at all
				next if $date_score == 1;	
				$match_score += $date_score;

				#
				# variant matching score
				#
				if($variant_car =~ /(\d+(\.\d+)?)/)
					{
					my $m = $1;
					if($variant_bmc =~ /$m/)
						{
						$variant_score = 100;	
						}
					$match_score += $variant_score;	
					}

				if (int($match_score) >= 90) 
					{
					my $hash_string = "$variant_bmc : $hp_bmc : $year_bmc :$match_score ::$code_bmc";
					$matches{$f_type}{$hash_string} = int($match_score);
					}

				}
				
			}
				
		}
	return \%matches;
}


	
sub compare_dates 
####################################
#
# This sub compares dates and returns
# score based on fuzzy matching
#
####################################
	{
	my ($car_start_date, $car_end_date, $bmc_year) = @_;
	
	my $car_start_year = substr ($car_start_date, 0, 4);
	my $car_end_year = substr ($car_end_date, 0, 4);
	my $bmc_start_year = 0;
	my $bmc_end_year = 0;
	my $gooddate = 0;
	my $date_score = 0;

	$bmc_year =~ s/ //g;
	
	if ($bmc_year =~ /^(\d{2})>(\d{2})$/)
		{
		$bmc_start_year = $1;
		$bmc_end_year = $2;
		$gooddate = 1;
		}

	if ($bmc_year =~ /^>(\d{2})$/)
		{
		$bmc_start_year = 70;
		$bmc_end_year = $1;
		$gooddate = 1;
		}

	if ($bmc_year =~ /^(\d{2})>$/)
		{
		$bmc_start_year = $1;
		$bmc_end_year = 50;
		$gooddate = 1;
		}
	if ($car_end_year < 1)	
		{
		$car_end_year +=2050;	
		}

	if (!$gooddate)
		{
		#say "Unrecognised Date Format: $bmc_year";
		return 0;
		}

	if ($bmc_start_year < 50)
		{
		$bmc_start_year += 2000;
		}
	else
		{
		$bmc_start_year += 1900;
		}
		
	if ($bmc_end_year <= 50)
		{
		$bmc_end_year += 2000;
		}
	else
		{
		$bmc_end_year += 1900;
		}
	
	# Now see if the car dates are within or equal to the filter dates
	$date_score  = &dateCheck($car_start_year,$car_end_year, $bmc_start_year, $bmc_end_year);
	return $date_score;
	}



sub dateCheck
####################################
#
# helper sub for &compare_dates 
#
####################################
	{
	my ($car_start, $car_end, $bmc_start, $bmc_end) = @_;
	my $car_date_range = $car_end - $car_start+1;
	my $score = 0;

	if (($bmc_start >= $car_start) && ($bmc_end <= $car_end))
		{
		$score = 100;
		}
	elsif (($bmc_start >= $car_start) && ($bmc_start <= $car_end) && ($bmc_end > $car_end))
		{
		$score = (($car_end - $bmc_start+1)*100)/$car_date_range;
		}
	elsif (($bmc_start < $car_start) && ($bmc_end <= $car_end) && ($bmc_end >= $car_start))
		{
		if ($car_end == 2050 && $bmc_end != 2050)	
			{
			$score = (($bmc_end - $car_start+1)*100)/10;	
			}
		else
			{
			$score = (($bmc_end - $car_start+1)*100)/$car_date_range;	
			}	
		}
	elsif (($bmc_start < $car_start) && ($bmc_end > $car_end))
		{
		$score = 90;
		}
	elsif ($bmc_end < $car_start || $bmc_start > $car_end)
		{
		# this is just a flag 
		$score = 1;	
		}	
	
	return int($score);	
	}


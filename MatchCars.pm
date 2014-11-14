#!/usr/bin/perl
##############################################################################
# Package of TigersoftPerformance subroutines
#
##############################################################################

package MatchCars;


require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( load_cars_by_make erase_non_matching_models score_matching_model_codes);



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


#############################################################################################
# load_cars_by_make
# Loads all of the cars in the BMCCars table that match the make (or make alias) of the
# make of the car from the Cars table. It store them in the match_list array
#############################################################################################

sub load_cars_by_make
	{
	my ($make, $get_car_h, $match_list) = @_;
	
	# Create a makes array, and store the passed make as the first element
	my @makes = ();
	push (@makes, $make);

	# Now go and find all of the alias makes listed in the make alias table, and add them to the array
	$get_make_alias_sth->execute($make) or die $dbh->errstr;
	my $aliasmake = {};
	while ($aliasmake = $get_make_alias_sth->fetchrow_hashref)
		{
		push (@makes, $aliasmake->{alias});
		}

	# Now that we have our array of makes and make alias', find all of the matching cars in the
	# BMCCars table and store the hashref to them in the match_list array
	foreach (@makes)
		{
		$get_car_h->execute($_) or die $dbh->errstr;
		my $cars = {};
		while ($cars = $get_car_h->fetchrow_hashref)
			{
			push (@$match_list, $cars);
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
	my ($make, $model, $match_list) = @_;

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
	while ($index < scalar (@$match_list))
		{
		my $car = @$match_list[$index];

		my $match_found = 0;
		# and we try and match each each of the models or model alias' with the model field
		foreach my $j (0 .. scalar (@models) - 1)
			{
			if ($car->{model} =~ m/$models[$j]/i)
				{
				$match_found = 1;
				last;
				}
			}
		# and then if we don't find a match, then we delete this entry
		if (!$match_found)
			{
			splice (@$match_list, $index, 1);
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
	my ($make, $model, $model_code, $weighting, $match_list, $match_score) = @_;

	my $any_matches = 0;

	# If the passed model_code is null, then just return without trying to match anything.
	if (!length $model_code)
		{
		return;
		}

	# Create an array of model_codes, and load the passed model_code, and the list of model_code aliases.
	my @model_codes = ();

	$get_modelcode_alias_sth->execute($make, $model, $model_code) or die $dbh->errstr;
	my $aliasmodelcode = {};
	while ($aliasmodelcode = $get_modelcode_alias_sth->fetchrow_hashref)
		{
		if (defined $aliasmodelcode->{alias} && length ($aliasmodelcode->{alias}))
			{
			push (@model_codes, $aliasmodelcode->{alias});
			#debug ("Found Alias $aliasmodelcode->{alias}");
			}
		}

	# Now, if we didn't find any aliases, then just load up the passed model_code(s)
	my $alias_count = scalar (@model_codes) + 1;
	#debug ("There were $alias_count aliases found");
	if (!$alias_count)
		{
		#debug ("There were $alias_count aliases found, loading up passed records");
		if ($model_code =~ m/^(.+)\s*\/\s*(.+)$/)
			{
			push (@model_codes, $1);
			push (@model_codes, $2);
			}
		else
			{
			push (@model_codes, $model_code);
			}
		}

	# Now we cycle through each entry in the match_list array
	my $index = 0;
	while ($index < scalar (@$match_list))
		{
		my $car = {};
		$car = @$match_list[$index];

		# and we try and match each of the model_codes or model_code alias' with BOTH
		# the model field and the model_code field
		my $match_found = 0;
		foreach my $j (0 .. scalar (@model_codes) - 1)
			{
			if ($car->{model} =~ m/$model_codes[$j]/i || $car->{model_code} =~ m/$model_codes[$j]/i)
				{
				#&debug ("Found match for model code $model_codes[$j]");
				$match_found = 1;
				$any_matches = 1;
				last;
				}
			}
		# and then if we find a match, then give this entry a 10
		if ($match_found)
			{
			@$match_score[$index] += $weighting;
			}
		$index ++;
		}

	# if we found any matches, then go and remove any that didn't match
	if ($any_matches)
		{
		$index = 0;

		#debug ("There were matches found, so we now delete unwanted models");
		while ($index < scalar (@$match_list))
			{
			my $car = {};
			$car = @$match_list[$index];
			#&debug ("index = $index, model = $match_list[$index]->{model}, model_code = $match_list[$index]->{model_code}");
			# and we try and match each of the model_codes or model_code alias' with BOTH
			# the model field and the model_code field
			my $match_found = 0;
			foreach my $j (0 .. scalar (@model_codes) - 1)
				{
				if ($car->{model} =~ m/$model_codes[$j]/i || $car->{model_code} =~ m/$model_codes[$j]/i)
					{
					#&debug ("Match Found! index = $index, model = $match_list[$index]->{model}, model_code = $match_list[$index]->{model_code}, searching for $model_codes[$j]");
					$match_found = 1;
					last;
					}
				}

			if (!$match_found)
				{
				#&debug ("removing Record with model_code $match_list[$index]->{model_code}");
				splice (@$match_list, $index, 1);
				splice (@$match_score, $index, 1);
				next;
				}
			$index ++;

			}
		}
	}
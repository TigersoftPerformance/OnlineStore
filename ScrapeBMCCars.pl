#!/usr/bin/perl -w
#####################################################################################
# Scrape BMC Website script - John Robinson, August 2014
# First of all, it scrapes all of the Cars that it can find from the website
# And then scrapes all of the products and category information
# There are 3 tables used in the database:
# BMCCars holds all of the information about the cars described on the BMC Website
# BMCProducts holds all of the information about the products listed
# BMCFitment holds the relationships between Cars and Products.
####################################################################################
use strict;
use DBI;
use LWP::Simple;
use feature 'say';
use WWW::Mechanize::Firefox;
use Text::Unidecode;
use utf8;
use English;
use Encode;
use IO::Handle;

my $url = 'http://au.bmcairfilters.com';

use constant LOGFILE    => "./Logs/ScrapeBMCCars.log";
use constant ALERTFILE  => "./Logs/ScrapeBMCCars.alert";
use constant DEBUGFILE  => "./Logs/ScrapeBMCCars.debug";

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
# Load record from BMC Cars Table
#
my $get_bmc_car_sth = $dbh->prepare("
	SELECT * FROM BMCCars WHERE make = ? AND model = ?
	 AND model_code = ? AND variant = ? AND hp = ? AND year = ?
") or die $dbh->errstr;

#
# Insert new record into BMC Cars Table
#
my $ins_bmc_car_sth = $dbh->prepare("
	REPLACE INTO BMCCars SET make = ?, model = ?, model_code = ?, variant = ?, 
	 hp = ?, year = ?, cylinders = ?, capacity = ?, engine_code = ?, filter_shape = ?, mounting_note = ?, active = 'Y'
") or die $dbh->errstr;

#
# Load record from BMC Products Table
#
my $get_bmc_prod_sth = $dbh->prepare("
	SELECT * FROM BMCProducts WHERE bmc_part_id = ?
") or die $dbh->errstr;

#
# Add a dummy record to BMC Products Table
#
my $ins_bmc_prod_sth = $dbh->prepare("
	INSERT IGNORE INTO BMCProducts SET bmc_part_id = ?, product_url = ?, type = ?, active = 'Y'
") or die $dbh->errstr;

#
# get a joining record from BMC fitment Table
#
my $get_bmc_fitment_sth = $dbh->prepare("
	SELECT * FROM BMCFitment WHERE BMCCars_idBMCCars = ? AND BMCProducts_bmc_part_id = ?
") or die $dbh->errstr;

#
# Add a joining record to BMC fitment Table
#
my $ins_bmc_fitment_sth = $dbh->prepare("
	INSERT IGNORE INTO BMCFitment SET BMCCars_idBMCCars = ?, BMCProducts_bmc_part_id = ?
") or die $dbh->errstr;


#######################################################################
# Code starts here
#######################################################################

my $mech = WWW::Mechanize::Firefox->new();
my ($makeid,$make,$modelid, $model);
my $content;

# This will get the front page of the website
# Try a few times in case of failure
my $retries = 5;
while ($retries && !($content = decode_utf8 (get $url)))
	{
	$retries --;
	}
die "Couldn't get $url" if (!$retries);
$content = decode_utf8 ($content);

#
# collecting makeid for all makes
#
$content =~ /<option value="0">(.*?)<\/select>/s;
my $temp1 = $1;

#
# looping through each makeids
#
while ($temp1 =~ /<option value="(\d+)">(.*?)<\/option>/gi)
	{
	$makeid = $1;
	$make  = $2;	
	&log ("make: $make", " => $makeid");

	#
	# This is where we get the content from the wesbite for the specific make
	#
	my $make_url = 'http://au.bmcairfilters.com/search_a.aspx?marca=' . $makeid . '&lng=2';
	# Try a few times in case of failure
	$retries = 5;
	while ($retries && !($mech->get($make_url)))
		{
		$retries --;
		}
	die "Couldn't get $make_url" if (!$retries);	

	#
	# get makeids content to get modids
	#
	my $makeid_content;
	my $time_delay = 0.2;
	$retries = 5;
	my $model_list = '';
	while ($retries && $model_list !~ m/option value/)
		{
		select(undef, undef, undef, $time_delay);
		$makeid_content = decode_utf8 ($mech->content());
		$makeid_content =~ m/id="ComboModelli" name="ComboModelli"><(.*?)<\/select>/s;
		$model_list = $1;
		$retries--;
		$time_delay *= 2;
		}
	if ($model_list !~ m/option value/)
		{
		&alert ("WARNING: Could not find model information for make $make");
		&alert (" URL is $make_url");
		next;
		}
	$makeid_content =~ s/,/&#44;/g;

	#
	# Now loop through the page looking for all of the models listed for this make
	# Note that the list on the website is populated via some ajax calls, which is why
	# Dave used Firefox::Mechanize
	#
	while ($model_list =~ /<option value="(\d+)">(.*?)\s*<\/option>/gi)
		{
		$modelid = $1;
		$model = $2;
		&log (" >model: $model", " => $modelid");
		
		my $model_url = 'http://au.bmcairfilters.com/search_a.aspx?marca=' . $makeid . '&mod=' . $modelid . '&lng=2';
		# Try a few times in case of failure
		$retries = 5;
		while ($retries && !($mech->get($model_url)))
			{
			$retries --;
			}
		die "Couldn't get $model_url" if (!$retries);	
		
		#
		# Now go and get the page for the specified model
		#
		my $modelid_content = '';
		my $time_delay = 0.2;
		my $retries = 5;
		while ($retries && $modelid_content !~ m/table class="gradient-style2"/)
			{
			select(undef, undef, undef, $time_delay);
			$modelid_content = decode_utf8 ($mech->content());
			$retries--;
			$time_delay *= 2;
			}
		if ($modelid_content !~ m/table class="gradient-style2"/)
			{
			&alert ("WARNING: Could not find Product Tables for model $make $model");
			&alert (" URL is $model_url");
			next;
			}
		$modelid_content =~ s/,/&#44;/g;
		
		# Scan the page for tables of variants of the specified model 
		# There will be one table per BMC product. 
		# The table will have the product type (eg CAR FILTERS, or CDA - CARBON DYNAMIC AIRBOX)
		# within <strong> tags and then the table will follow
		while ($modelid_content =~ /<strong>(.*?)<\/strong>.*?<table class="gradient-style2"(.*?)<\/table>/sg)
			{
			my $product_type = $1, my $model_table = $2;
			&debug ("  >Found table for $product_type");
			
			# so now we have just the structure of one table with its product type, 
			# so we can parse the table header to see what columns we are dealing with.
			# Need to come up with a strategy for dealing with these better than just counting them
			my $table_header = $1 if $model_table =~ /<thead>(.*?)<\/thead/sg;
			last if (!defined $table_header);
			my @column_names = ();
			while ($table_header =~ /<th scope="col">(.*?)<\/th>/sg)
				{
				push (@column_names, $1);
				}
			

			# Now we have to read each row of data from the table
			# first thing is to isolate just the table data
			my $table_data = $1 if $model_table =~ /<tbody>(.*?)<\/tbody/sg;
			last if (!defined $table_data);
			my @column_values = ();
			# Now loop through each row in the table. There is one row per variant
			while ($table_data =~ /<tr>(.*?)<\/tr>/sg)
				{
				my $table_row = $1;
				@column_values = ();
				while ($table_row =~ /<td.*?>(.*?)<\/td>/sg)
					{
					push (@column_values, $1);
					}
				&add_new_variant ($make, $model, $product_type, \@column_names, \@column_values);
				}
			}
		}
	}

########################################################################
# add_new_variant sub
# this routine takes a single row that has been taken from the BMC 
# product table (eg; the table for CAR FILTERS), and creates corresponding
# database entries: 1 for the variant, one for the product and one for
# the joiner table.
# It uses a global variable '$previous_variant' to cater for a peculiarity 
# of the CDA table listing. It will sometimes list extra accessories for
# each variant, but subsequent rows do not repeat the variant information,
# so we need to keep track of it manually
########################################################################

my $previous_variant;
sub add_new_variant
	{
	my $make = $_[0];
	my $model = $_[1];
	my $product_type = $_[2];
	my @column_names = @{$_[3]};
	my @column_values = @{$_[4]};
	
	# Column Names for CDA - CARBON DYNAMIC AIRBOX are:
	# Model, Mounting Note, Components List
	# So 3 columns in total
	if ($product_type eq "CDA - CARBON DYNAMIC AIRBOX")
		{
		my $variant;
		my $bmc_part_id;
		my $bmc_part_url;
		my $mounting_note;
		
		# CDA tables are peculiar in that a row can either have 2 or 3 columns. 
		# Those rows with 2 columns are to list additional accessories to go with the abovementioned CDA
		# but the row only contains the part_id of the accessory part, and not the variant. As such, we
		# need to remember what the previous variant was.
		if (scalar (@column_names) != 3 || (scalar (@column_values) != 3 && scalar (@column_values) != 2))
			{
			&wrong_columns ($product_type, \@column_names, \@column_values);
			return -1;
			}
		if (scalar (@column_values) == 2)
			{
			$variant = $previous_variant;
			$bmc_part_id = $column_values[1];
			$mounting_note = '';
			$product_type = "BMC ACCESSORIES";			
			}
		else
			{
			$previous_variant = $column_values[0];
			$variant = $column_values[0];
			$mounting_note = $column_values[1];
			$bmc_part_id = $column_values[2];
			}
		
		if ($bmc_part_id =~ m/<a href=\"(.*?)\".*?>(.*?)<\/a/)
			{
			$bmc_part_url = $1;
			$bmc_part_id = $2;
			}
		else
			{
			&screen ("ERROR: I Don't recognise this BMC Part ID: $bmc_part_id");
			}
			
			
		# Also peculiar about the CDA listing is that the variant information such as hp and year
		# is stuck on the end of the variant rather than being listed separately as with all other 
		# products. So we must parse the variant string to extract the sub-variant, hp and year.
		# of course, BMC has not done this consistently, so we need to try several different patterns
		# to see which one matches
		
		my $sub_variant = '';
		my $dateless_variant = '';
		my $hp = '';
		my $year = '';
		# first, let's see if the year is actually specified on the end of the string, and if so, 
		# lets get it and strip it from the remaining string. 
		# Could be in the following formats: '11 &gt; 22', '11 &gt;', '11', or it may not be there.
		if ($variant =~ m/(.*)(\d{2} &gt;.*)$/)
			{
			$dateless_variant = $1;
			$year = $2;
			}
		elsif ($variant =~ m/(.*)(\d{2})$/)
			{
			$dateless_variant = $1;
			$year = $2;
			}
		else
			{
			$dateless_variant = $1;
			$year = '';
			}
		$year =~ s/ +//g;
		$variant = $dateless_variant;
		
		# If the last word now is HP, then we know for sure that the previous word is the HP
		if ($variant =~ m/(.*) (\S+)\s*HP\s*$/)
			{
			$sub_variant = $1;
			$hp = $2;
			}
		# Otherwise we are going to assume the HP figure can only be digits or a / char
		# The / char means technically this is 2 different cars, and should really be split
		elsif ($variant =~ m/(.*) ([\/\d][\/\d]+)\s*$/)
			{
			$sub_variant = $1;
			$hp = $2;
			}
		else
			{
			$sub_variant = $variant;
			$hp = '';
			}
			

		# Now that we have parsed all of the input, we can now write the records to the database
		# and return
		&add_cars_to_database ($make, $model, '', $sub_variant, $hp, $year, '', '',
		 $bmc_part_id, $bmc_part_url, $product_type, $mounting_note);
		return 0;
		}
	else
		{
		$previous_variant = '';
		}

	# Column Names for CAR FILTERS, OTA - OVAL TRUMPET AIRBOX, 
	# CRF - CARBON RACING FILTERS - CARS, CRF - CARBON RACING FILTERS - BIKES, 
	# STANDARD BIKE FILTERS, RACE BIKE FILTERS and SPECIFIC KITS are:
	# Model, HP, Year, ID/Chassis, Engine Code, Shape, Code
	# So 7 columns in total
	if ($product_type =~ 
	 m/CAR FILTERS|OTA - OVAL TRUMPET AIRBOX|CRF - CARBON RACING FILTERS - CARS|CRF - CARBON RACING FILTERS - BIKES|SPECIFIC KITS|STANDARD BIKE FILTERS|RACE BIKE FILTERS/)
		{
		if (scalar (@column_names) != 7 || scalar (@column_values) != 7)
			{
			&wrong_columns ($product_type, \@column_names, \@column_values);
			return -1;
			}
		# Get the bmc_part_id from the <a> tags in col 6
		my $bmc_part_id;
		my $bmc_part_url;
		if ($column_values[6] =~ m/<a href=\"(.*?)\".*?>(.*?)<\/a/)
			{
			$bmc_part_url = $1;
			$bmc_part_id = $2;
			}
		else
			{
			&screen ("ERROR: I Don't recognise this BMC Part ID: $bmc_part_id");
			}
		
		# remove spaces from the year
		$column_values[2] =~ s/ +//g;
		
		# Check to see if the model_code is in the model, and if it is, remove it
		if ($model =~ m/(^.*)\s*\($column_values[3]\)(.*$)/)
			{
			$model = $1.$2;
			}
		$model =~ s/ +$//;
		
		&add_cars_to_database ($make, $model, $column_values[3], $column_values[0], $column_values[1], $column_values[2],
		 $column_values[4], $column_values[5], $bmc_part_id, $bmc_part_url, $product_type, '');
		return 0;
		}
	# I put this here during testing, but all going well we should never get here.
	&alert ("ERROR! Unknown Product Type!");
	&alert ("$product_type");
	&alert ("---------------------------------");
	&alert ("@column_names\n");
	&alert ("---------------------------------");
	&alert ("@column_values\n");
	&alert ("---------------------------------");
	return -1;
	}
	
# Wrong Columns was a sub written during alpha testing. Hopefully, it will never get called. 
sub wrong_columns
	{
	my $product_type = $_[0];
	my @column_names = @{$_[1]};
	my @column_values = @{$_[2]};
	
	&alert ("ERROR! Mismatch of Columns!");
	&alert ("$product_type");
	&alert ("---------------------------------");
	&alert ("@column_names\n");
	&alert ("---------------------------------");
	&alert ("@column_values\n");
	&alert ("---------------------------------");
	return -1;
	}


#########################################################################################################
# Sub add_cars_to_database
# We need to put in this sub to take care of multiple cars specified on the same line
# eg, where hp is specified as 140/150, then 2 cars need to be created.
#########################################################################################################
sub add_cars_to_database
	{
	my ($make, $model, $model_code, $variant, $hp, $year, 
	 $engine_code, $filter_shape, $bmc_part_id, $bmc_part_url, $product_type, $mounting_note) = @_;

	$hp = &tidy_field ($hp);
	$hp =~ s/\s+//g;

	# If the HP field is a single number, or it is empty, then just write it as is. 
	if ($hp =~ m/^\d+$/ || !length ($hp))
		{
		&add_car_to_database ($make, $model, $model_code, $variant, $hp, $year,
		 $engine_code, $filter_shape, $bmc_part_id, $bmc_part_url, $product_type, $mounting_note);
		return 0;
		}
	my $iterations = 0;
	while ($hp =~ m/(\d+)/g)
		{
		my $hp1 = $1; 
		&add_car_to_database ($make, $model, $model_code, $variant, $hp1, $year,
		 $engine_code, $filter_shape, $bmc_part_id, $bmc_part_url, $product_type, $mounting_note);
		$iterations ++;
		}
	if ($iterations)
		{
		return 0;
		}
	else
		{
		&screen ("ERROR: I Don't recognise this HP figure: $hp");
		return -1;
		}
	}



#########################################################################################################
# Sub add_car_to_database
# This sub takes the information that we parsed from the BMC product table row, and creates or updates the appropriate
# database records
#########################################################################################################
sub add_car_to_database
	{
	my ($make, $model, $model_code, $variant, $hp, $year, 
	 $engine_code, $filter_shape, $bmc_part_id, $bmc_part_url, $product_type, $mounting_note) = @_;
	my $update_required = 1;
	

	# First thing to do is to tidy up the data a little. First of all remove all trailing spaces, leading spaces,
	# and multiple spaces.
	$make = &tidy_field ($make);
	$model = &tidy_field ($model);
	$model_code = &tidy_field ($model_code);
	$variant = &tidy_field ($variant);
	$hp = &tidy_field ($hp);
	$year = &tidy_field ($year);
	$engine_code = &tidy_field ($engine_code);
	$filter_shape = &tidy_field ($filter_shape);
	$bmc_part_id = &tidy_field ($bmc_part_id);
	# $product_type = &tidy_field ($product_type);
	# $mounting_note = &tidy_field ($mounting_note);
	
	# Now see what we can derive from the variant
	my $capacity = $1 if $variant =~ m/(\d\.\d)/;


	# To figure out how many cylinders, we can try 3 different things
	# First, see if we can derive it from the number of valves
	my $valves = 0; $valves = $1 if $variant =~ m/(\d{1,2})V/i;
	my $cylinders = '';
	if ($valves == 8) { $cylinders = 4; }
	elsif ($valves == 12) { $cylinders = 0; } # Could be 3, 4 or 6. Need to look at this further
	elsif ($valves == 16) { $cylinders = 4; } 
	elsif ($valves == 20) { $cylinders = 0; } # Could be 4 or 5. Need to look at this further
	elsif ($valves == 24) { $cylinders = 6; } 
	elsif ($valves == 32) { $cylinders = 8; } 
	
	# Next, see if the variant contains V6, V8 etc
	if ($variant =~ m/v6/i) { $cylinders = 6; }
	elsif ($variant =~ m/v8/i) { $cylinders = 8; }
	elsif ($variant =~ m/v10/i) { $cylinders = 10; }
	elsif ($variant =~ m/v12/i) { $cylinders = 12; }
	
	# Lastly, see if the number of cylinders has been specified explicitly
	$cylinders = $1 if $variant =~ m/(\d) *cyl/i;

	# See if that car already exists in the database by reading it.
	$get_bmc_car_sth->execute ($make, $model, $model_code, $variant, $hp, $year) or die $dbh->errstr;
	my $bmccar = $get_bmc_car_sth->fetchrow_hashref;
	
	# if the record did already exist, then just check to see if any of the none-primary key fields have been 
	# updated, and if they have, then we will rewrite the record to the database.
	if (defined $bmccar->{make})
		{
		$update_required = 0;
		if (length($engine_code) > length($bmccar->{engine_code}))
			{
			&alert ("   >CHANGE: Engine Code is different :$engine_code:$bmccar->{engine_code}:");
			$update_required = 1;
			}
		else
			{
			$engine_code = $bmccar->{engine_code};
			}

		if (length($filter_shape) > length($bmccar->{filter_shape}))
			{
			&alert ("   >CHANGE: filter_shape is different :$filter_shape:$bmccar->{filter_shape}:");
			$update_required = 1;
			}
		else
			{
			$filter_shape = $bmccar->{filter_shape};
			}
		
		if (length($mounting_note) > length($bmccar->{mounting_note}))
			{
			&alert ("   >CHANGE: mounting_note is different :$mounting_note:$bmccar->{mounting_note}:");
			$update_required = 1;
			}
		else
			{
			$mounting_note = $bmccar->{mounting_note};
			}

		if ($capacity && !$bmccar->{capacity})
			{
			&alert ("   >CHANGE: capacity is different :$capacity:$bmccar->{capacity}:");
			$update_required = 1;
			}
		else
			{
			$capacity = $bmccar->{capacity};
			}
			
		if ($cylinders && !$bmccar->{cylinders})
			{
			&alert ("   >CHANGE: cylinders is different :$cylinders:$bmccar->{cylinders}:");
			$update_required = 1;
			}
		else
			{
			$cylinders = $bmccar->{cylinders};
			}
			
		}
		
	if (!defined $bmccar->{make} || $update_required)
		{
		# So to get here, either there was a record for this variant in the BMCCars tables
		# and it needs to be updated, or this is a new record. Either way, write it.
		$ins_bmc_car_sth->execute ($make, $model, $model_code, $variant, $hp,
		 $year, $cylinders, $capacity, $engine_code, $filter_shape, $mounting_note) or die $dbh->errstr;
		&screen ("    >NEW CAR! :$make:$model:$model_code:$variant: HP :$hp: Year :$year:");
		}
		
	 
	# and then read it straight back again to get the carid.
	undef $bmccar;
	my $retries = 5;
	while ($retries && !defined $bmccar)
		{
		$get_bmc_car_sth->execute ($make, $model, $model_code, $variant, $hp, $year) or die $dbh->errstr;
		$bmccar = $get_bmc_car_sth->fetchrow_hashref;
		$retries --;
		}
	if (!defined $bmccar->{idBMCCars})
		{
		&screen ("ERROR: Could not read entry for car $make:$model:$model_code:$variant: HP :$hp: Year :$year:");
		return -1;
		}
		
	# Check to see if the product already exists, and if it doesn't, then add it
	$get_bmc_prod_sth->execute ($bmc_part_id) or die $dbh->errstr;
	my $bmc_product = $get_bmc_prod_sth->fetchrow_hashref;
	if (!defined $bmc_product->{bmc_part_id})
		{
		$ins_bmc_prod_sth->execute ($bmc_part_id, $bmc_part_url, $product_type) or die $dbh->errstr;
		&screen ("      >NEW PRODUCT! BMC Part :$bmc_part_id:$product_type)");
		return 0;
		}

	# Check to see if the joiner already exists, and if it doesn't, then add it
	$get_bmc_fitment_sth->execute ($bmccar->{idBMCCars}, $bmc_part_id) or die $dbh->errstr;
	my $bmc_fitment = $get_bmc_fitment_sth->fetchrow_hashref;
	if (!defined $bmc_fitment->{BMCCars_idBMCCars})
		{
		$ins_bmc_fitment_sth->execute ($bmccar->{idBMCCars}, $bmc_part_id) or die $dbh->errstr;
		&alert ("      >NEW JOIN! CAR: $bmccar->{idBMCCars}:$make:$model.\n   BMC Part :$bmc_part_id:$product_type)");
		return 0;
		}


	return -1;
	}
	
sub tidy_field
	{
	my $field = $_[0];
	
	$field =~ s/^\s+//;
	$field =~ s/\s+$//;
	$field =~ s/\s\s+/ /g;
	
	return $field;	
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
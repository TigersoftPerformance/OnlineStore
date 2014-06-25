#!/usr/bin/perl -w

use strict;
use DBI;
use LWP::Simple;
use feature 'say';

my $content;  # will store content of http://www.quantumtuning.co.uk/car-directory.aspx
my $content2; # will store content like http://www.quantumtuning.co.uk/car-remap-tuning-remapping.aspx?Make=Skoda&Range=Octavia
my $home_url = 'http://www.quantumtuning.co.uk/';

# From this url we extract all useful links for further extractions
my $url = 'http://www.quantumtuning.co.uk/car-directory.aspx';
my $car_url = '';

use constant LOG => "./quantumtuning";

# Open log file to log data
open (my $logfh, ">", LOG) or die "cannot open " . LOG; 

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
# Load QuantumCars based on 4 parameters,
# in this site we have Cars with the same,
# make,range,model and they differ by bhp
#
my $loadqcth = $dbh->prepare("
	SELECT * FROM QuantumCars where 
	make =? AND model =? AND variant =? AND original_bhp =?
") or die $dbh->errstr;

#
# Update QuantumCars
#
my $updqcth = $dbh->prepare("
	UPDATE QuantumCars  SET tuned_bhp =?,bhp_increase =?,
	original_nm =?,tuned_nm =?,nm_increase =? WHERE 
	make =? AND model =? AND variant =? AND original_bhp =? AND image =?
") or die $dbh->errstr;

#
# Insert a new row into QuantumCars
#
my $insqcth = $dbh->prepare("
	INSERT into QuantumCars (make,model,variant,original_bhp,
	tuned_bhp,bhp_increase,original_nm,tuned_nm,nm_increase,image) 
	VALUES (?,?,?,?,?,?,?,?,?,?)
") or die $dbh->errstr;


my $retries = 5;
# Try a few times in case of failure
while ($retries && !($content = get $url ))
	{
	$retries --;
	}
die "Couldn't get $url" if (!$retries);

# In this while loop we gather and loop through all links like
# ex. car-remap-tuning-remapping.aspx?Make=Skoda&Range=Octavia
# and as we loop we scrape all Cars data
while ($content =~/<a href=\'(car-remap.*?)\'>.*?<\/a>/gi)
	{	
	#
	# Make an absolute url like
	# http://www.quantumtuning.co.uk/car-remap-tuning-remapping.aspx?Make=Skoda&Range=Octavia	
	$car_url = $home_url . $1;

	$retries = 5;
	# Try a few times in case of failure
	while ($retries && !($content2 = get $car_url ))
		{
		$retries --;
		}
	die "Couldn't get $car_url" if (!$retries);

	#
	# Extract images for Cars
	# All Car images are in here:http://quantumtuning.co.uk/Images/Database-Pictures/Cars/
	my $image = '';
	   $image = $1 if $content2 =~ /http:\/\/quantumtuning.co.uk\/Images\/Database-Pictures\/Cars\/(.*?\.jpg)/gi;

	#
	# Here we store all table content (html content) into $part1 variable
	# to make our job easy for further parsing
	my $part1 = $1 if $content2 =~/<table class=\"vehicletable\".*?>(.*?)<\/table>/sgi;

	#
	# Extract Cars data from the table: First we separate 
	# <td >data from <tr> then take exact stuff accordingly
	while ($part1 =~/<tr class=\"tablecolumn\">(.*?)<\/tr>/sgi)
		{
		my $line = $1;
		$line =~ s/^\s*$//gi;   # Remove blank lines
		$line =~ s/&nbsp;/0/gi; # Replace &nbsp with 0 to avoid problems when storind data 
								# into (INT) type columns in the QuantumCars table

		if ($line =~/
		<td>(.*?)<\/td> # $1 - Make
		<td>(.*?)<\/td> # $2 - Range<=>Model
		<td>(.*?)<\/td> # $3 - Model<=>variant
		<td>(.*?)<\/td> # $4 - Orig. BHP
		<td>(.*?)<\/td> # $5 - Tuned BHP
		<td>(.*?)<\/td> # $6 - BHP increase
		<td>(.*?)<\/td> # $7 - Orig. NM
		<td>(.*?)<\/td> # $8 - Tuned NM
		<td>(.*?)<\/td> # $9 - NM increase
		/xi)
			{
			# Do all DB and log realted things	
			&do_db ($1,$2,$3,$4,$5,$6,$7,$8,$9,$image);
			}
		else
			{
			# Next if our table row has a different structure	
			next;	
			}	
		}
	}	

close $logfh;


sub do_db
########################################
# Updates data if needed in QuantumCars
# Inserts new row if new in QuantumCars
########################################
{
	my ($make,$model,$variant,$original_bhp,$tuned_bhp,$bhp_increase,$original_nm,$tuned_nm,$nm_increase,$img) = @_;	
	my $need_update = 0;
	my ($row,$stored_row,$new_row);

	# Form a common list from new data
	$new_row = join ':', @_;

	$loadqcth->execute($make,$model,$variant,$original_bhp) or die $dbh->errstr;

	#
	# If row exists in QuantumCars table
	if ($row = $loadqcth->fetchrow_hashref)
		{
		# Form a common list from stored data	
		$stored_row = join ':',$row->{make},$row->{model},$row->{variant},$row->{original_bhp},$row->{tuned_bhp},$row->{bhp_increase},$row->{original_nm},$row->{tuned_nm},$row->{nm_increase},$row->{image};	

		#
		# This condition shows us if any of the parameters 
		# were modified after last run of this script then consider updating data
		if ($stored_row ne $new_row)
			{
			$need_update++;	
			&screen(" Updated $make : $model : $variant : $original_bhp:$tuned_bhp:$bhp_increase:$original_nm:$tuned_nm:$nm_increase:$img ==> $row->{make}:$row->{model}:$row->{variant}:$row->{original_bhp}:$row->{tuned_bhp}:$row->{bhp_increase}:$row->{original_nm}:$row->{tuned_nm}:$row->{nm_increase}:$row->{image}");
			}
		# If nothing is modified then just 
		# log data from QuantumCars table	
		else
			{
			&screen("\t$make : $model : $variant : $original_bhp:$tuned_bhp:$bhp_increase:$original_nm:$tuned_nm:$nm_increase:$img");
			}		
		}
	# Insert new row and log data	
	else
		{
		$insqcth->execute($make,$model,$variant,$original_bhp,$tuned_bhp,$bhp_increase,$original_nm,$tuned_nm,$nm_increase,$img) or die $dbh->errstr;
		&screen(" New Car => $make : $model : $variant : $original_bhp:$tuned_bhp:$bhp_increase:$original_nm:$tuned_nm:$nm_increase:$img");
		}	
	# Update data in QuantumCars table if needed	
	if ($need_update>0)
		{
		$updqcth->execute($tuned_bhp,$bhp_increase,$original_nm,$tuned_nm,$nm_increase,$make,$model,$variant,$original_bhp,$img) or die $dbh->errstr;
		}	
}

# This subroutine prints to the screen
# also logs whatever passed to it
sub screen
	{
	my $line = shift;
	say $line;
	say $logfh $line;
	}

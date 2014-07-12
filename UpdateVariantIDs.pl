#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use LWP::Simple;

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

# Now to select a matching entry from Cars
my $getcarsth = $dbh->prepare("
	SELECT * FROM Cars
") or die $dbh->errstr;
$getcarsth->execute() or die $dbh->errstr;

my $seltuneth = $dbh->prepare("
	SELECT * FROM SuperchipsWebsite WHERE tune_id = ?
") or die $dbh->errstr;

my $selttth = $dbh->prepare("
	SELECT * FROM SuperchipsDerived WHERE tune_id = ?
") or die $dbh->errstr;

my $updcarsth = $dbh->prepare("
	UPDATE Cars SET superchips_tune = ? WHERE idCars = ?
") or die $dbh->errstr;

my $updtuneth = $dbh->prepare("
	UPDATE SuperchipsWebsite SET tune_type = ? WHERE tune_id = ?
") or die $dbh->errstr;

while (my $cars_hr = $getcarsth->fetchrow_hashref)
{
	print "Found Car $cars_hr->{idCars} ";
	
	my $tune_type = "?";

	$selttth->execute ($cars_hr->{idCars});
	my $sd_hr = $selttth->fetchrow_hashref;
	if (defined $sd_hr)
	{
		print "Found Tune Type $sd_hr->{tune_type}";
		$tune_type = $sd_hr->{tune_type};
	}
	else
	{
		print "Could not find tun type for this car\n";
	}
	
	$seltuneth->execute ($cars_hr->{idCars}) or die "Could not execute read tune";
	my $tune_hr = $seltuneth->fetchrow_hashref;
	if (defined $tune_hr)
	{
		print "Variant_id is $tune_hr->{variant_id} \n";
		$updcarsth->execute ($tune_hr->{variant_id}, $cars_hr->{idCars}) or die "Could not update car";
		$updtuneth->execute ($tune_type, $cars_hr->{idCars}) or die "Could not update car";
	}
	else
	{
		print "Could not find tune for this car\n";
	}
}
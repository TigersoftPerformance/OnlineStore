#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';

my $driver = "mysql";   # Database driver type
my $database = "TP";  # Database name
my $user = "root";          # Database user name
my $password = "doover11";      # Database user password

#
# Connect to database
#
my $dbh = DBI->connect(
"DBI:$driver:$database", $user, $password,
	{
	RaiseError => 1, PrintError => 1,
	}
) or die $DBI::errstr;

#
# prepare the sql statements
# This is for the main loop, we will read every entry with a model code
my $carsth = $dbh->prepare("
	SELECT * FROM Cars WHERE model_code != ''
") or die $dbh->errstr;
$carsth->execute() or die $dbh->errstr;
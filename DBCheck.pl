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
my $dsn = "DBI:$driver:;" . "mysql_read_default_file=$my_cnf";
my $dbh = DBI->connect($dsn, undef, undef,
	{
	RaiseError => 1, PrintError => 1, mysql_enable_utf8 => 1
	}
) or die $DBI::errstr;

#
# prepare the sql statements
# This is for the main loop, we will read every entry with a model code
my $carsth = $dbh->prepare("
	SELECT * FROM Cars WHERE model_code != ''
") or die $dbh->errstr;
$carsth->execute() or die $dbh->errstr;
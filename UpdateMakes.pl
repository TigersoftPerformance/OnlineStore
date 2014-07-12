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

# Now to select a matching entry from SuperchipsMakes
my $selmakth = $dbh->prepare("
	SELECT * FROM SuperchipsMakes WHERE make_num = ?
") or die $dbh->errstr;

# Insert new row into SuperchipsMakes
my $insmakth = $dbh->prepare("
	INSERT into SuperchipsMakes VALUES (?,?,?,?)
") or die $dbh->errstr;

# Update existing row into SuperchipsMakes
my $updmakth = $dbh->prepare("
	UPDATE SuperchipsMakes SET make = ? WHERE make_num = ?
") or die $dbh->errstr;

my $url = "http://www.superchips.co.uk/searchhelper";
my $content = get $url || die "Couldn't get $url";
# say $content;
while ($content =~ /<option value=\\"(\d{1,2})\\" >(.*?)<\\\/option>/g)
{
	my $make_num = $1;
	my $make = $2;
	$selmakth->execute($make_num) or die $dbh->errstr;
	if (my $make_data = $selmakth->fetchrow_hashref)
	{
		$updmakth->execute($make, $make_num) or die $dbh->errstr;
	}
	else
	{
		$insmakth->execute($make_num, $make, 'Y', "No comments") or die $dbh->errstr;
	}
}


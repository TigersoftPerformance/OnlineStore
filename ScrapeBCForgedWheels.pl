#!/usr/bin/perl -w
#####################################################################################
# Scrape BC Forged Wheels Website script - John Robinson, September 2014
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

my $url = 'http://www.bcec.com.tw/wheel/new_rim_main/MAIN.html';

use constant LOGFILE    => "./Logs/ScrapeBCForgedWheels.log";
use constant ALERTFILE  => "./Logs/ScrapeBCForgedWheels.alert";
use constant DEBUGFILE  => "./Logs/ScrapeBCForgedWheels.debug";

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
# Insert/Replace a new record into BC ForgedWheels Table
#
my $ins_bmc_car_sth = $dbh->prepare("
	REPLACE INTO BCForgedWheels SET model = ?, url = ?, active = 'Y'
") or die $dbh->errstr;


#######################################################################
# Code starts here
#######################################################################

my $mech = WWW::Mechanize::Firefox->new();
my $main_content;

# This will get the front page of the website
# Try a few times in case of failure
my $retries = 5;
while ($retries && !($mech->get($url)))
	{
	$retries --;
	}
die "Couldn't get $url" if (!$retries);
$main_content = decode_utf8 ($mech->content);
$main_content =~ /<div id="MENU">/gs or die "No MENU found on main page";
while ($main_content =~ /<a href=\"(.+?)\" onmouse.+?>/gs)
	{
	$url = $1;
	&debug ($1);

	$retries = 5;
	while ($retries && !($mech->get($url)))
		{
		$retries --;
		}
	die "Couldn't get $url" if (!$retries);
	my $wheel_content = decode_utf8 ($mech->content);

	$wheel_content =~ m/<div id="slide">\s*<table(.+?)<\/table>\s*<\/div>/s;
	my $table = $1;
	unless (defined $1)
		{
		&alert ("Could not find a table");
		next;
		}
	
	my $row_count = 0;
	my $cell_count;
	my $specs;
	my $pics;
	while ($table =~ m/<tr(.+?)<\/tr>/sg)
		{
		my $myrow = $1;
		$row_count ++;
		&debug (" Found a table row -> $row_count");

		$cell_count = 0;
		undef $specs;
		undef $pics;
		while ($myrow =~ m/<td(.+?)<\/td>/sg)
			{
			my $mycell = $1;
			$cell_count ++;
			&debug ("  Found a table cell");
			if ($cell_count == 3)
				{
				$specs = $mycell;
				}
			elsif ($cell_count == 5)
				{
				$pics = $mycell;
				}

			}

		if (!defined $specs)
			{
			next;
			}

		if (!defined $pics)
			{
			&alert ("   Could not find any pics");
			next;
			}

		&debug ("Specs\n======\n$specs\n======\n");
		&debug ("Pics\n======\n$pics\n======\n");
			

		}
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
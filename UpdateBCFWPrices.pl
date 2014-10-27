#!/usr/bin/perl -w
#####################################################################################
# Update BC Forged Wheels Prices script - John Robinson, September 2014
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
use TP qw (debug log alert screen);


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
# Read a record from the BCForgedWheelsWebsite Table based on model.
#
my $ins_bcp_sth = $dbh->prepare("
	REPLACE INTO BCForgedWheelsPrices SET series = ?, diameter =?, width = ?, tp_price = ?, RRP = ?, diamondcut = ?
") or die $dbh->errstr;

# This script take a single argument, which is the name of the csv file that has the retail pricing in it. 

exit if !defined $ARGV[0];

my $file = $ARGV[0];
open my $info, $file or die "Could not open $file: $!";

my $series = '';
my $previous_series = '';
while( my $line = <$info>)
	{   
	my @cols = split (/,/, $line);
	$cols[0] =~ s/^\s+//g;
	$cols[0] =~ s/\s+$//g;
	$cols[1] =~ s/\s+//g;
    
	if (!length ($cols[1]))
		{
		next;
		}
	
	if (length ($cols[0]))
		{
		$series = $cols[0];
		$previous_series = $series;
		}
	else
		{
		$series = $previous_series;
		}
		
	my $width_code = $cols[1];
	my $tp_price = $cols[2];
	my $rrp_price = $cols[3];
	&debug ("Series: $series. Size: $width_code. Prices = $tp_price, $rrp_price");

	my $diamondcut = 1;
	if ($series =~ m/FJ|SN|BS|BA|TM/)
		{
		$diamondcut = 0;
		debug ("$series does not get Diamond Cut");
		}

	# Now we just have to decypher the width_code, and write the records to the price table.
	$width_code =~ s/[\s\"]+//g;
	$width_code =~ s/[\x80-\xFF]+//g;
	if ($width_code =~ m/^(\d\d)\(([\d\.]+)J\~([\d\.]+)J\)$/)
		{
		my $diameter = $1, my $width1 = $2, my $width2 = $3;
		for (my $i = $width1; $i <= $width2; $i += 0.5)
			{
			&write_price_record ($series, $diameter, $i, $tp_price, $rrp_price, $diamondcut);
			}
		}
	elsif ($width_code =~ m/^(\d\d)\(([\d\.]+)J\&([\d\.]+)J\)$/)
		{
		my $diameter = $1, my $width1 = $2, my $width2 = $3;
		&write_price_record ($series, $diameter, $width1, $tp_price, $rrp_price, $diamondcut);
		&write_price_record ($series, $diameter, $width2, $tp_price, $rrp_price, $diamondcut);
		}
	elsif ($width_code =~ m/^(\d\d)x([\d\.]+)J$/ || $width_code =~ m/^(\d\d)\(([\d\.]+)J\)$/)
		{
		my $diameter = $1, my $width = $2;
		&write_price_record ($series, $diameter, $width, $tp_price, $rrp_price, $diamondcut);
		}
	else
		{
		&alert ("unrecognised width_code: $width_code");
		}
	}

close $info;

sub write_price_record
	{
	my ($series, $diameter, $width, $tp_price, $rrp_price, $diamondcut) = @_;
	
	&log ("New Price Record: $series. Diam: $diameter. Width: $width. Prices = $tp_price, $rrp_price");
	$ins_bcp_sth->execute ($series, $diameter, $width, $tp_price, $rrp_price, $diamondcut) or die "Could not write record";
	
	}


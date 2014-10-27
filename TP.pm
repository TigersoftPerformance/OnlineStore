#!/usr/bin/perl
##############################################################################
# Package of TigersoftPerformance subroutines
#
##############################################################################

package TP;


require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( debug log alert screen INFOBOX_CONTAINER INFOBOX_CONTAINER_END INFOBOX_START INFOBOX_THIRD INFOBOX_HALF INFOBOX_TWOTHIRD INFOBOX_FULL INFOBOX_LONG INFOBOX_END LONGBOX_PIC_START LONGBOX_PIC_END LONGBOX_TEXT_START LONGBOX_TEXT_END INFOBOX_SUB INFOBOX_SUBTEXT INFOBOX_SUBPIC WIDTH25 WIDTH30 WIDTH33 WIDTH40 WIDTH50 WIDTH60 WIDTH66 WIDTH70 WIDTH75 WIDTH100
NONTURBO TURBOPETROL TURBODIESEL SUPERCHARGED TWINCHARGER infobox_womostuff create_superchips_stats_table create_metatags_description);

use strict;
use warnings;
use DBI;
use English;
use feature 'say';

use constant LOGSDIR    => "./Logs/";

use constant NONTURBO    => "Non-Turbo Petrol";
use constant TURBOPETROL => "Turbocharged Petrol";
use constant TURBODIESEL => "Turbo-Diesel";
use constant SUPERCHARGED => "Supercharged";
use constant TWINCHARGER => "Twincharger";

use constant INFOBOX_CONTAINER => '<div class="infobox_container">';
use constant INFOBOX_START => "<div class=\"infobox";
use constant INFOBOX_THIRD => " onethirdbox\">";
use constant INFOBOX_HALF => " halfbox\">";
use constant INFOBOX_TWOTHIRD => " twothirdbox\">";
use constant INFOBOX_FULL => " fullbox\">";
use constant INFOBOX_LONG => " fullbox longbox\">";
use constant INFOBOX_END => '</div>';
use constant INFOBOX_CONTAINER_END => '</div>';
use constant LONGBOX_PIC_START => "<div class=\"longbox_pic\">";
use constant LONGBOX_PIC_END => "</div>";
use constant LONGBOX_TEXT_START => "<div class=\"longbox_text\">";
use constant LONGBOX_TEXT_END => "</div>";

use constant INFOBOX_SUB => ' subbox">';
use constant INFOBOX_SUBTEXT => '<div class="subbox_text ';
use constant INFOBOX_SUBPIC => '<div class="subbox_pic ';
use constant WIDTH25 => 'width25">';
use constant WIDTH30 => 'width30">';
use constant WIDTH33 => 'width33">';
use constant WIDTH40 => 'width40">';
use constant WIDTH50 => 'width50">';
use constant WIDTH60 => 'width60">';
use constant WIDTH66 => 'width66">';
use constant WIDTH70 => 'width70">';
use constant WIDTH75 => 'width75">';
use constant WIDTH100 => 'width100">';



my $progname = '';
my $logfile;
my $alertfile;
my $debugfile;

my $logfh;
my $alertfh;
my $debugfh;
	
BEGIN	{
	$progname = $0;
	$progname =~ s/\.pl$//;
	
	$logfile = LOGSDIR . $progname . ".log";
	$alertfile = LOGSDIR . $progname . ".alert";
	$debugfile = LOGSDIR . $progname . ".debug";
	
	open($logfh, ">", $logfile)     or die "cannot open $logfile $!";
	open($alertfh, ">", $alertfile) or die "cannot open $alertfile $!";
	open($debugfh, ">", $debugfile) or die "cannot open $debugfile $!";
	$logfh->autoflush;
	$alertfh->autoflush;
	$debugfh->autoflush;
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
	
END	{
	close $logfh, $alertfh, $debugfh;
	}

sub infobox_womostuff 
	{
	return INFOBOX_START . INFOBOX_FULL . '<h2>See what our Customers have to say about us</h2>' . 
	 '<table class="womoTable"><tr><td align="center">
	 <script type="text/javascript" src="http://www.womo.com.au/widget-MDAxMTUyNjcw.js"></script>
	 </td><td><div class="picWomoAwards"><span> </span></div>
	 <p><b>Tigersoft Performance</b><br>Winners of a Customer Service award from WOMO<br>2 Years in a Row!</p></td></tr></table>' . INFOBOX_END;
	}
	
sub create_superchips_stats_table
	{
	my ($car_data, $superchips_website) = @_;

	my $percentpowerincrease = $car_data->{original_bhp} ? int ($superchips_website->{gain_bhp} / $car_data->{original_bhp} * 100) : 0;
	my $percenttorqueincrease = $car_data->{original_nm} ? int ($superchips_website->{gain_nm} / $car_data->{original_nm} * 100) : 0;
	my $powerincreasekw = int (($superchips_website->{gain_bhp} * 0.746) + 0.5);
	
	my $complete_model = &get_complete_model ($car_data);
	
	return "<table class=\"tuneSpecsTable\"><tbody><tr><th>Vehicle</th><td>$complete_model</td></tr>
	 <tr><th>Engine Type</th><td>$superchips_website->{engine_type}</td></tr>
	 <tr><th>Engine Capacity</th><td>$superchips_website->{capacity} cc</td></tr>
	 <tr><th>Original Power</th><td>$car_data->{original_kw} kW ($car_data->{original_bhp} bhp)</td></tr>
	 <tr><th>Original Torque</th><td>$car_data->{original_nm} Nm</td></tr>
	 <tr class=\"highlight\"><th>Power Gain</th><td>$powerincreasekw kW ($superchips_website->{gain_bhp} bhp) = $percentpowerincrease% increase</td></tr>
	 <tr class=\"highlight\"><th>Torque Gain</th><td>$superchips_website->{gain_nm} Nm = $percenttorqueincrease% increase</td></tr></tbody></table>";
	}
	
sub get_complete_model
	{
	my ($car_data) = @_;
	
	my $carkw = ($car_data->{original_kw} ? " " . $car_data->{original_kw} . "kW": "");
	my $complete_model = $car_data->{make} . " " . $car_data->{model};
	$complete_model .= " (" . $car_data->{model_code} . ") " if length $car_data->{model_code};
	$complete_model .= (length ($car_data->{variant}) ? $car_data->{variant} : "All Models") . $carkw;
	}

sub create_metatags_description
	{
	my ($name, $car_data, $tune_data) = @_;
	
	my $complete_model = $car_data->{make} . " " . $car_data->{model};
	my $model_code = "";
	if (length ($car_data->{model_code}))
		{
		$model_code = $car_data->{model_code};
		$model_code =~ s/$car_data->{model} //;
		$model_code = " (" . $model_code . ")";
		}
	$complete_model .= $model_code . " " . $car_data->{variant};
	my $powerincreasekw = int (($tune_data->{gain_bhp} * 0.746) + 0.5);
	
	
	return "The $name for $complete_model provides a performance increase of $powerincreasekw kW and $tune_data->{gain_nm} Nm along with better fuel economy and smooth flexible driving";
	}






1;
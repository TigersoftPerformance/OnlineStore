#!/usr/bin/perl
##############################################################################
# Package of TigersoftPerformance subroutines
#
##############################################################################

package TP;


require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( debug log alert screen INFOBOX_CONTAINER INFOBOX_CONTAINER_END INFOBOX_START INFOBOX_THIRD INFOBOX_HALF INFOBOX_TWOTHIRD INFOBOX_FULL INFOBOX_LONG INFOBOX_END LONGBOX_PIC_START LONGBOX_PIC_END LONGBOX_TEXT_START LONGBOX_TEXT_END INFOBOX_SUB INFOBOX_SUBTEXT INFOBOX_SUBPIC WIDTH25 WIDTH30 WIDTH33 WIDTH40 WIDTH50 WIDTH60 WIDTH66 WIDTH70 WIDTH75 WIDTH100
NONTURBO TURBOPETROL TURBODIESEL SUPERCHARGED TWINCHARGER BFECUOPENPRICE TUNENASPPRICE1 TUNENASPPRICE2 TUNETURBOPRICE1 TUNETURBOPRICE2 TUNETURBOPRICE3 TUNESTAGE2PRICE TUNESTAGE3PRICE TUNESTAGE4PRICE BFNASPPRICE BFFORDPRICE BFVAGPRICE BFOPELPRICE PNBLUEFIN PNFLASHTUNE PNBENCHTUNE PNCHIPCHANGE PNUNKNOWN PNNONE PNSTAGE2 PNSTAGE3 PNSTAGE4 infobox_womostuff create_superchips_stats_table get_complete_model get_tune_price get_bluefin_price);




use constant PNBLUEFIN    => "Superchips Bluefin"; # Product Name for Bluefin
use constant PNFLASHTUNE  => "Superchips Flash Tune"; # Product Name for Flash tune
use constant PNBENCHTUNE  => "Superchips Bench Tune"; # Product Name for Bench Tune
use constant PNCHIPCHANGE => "Superchips Chip Change"; # Product Name for Bench Tune
use constant PNUNKNOWN    => "Superchips Tune"; # Product Name for Bluefin
use constant PNNONE       => "No Tune Whatsoever"; # Product Name for None
use constant PNSTAGE2     => "Stage 2 Tune"; 
use constant PNSTAGE3     => "Stage 3 Tune"; 
use constant PNSTAGE4     => "Stage 4 Tune"; 

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

use constant INFOBOX_CONTAINER => "<div class='infobox_container'>";
use constant INFOBOX_START => "<div class='infobox";
use constant INFOBOX_THIRD => " onethirdbox'>";
use constant INFOBOX_HALF => " halfbox'>";
use constant INFOBOX_TWOTHIRD => " twothirdbox'>";
use constant INFOBOX_FULL => " fullbox'>";
use constant INFOBOX_LONG => " fullbox longbox'>";
use constant INFOBOX_END => '</div>';
use constant INFOBOX_CONTAINER_END => '</div>';
use constant LONGBOX_PIC_START => "<div class='longbox_pic'>";
use constant LONGBOX_PIC_END => "</div>";
use constant LONGBOX_TEXT_START => "<div class='longbox_text'>";
use constant LONGBOX_TEXT_END => "</div>";

use constant INFOBOX_SUB => " subbox'>";
use constant INFOBOX_SUBTEXT => "<div class='subbox_text ";
use constant INFOBOX_SUBPIC => "<div class='subbox_pic ";
use constant WIDTH25 => "width25'>";
use constant WIDTH30 => "width30'>";
use constant WIDTH33 => "width33'>";
use constant WIDTH40 => "width40'>";
use constant WIDTH50 => "width50'>";
use constant WIDTH60 => "width60'>";
use constant WIDTH66 => "width66'>";
use constant WIDTH70 => "width70'>";
use constant WIDTH75 => "width75'>";
use constant WIDTH100 => "width100'>";



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
	return INFOBOX_START . INFOBOX_FULL . "<h2>See what our Customers have to say about us</h2>" . 
	 "<table class='womoTable'><tr><td align='center'>
	 <script type='text/javascript' src='http://www.womo.com.au/widget-MDAxMTUyNjcw.js'></script>
	 </td><td><div class='picWomoAwards'><span> </span></div>
	 <p><b>Tigersoft Performance</b><br>Winners of a Customer Service award from WOMO<br>2 Years in a Row!</p></td></tr></table>" . INFOBOX_END;
	}
	
sub create_superchips_stats_table
	{
	my ($car_data, $superchips_website) = @_;

	my $percentpowerincrease = $car_data->{original_bhp} ? int ($superchips_website->{gain_bhp} / $car_data->{original_bhp} * 100) : 0;
	my $percenttorqueincrease = $car_data->{original_nm} ? int ($superchips_website->{gain_nm} / $car_data->{original_nm} * 100) : 0;
	my $powerincreasekw = int (($superchips_website->{gain_bhp} * 0.746) + 0.5);
	
	my $complete_model = &get_complete_model ($car_data);
	
	return "<table class='tuneSpecsTable'><tbody><tr><th>Vehicle</th><td>$complete_model</td></tr>
	 <tr><th>Engine Type</th><td>$superchips_website->{engine_type}</td></tr>
	 <tr><th>Engine Capacity</th><td>$superchips_website->{capacity} cc</td></tr>
	 <tr><th>Original Power</th><td>$car_data->{original_kw} kW ($car_data->{original_bhp} bhp)</td></tr>
	 <tr><th>Original Torque</th><td>$car_data->{original_nm} Nm</td></tr>
	 <tr class='highlight'><th>Power Gain</th><td>$powerincreasekw kW ($superchips_website->{gain_bhp} bhp) = $percentpowerincrease% increase</td></tr>
	 <tr class='highlight'><th>Torque Gain</th><td>$superchips_website->{gain_nm} Nm = $percenttorqueincrease% increase</td></tr></tbody></table>";
	}
	
sub get_complete_model
	{
	my ($car_data) = @_;
	
	# First build the Short Date
	my $start_year = substr ($car_data->{start_date}, 0, 4);
	my $end_year = substr ($car_data->{end_date}, 0, 4);
	my $start_part = ($start_year eq 1970) ? "upto" : substr ($start_year, 2, 2);
	my $middle_part = "-";
	my $end_part = ($end_year eq 2050 || $end_year eq "0000") ? "on" : substr ($end_year, 2, 2);
	my $short_date = ($start_year eq 1970 && ($end_year eq 2050 || $end_year eq "0000")) ? "" : "[". $start_part . $middle_part . $end_part . "]";
	
	my $model_code = "";
	if (length ($car_data->{model_code}))
		{
		$model_code = $car_data->{model_code};
		$model_code =~ s/$car_data->{model} //;
		$model_code = "(" . $model_code . ")";
		}
	my $carkw = ($car_data->{original_kw} ? $car_data->{original_kw} . "kW" : "");
	my $complete_model = "$car_data->{make} $car_data->{model} $model_code $car_data->{variant} $carkw $short_date";
	$complete_model =~ s/  +/ /g;
	$complete_model =~ s/^ //;
	$complete_model =~ s/ $//;
	return $complete_model;
	}


use constant BFECUOPENPRICE => 400; 
use constant TUNENASPPRICE1 => 599;
use constant TUNENASPPRICE2 => 699;
use constant TUNETURBOPRICE1 => 999;
use constant TUNETURBOPRICE2 => 1249;
use constant TUNETURBOPRICE3 => 1499;

use constant TUNESTAGE2PRICE => 150;
use constant TUNESTAGE3PRICE => 150;
use constant TUNESTAGE4PRICE => 150;

use constant BFNASPPRICE => 499;
use constant BFFORDPRICE => 739;
use constant BFVAGPRICE  => 739;
use constant BFOPELPRICE => 739;

sub get_tune_price
##########################
# Gives the right price for
# the selected tuner
##########################
{
	my ($uk_price, $fuel_type) = @_;
	my $tuneprice = 0;

	if ($uk_price <= 229)
		{
		if ($fuel_type eq NONTURBO)
			{
			$tuneprice = TUNENASPPRICE1;
			}
		else
			{
			$tuneprice = TUNETURBOPRICE1;
			}
		}

	if ($uk_price > 229 && $uk_price <= 320)
		{
		if ($fuel_type eq NONTURBO)
			{
			$tuneprice = TUNENASPPRICE2;
			}
		else
			{
			$tuneprice = TUNETURBOPRICE1;
			}
		}

	if ($uk_price > 320 && $uk_price <= 365)
		{
		$tuneprice = TUNETURBOPRICE1;
		}

	if ($uk_price > 365 && $uk_price <= 480)
		{
		$tuneprice = TUNETURBOPRICE2;
		}

	if ($uk_price > 480 && $uk_price <= 799)
		{
		$tuneprice = TUNETURBOPRICE3;
		}

	if ($uk_price > 799)
		{
		$tuneprice = 1000000;
		}
	return $tuneprice;
}

sub get_bluefin_price
##########################
# Gives the right price for
# the selected bluefin
##########################
{
	my ($make, $model, $fuel_type, $capacity) = @_;	
	my $bluefinprice = 0;
	
	if ($make =~ /Audi|BMW|Dacia|Mercedes|Nissan|Renault|Seat|Skoda|Volkswagen/i)
		{
		if ($fuel_type eq NONTURBO)
			{
			$bluefinprice = BFNASPPRICE;
			}
		else
			{
			$bluefinprice = BFVAGPRICE;
			}
		}

	if ($make =~ /Buick|Chevrolet|Holden|Saab|Vauxhall-Opel|Opel/i)
		{
		if ($fuel_type eq NONTURBO)
			{
			$bluefinprice = BFNASPPRICE;
			}
		else
			{
			$bluefinprice = BFOPELPRICE;
			}
		}

	if ($make =~ /Ford|LTI/i)
		{
		if ($fuel_type eq NONTURBO)
			{
			$bluefinprice = BFNASPPRICE;
			}
		else
			{
			$bluefinprice = BFFORDPRICE;
			}
		}

	if ($make =~ /Jaguar/i)
		{
		# The X Types use the FORD-T, while the XF and XJ use LRF-T
		# $2 is the Model. If the left 2 characters are "X ", then it is an X Type
		if (substr($model, 1, 2) eq "X ")
			{
			$bluefinprice = BFFORDPRICE;
			}
		else
			{
			$bluefinprice = BFVAGPRICE;
			}
		}

	if ($make =~ /Land Rover/i)
		{
		if ($capacity == 2402)
			{
			$bluefinprice = BFFORDPRICE;
			}
		else
			{
			$bluefinprice = BFVAGPRICE;
			}
		}

	if ($make =~ /Mini|Morgan/i)
		{
		$bluefinprice = BFNASPPRICE;
		}
	return $bluefinprice;
}


























1;
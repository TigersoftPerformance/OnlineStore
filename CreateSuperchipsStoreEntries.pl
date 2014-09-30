#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';

use constant LOG => "./Logs/CreateSuperchipsStoreEntries.log";
open (my $logfh, ">", LOG) or die "cannot open " . LOG; 

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

use constant NONTURBO    => "Non-Turbo Petrol";
use constant TURBOPETROL => "Turbocharged Petrol";
use constant TURBODIESEL => "Turbo-Diesel";

use constant PPBLUEFIN    => "BF"; # Product suffix for Bluefin
use constant PPFLASHTUNE  => "FT"; # Product prefix for Flash tune
use constant PPBENCHTUNE  => "BT"; # Product prefix for Bench Tune
use constant PPCHIPCHANGE => "CC"; # Product prefix for Bench Tune
use constant PPUNKNOWN    => "UK"; # Product prefix for Bluefin
use constant PPNONE       => "NO"; # Product prefix for None
use constant PPSTAGE2     => "S2"; # Product prefix for None
use constant PPSTAGE3     => "S3"; # Product prefix for None
use constant PPSTAGE4     => "S4"; # Product prefix for None

use constant PNBLUEFIN    => "Superchips Bluefin"; # Product Name for Bluefin
use constant PNFLASHTUNE  => "Superchips Flash Tune"; # Product Name for Flash tune
use constant PNBENCHTUNE  => "Superchips Bench Tune"; # Product Name for Bench Tune
use constant PNCHIPCHANGE => "Superchips Chip Change"; # Product Name for Bench Tune
use constant PNUNKNOWN    => "Superchips Tune"; # Product Name for Bluefin
use constant PNNONE       => "No Tune Whatsoever"; # Product Name for None
use constant PNSTAGE2     => "Stage 2 Tune"; 
use constant PNSTAGE3     => "Stage 3 Tune"; 
use constant PNSTAGE4     => "Stage 4 Tune"; 

use constant START_WRAPPER => "<div id=\"superchipsProductDescription\" class=\"infobox_container\">";
use constant END_WRAPPER => "</div>";

use constant SORT_ORDER_START => 100;
use constant SORT_ORDER_INCREMENT => 50;
my $sortorder = SORT_ORDER_START;

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

my $cars_query = "SELECT * FROM Cars WHERE superchips_tune > 0 AND active = 'Y'";
if (defined $ARGV[0])
{
	$cars_query = "$cars_query AND make ='$ARGV[0]'";
	if (defined $ARGV[1])
	{
		$cars_query = "$cars_query AND model ='$ARGV[1]'";
	}
}
my $sth = $dbh->prepare($cars_query) or die $dbh->errstr;
$sth->execute() or die $dbh->errstr;

#
# Select a row from SuperchipsWebsite based on variant_id
#
my $get_tune_sth = $dbh->prepare("
	SELECT * FROM SuperchipsWebsite WHERE variant_id = ?
") or die $dbh->errstr;

#
# Select a row from Categories based on idCars
#
my $get_cat_sth = $dbh->prepare("
	SELECT * FROM Categories WHERE partid = ? AND active = 'Y'
") or die $dbh->errstr;

#
# Update/Insert row into ZenCartStoreEntries table
#
my $insertth = $dbh->prepare("
	REPLACE INTO ZenCartStoreEntries VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) 
") or die $dbh->errstr;

#
# Global Variables
#
my $v_products_type = 1;
my $v_products_url_1;
my $v_specials_price;
my $v_specials_date_avail = "";
my $v_specials_expires_date = "";
my $v_products_weight = 0;
my $v_product_is_call = 0;
my $v_products_sort_order;
my $v_products_quantity_order_min = 1;
my $v_products_quantity_order_units = 1;
my $v_products_priced_by_attribute = 0;
my $v_product_is_always_free_shipping = 1;
my $v_date_avail = "0000-00-00 00:00:00";
my $v_date_added = "2014-09-08 00:00:00";
my $v_products_quantity = 100;
my $v_manufacturers_name = "Superchips";
my $v_categories_name_1;
my $v_tax_class_title = "Taxable Goods";
my $v_status = 1;
my $v_metatags_products_name_status = 1;
my $v_metatags_title_status = 1;
my $v_metatags_model_status = 1;
my $v_metatags_price_status = 0;
my $v_metatags_title_tagline_status = 1;
my $v_metatags_title_1 = "";
my $v_metatags_keywords_1 = "";
my $v_metatags_description_1 = "";
my $v_products_price  = 0;
my $v_products_image = "";
my $v_products_model = "";
my $v_products_name_1 = "";
my $v_products_description_1 = "";

my $products_model;

my $carkw;
my $complete_model;
# my $hiddenstats = "<DIV ID=\"hiddenstats1\" STYLE=\"POSITION: absolute; z-index: 4; VISIBILITY: hidden;\">$complete_model. Original Power: $car_data->{original_kw} kW ($car_data->{original_bhp} bhp). Original Torque: $car_data->{original_nm} Nm. Power Gain: $powerincreasekw kW ($superchips_website->{gain_bhp} bhp) = $percentpowerincrease% increase.Torque Gain: $superchips_website->{gain_nm} Nm = $percenttorqueincrease% increase</DIV>";



#
# This is where the grunt work happens
# This main loop reads each row from the Cars table
#
#print 'v_products_model,v_products_type,v_products_image,v_products_name_1,v_products_description_1,v_products_url_1,v_specials_price,v_specials_date_avail,v_specials_expires_date,v_products_price,v_products_weight,v_product_is_call,v_products_sort_order,v_products_quantity_order_min,v_products_quantity_order_units,v_products_priced_by_attribute,v_product_is_always_free_shipping,v_date_avail,v_date_added,v_products_quantity,v_manufacturers_name,v_categories_name_1,v_tax_class_title,v_status,v_metatags_products_name_status,v_metatags_title_status,v_metatags_model_status,v_metatags_price_status,v_metatags_title_tagline_status,v_metatags_title_1,v_metatags_keywords_1,v_metatags_description_1' . "\n";
my $car_data = {};
while ($car_data = $sth->fetchrow_hashref)
	{
	say "$car_data->{make} $car_data->{model}";
	my $superchips_website = &get_tune_info ($car_data->{superchips_tune}, $get_tune_sth);
	unless (defined $superchips_website)
		{
		print $logfh "  No Superchips Website Entry for car $car_data->{idCars}\n";
		next;
		}
	my $percentpowerincrease = $car_data->{original_bhp} ? int ($superchips_website->{gain_bhp} / $car_data->{original_bhp} * 100) : 0;
	my $percenttorqueincrease = $car_data->{original_nm} ? int ($superchips_website->{gain_nm} / $car_data->{original_nm} * 100) : 0;
	my $powerincreasekw = int (($superchips_website->{gain_bhp} * 0.746) + 0.5);
	my $powercurve = $superchips_website->{dyno_graph} ? "<p><a href=\"http://www.superchips.co.uk/curves/$superchips_website->{dyno_graph}\"><img src=\"images/icon_curve.png\"></img></a>" : "";


	$products_model = sprintf ("TPC%06d", $car_data->{idCars});
	$v_products_sort_order = $sortorder;
	$sortorder += SORT_ORDER_INCREMENT;

	$get_cat_sth->execute($car_data->{idCars}) or die;
	my $categories = $get_cat_sth->fetchrow_hashref;
	$v_categories_name_1 = $categories->{longname};
	unless (defined ($v_categories_name_1))
		{
		print $logfh "Can't find Category Name for car $car_data->{idCars}\n";
		next;
		}

	my $no_tune = 1;

	$carkw = ($car_data->{original_kw} ? " " . $car_data->{original_kw} . "kW": "");
	$complete_model = $car_data->{make} . " " . $car_data->{model};
	$complete_model .= " (" . $car_data->{model_code} . ") " if length $car_data->{model_code};
	$complete_model .= (length ($car_data->{variant}) ? $car_data->{variant} : "All Models") . $carkw;
	my $openingstats = "<table class=\"tuneSpecsTable\"><tbody><tr><th>Vehicle</th><td>$complete_model</td></tr>
	 <tr><th>Engine Type</th><td>$superchips_website->{engine_type}</td></tr>
	 <tr><th>Engine Capacity</th><td>$superchips_website->{capacity} cc</td></tr>
	 <tr><th>Original Power</th><td>$car_data->{original_kw} kW ($car_data->{original_bhp} bhp)</td></tr>
	 <tr><th>Original Torque</th><td>$car_data->{original_nm} Nm</td></tr>
	 <tr class=\"highlight\"><th>Power Gain</th><td>$powerincreasekw kW ($superchips_website->{gain_bhp} bhp) = $percentpowerincrease% increase</td></tr>
	 <tr class=\"highlight\"><th>Torque Gain</th><td>$superchips_website->{gain_nm} Nm = $percenttorqueincrease% increase</td></tr></tbody></table>";

$v_products_description_1 = START_WRAPPER;

#
# This is for BLUEFIN
#
	if ($no_tune && $superchips_website->{bluefin} ne "N")
		{
		$no_tune = 0;
		$v_products_price = &get_bluefin_price ($superchips_website->{make}, $superchips_website->{model}, $superchips_website->{engine_type}, $superchips_website->{capacity});
		$v_products_image = "bluefin_pic.jpg";
		$v_products_model = $products_model . PPBLUEFIN;
		$v_products_name_1 = PNBLUEFIN;

		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 for $complete_model provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";

		$v_products_description_1 .= &infobox_product_heading (PNBLUEFIN, $openingstats);
		$v_products_description_1 .= &infobox_powercurve ();
		$v_products_description_1 .= &infobox_whatisbluefin ();
		$v_products_description_1 .= &infobox_howbluefinworks ();
		$v_products_description_1 .= &infobox_otherbenefits ();
		$v_products_description_1 .= &infobox_bluefinenable () if ($superchips_website->{bluefin} eq 'E');
		$v_products_description_1 .= &infobox_guarantee ();
		$v_products_description_1 .= &infobox_womostuff ();
		$v_products_description_1 .= END_WRAPPER;
			
		&insert_store_entry ();
		}

#
# This is for UNKNOWN TUNE TYPE
#
	if ($no_tune && $superchips_website->{tune_type} eq "?")
		{
		$v_products_price = &get_tune_price ($superchips_website->{uk_price}, $superchips_website->{engine_type});
		$v_products_image = "unknown_tune.jpg";
		$v_products_model = $products_model . PPUNKNOWN;
		$v_products_name_1 = PNUNKNOWN;

		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 for $complete_model provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";
			
		$v_products_description_1 .= &infobox_product_heading (PNUNKNOWN, $openingstats);
		$v_products_description_1 .= &infobox_powercurve ();
		$v_products_description_1 .= &infobox_unknowntune ();
		$v_products_description_1 .= &infobox_otherbenefits ();
		$v_products_description_1 .= &infobox_guarantee ();
		$v_products_description_1 .= &infobox_womostuff ();
		$v_products_description_1 .= END_WRAPPER;

		&insert_store_entry ();
		}

#
# This is for FLASH TUNE
#
	if ($no_tune && $superchips_website->{tune_type} eq "F")
		{
		$v_products_price = &get_tune_price ($superchips_website->{uk_price}, $superchips_website->{engine_type});
		$v_products_image = "flash_tune.jpg";
		$v_products_model = $products_model . PPFLASHTUNE;
		$v_products_name_1 = PNFLASHTUNE;
			
		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 for $complete_model provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";

		$v_products_description_1 .= &infobox_product_heading (PNFLASHTUNE, $openingstats);
		$v_products_description_1 .= &infobox_powercurve ();
		$v_products_description_1 .= &infobox_flashtune ();
		$v_products_description_1 .= &infobox_otherbenefits ();
		$v_products_description_1 .= &infobox_guarantee ();
		$v_products_description_1 .= &infobox_womostuff ();
		$v_products_description_1 .= END_WRAPPER;

		&insert_store_entry ();
		}

#
# This is for BENCH TUNE
#
	if ($no_tune && $superchips_website->{tune_type} eq "B")
		{
		$v_products_price = &get_tune_price ($superchips_website->{uk_price}, $superchips_website->{engine_type}) + BFECUOPENPRICE;
		$v_products_image = "bench_tune.jpg";
		$v_products_model = $products_model . PPBENCHTUNE;
		$v_products_name_1 = PNBENCHTUNE;

		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 for $complete_model provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";

		$v_products_description_1 .= &infobox_product_heading (PNBENCHTUNE, $openingstats);
		$v_products_description_1 .= &infobox_powercurve ();
		$v_products_description_1 .= &infobox_benchtune ();
		$v_products_description_1 .= &infobox_otherbenefits ();
		$v_products_description_1 .= &infobox_guarantee ();
		$v_products_description_1 .= &infobox_womostuff ();
		$v_products_description_1 .= END_WRAPPER;

		&insert_store_entry ();
		}

#
# This is for CHIP CHANGE
#
	if ($no_tune && $superchips_website->{tune_type} eq "C")
		{
		$v_products_price = &get_tune_price ($superchips_website->{uk_price}, $superchips_website->{engine_type}) + BFECUOPENPRICE;
		$v_products_image = "chip_change.jpg";
		$v_products_model = $products_model . PPCHIPCHANGE;
		$v_products_name_1 = PNCHIPCHANGE;
			
		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 for $complete_model provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";

		$v_products_description_1 .= &infobox_product_heading (PNCHIPCHANGE, $openingstats);
		$v_products_description_1 .= &infobox_powercurve ();
		$v_products_description_1 .= &infobox_chipchange ();
		$v_products_description_1 .= &infobox_otherbenefits ();
		$v_products_description_1 .= &infobox_guarantee ();
		$v_products_description_1 .= &infobox_womostuff ();
		$v_products_description_1 .= END_WRAPPER;

		&insert_store_entry ();
		}
	
#
# This is for a STAGE 2 tune
#
	if ($car_data->{superchips_stage2})
		{
		my $superchips_website = &get_tune_info ($car_data->{superchips_stage2}, $get_tune_sth);
		unless (defined $superchips_website)
			{
			next;
			}
		
		my $percentpowerincrease = $car_data->{original_bhp} ? int ($superchips_website->{gain_bhp} / $car_data->{original_bhp} * 100) : 0;
		my $percenttorqueincrease = $car_data->{original_nm} ? int ($superchips_website->{gain_nm} / $car_data->{original_nm} * 100) : 0;
		my $powerincreasekw = int (($superchips_website->{gain_bhp} * 0.746) + 0.5);
		my $powercurve = $superchips_website->{dyno_graph} ? "<p><a href=\"http://www.superchips.co.uk/curves/$superchips_website->{dyno_graph}\"><img src=\"images/icon_curve.png\"></img></a>" : "";
		my $openingstats = "<p><b>Vehicle:</b> $complete_model<br><b>Engine Type:</b> $superchips_website->{engine_type}<br><b>Engine Capacity:</b> $superchips_website->{capacity} cc<br><b>Original Power:</b> $car_data->{original_kw} kW ($car_data->{original_bhp} bhp)<br><b>Original Torque:</b> $car_data->{original_nm} Nm<p><font color=\"green\"><b>Power Gain:</b> $powerincreasekw kW ($superchips_website->{gain_bhp} bhp) = $percentpowerincrease% increase<br><b>Torque Gain:</b> $superchips_website->{gain_nm} Nm = $percenttorqueincrease% increase</font>";

		$v_products_price = &get_tune_price ($superchips_website->{uk_price}, $superchips_website->{engine_type});
		$v_products_image = "flash_tune.jpg";
		$v_products_model = $products_model . PPSTAGE2;
		$v_products_name_1 = PNSTAGE2;
			
		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 for $complete_model provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";

		$v_products_description_1 .= &infobox_product_heading (PNSTAGE2, $openingstats);
		$v_products_description_1 .= &infobox_powercurve ();
		$v_products_description_1 .= &infobox_stage2 ();
		$v_products_description_1 .= &infobox_otherbenefits ();
		$v_products_description_1 .= &infobox_guarantee ();
		$v_products_description_1 .= &infobox_womostuff ();
		$v_products_description_1 .= END_WRAPPER;

		&insert_store_entry ();
		}
	

#
# This is for a STAGE 3 tune
#
	if ($car_data->{superchips_stage3})
		{
		my $superchips_website = &get_tune_info ($car_data->{superchips_stage3}, $get_tune_sth);
		unless (defined $superchips_website)
			{
			next;
			}
		
		my $percentpowerincrease = $car_data->{original_bhp} ? int ($superchips_website->{gain_bhp} / $car_data->{original_bhp} * 100) : 0;
		my $percenttorqueincrease = $car_data->{original_nm} ? int ($superchips_website->{gain_nm} / $car_data->{original_nm} * 100) : 0;
		my $powerincreasekw = int (($superchips_website->{gain_bhp} * 0.746) + 0.5);
		my $powercurve = $superchips_website->{dyno_graph} ? "<p><a href=\"http://www.superchips.co.uk/curves/$superchips_website->{dyno_graph}\"><img src=\"images/icon_curve.png\"></img></a>" : "";
		my $openingstats = "<p><b>Vehicle:</b> $complete_model<br><b>Engine Type:</b> $superchips_website->{engine_type}<br><b>Engine Capacity:</b> $superchips_website->{capacity} cc<br><b>Original Power:</b> $car_data->{original_kw} kW ($car_data->{original_bhp} bhp)<br><b>Original Torque:</b> $car_data->{original_nm} Nm<p><font color=\"green\"><b>Power Gain:</b> $powerincreasekw kW ($superchips_website->{gain_bhp} bhp) = $percentpowerincrease% increase<br><b>Torque Gain:</b> $superchips_website->{gain_nm} Nm = $percenttorqueincrease% increase</font>";

		$v_products_price = &get_tune_price ($superchips_website->{uk_price}, $superchips_website->{engine_type});
		$v_products_image = "flash_tune.jpg";
		$v_products_model = $products_model . PPSTAGE3;
		$v_products_name_1 = PNSTAGE3;
			
		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 for $complete_model provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";

		$v_products_description_1 .= &infobox_product_heading (PNSTAGE3, $openingstats);
		$v_products_description_1 .= &infobox_powercurve ();
		$v_products_description_1 .= &infobox_stage3 ();
		$v_products_description_1 .= &infobox_otherbenefits ();
		$v_products_description_1 .= &infobox_guarantee ();
		$v_products_description_1 .= &infobox_womostuff ();
		$v_products_description_1 .= END_WRAPPER;

		&insert_store_entry ();
		}
	

#
# This is for a STAGE 4 tune
#
	if ($car_data->{superchips_stage4})
		{
		my $superchips_website = &get_tune_info ($car_data->{superchips_stage4}, $get_tune_sth);
		unless (defined $superchips_website)
			{
			next;
			}
		
		my $percentpowerincrease = $car_data->{original_bhp} ? int ($superchips_website->{gain_bhp} / $car_data->{original_bhp} * 100) : 0;
		my $percenttorqueincrease = $car_data->{original_nm} ? int ($superchips_website->{gain_nm} / $car_data->{original_nm} * 100) : 0;
		my $powerincreasekw = int (($superchips_website->{gain_bhp} * 0.746) + 0.5);
		my $powercurve = $superchips_website->{dyno_graph} ? "<p><a href=\"http://www.superchips.co.uk/curves/$superchips_website->{dyno_graph}\"><img src=\"images/icon_curve.png\"></img></a>" : "";
		my $openingstats = "<p><b>Vehicle:</b> $complete_model<br><b>Engine Type:</b> $superchips_website->{engine_type}<br><b>Engine Capacity:</b> $superchips_website->{capacity} cc<br><b>Original Power:</b> $car_data->{original_kw} kW ($car_data->{original_bhp} bhp)<br><b>Original Torque:</b> $car_data->{original_nm} Nm<p><font color=\"green\"><b>Power Gain:</b> $powerincreasekw kW ($superchips_website->{gain_bhp} bhp) = $percentpowerincrease% increase<br><b>Torque Gain:</b> $superchips_website->{gain_nm} Nm = $percenttorqueincrease% increase</font>";

		$v_products_price = &get_tune_price ($superchips_website->{uk_price}, $superchips_website->{engine_type});
		$v_products_image = "flash_tune.jpg";
		$v_products_model = $products_model . PPSTAGE4;
		$v_products_name_1 = PNSTAGE4;
			
		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 for $complete_model provides a performance increase of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";

		$v_products_description_1 .= &infobox_product_heading (PNSTAGE4, $openingstats);
		$v_products_description_1 .= &infobox_powercurve ();
		$v_products_description_1 .= &infobox_stage4 ();
		$v_products_description_1 .= &infobox_otherbenefits ();
		$v_products_description_1 .= &infobox_guarantee ();
		$v_products_description_1 .= &infobox_womostuff ();
		$v_products_description_1 .= END_WRAPPER;

		&insert_store_entry ();
		}
	}
		


#
# Disconnect from database
#
$sth->finish;
$get_tune_sth->finish;
$get_cat_sth->finish;
$dbh->disconnect;

close $logfh;
exit 0;


sub insert_store_entry
{
	if ($v_products_model)
		{
		
		# Remove any commas from the product description
		$v_products_description_1 =~ s/,/&#44;/g;
		
		$insertth->execute ($v_products_model, $v_products_type, $v_products_image, $v_products_name_1, $v_products_description_1, $v_products_url_1, $v_specials_price, $v_specials_date_avail, $v_specials_expires_date, $v_products_price, $v_products_weight, $v_product_is_call, $v_products_sort_order, $v_products_quantity_order_min, $v_products_quantity_order_units, $v_products_priced_by_attribute, $v_product_is_always_free_shipping, $v_date_avail, $v_date_added, $v_products_quantity, $v_manufacturers_name, $v_categories_name_1, $v_tax_class_title, $v_status, $v_metatags_products_name_status, $v_metatags_title_status, $v_metatags_model_status, $v_metatags_price_status, $v_metatags_title_tagline_status, $v_metatags_title_1, $v_metatags_keywords_1, $v_metatags_description_1 );	
		}
}


sub get_tune_info
##########################
# Gets a row from the
# Superchipswebsite table
##########################
{
	my ($tune_id, $sth)  = @_;	
	$sth->execute($tune_id) or die $dbh->errstr;
	my $tune_results = $sth->fetchrow_hashref;
	return $tune_results;
}


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


use constant INFOBOX_START => "<div class=\"infobox";
use constant INFOBOX_THIRD => " onethirdbox\">";
use constant INFOBOX_HALF => " halfbox\">";
use constant INFOBOX_TWOTHIRD => " twothirdbox\">";
use constant INFOBOX_FULL => " fullbox\">";
use constant INFOBOX_LONG => " fullbox longbox\">";
use constant INFOBOX_END => "</div>";
use constant LONGBOX_PIC_START => "<div class=\"longbox_pic\">";
use constant LONGBOX_PIC_END => "</div>";
use constant LONGBOX_TEXT_START => "<div class=\"longbox_text\">";
use constant LONGBOX_TEXT_END => "</div>";

sub infobox_whatisbluefin 
	{
	return INFOBOX_START . INFOBOX_LONG . 
	 LONGBOX_PIC_START . "<img src=\"images/Superchips/bluefin_pic.jpg\" alt=\"Performance With Style at Tigersoft Performance\" />" . LONGBOX_PIC_END .
	 LONGBOX_TEXT_START . "<h2>What Is Bluefin?</h2><hr />" . 
	 "<p>The amazing Superchips Bluefin is a simple hand-held device that allows you to apply a Superchips tune at home by yourself. All you need is a Windows PC with an internet connection</p><p>It is very simple to use, it has just 3 buttons (Y, N and <) and a 2-line display. It walks you through the process of installing the tune.</p>" . LONGBOX_TEXT_END . INFOBOX_END;
	}
	
sub infobox_outofboxtune
	{
	
	}

sub infobox_bluefinFAQ
	{
	
	}


sub infobox_howbluefinworks 
	{
	return INFOBOX_START . INFOBOX_FULL . "<h2>How do I use the Bluefin to install the tune?</h2><hr />
	 <p>Installing the tune using the Bluefin is easy and safe. No specialist skills are required, anyone can do it. Full instructions are provided with the Bluefin.</p>
	 <p>You start by plugging the Bluefin into the OBD port in your car. This is typically under the dash above the driver's feet, but the location can vary. If you can't find it, just ask us and we can tell you where the OBD port will be in your car.<p>
	 <p>As soon as the Bluefin has been plugged into the OBD port, it will power up with a beep. It will display a few short messages such as which make of car the Bluefin is for, and then it will start the process as follows.
	
	 <ul class=\"infobox_list\">
	  <li>The Bluefin will begin by asking you to check that the ignition is OFF, and then to press the 'Y' key</li>
	  <li>It will then ask you to turn the ignition to ON (but don't start the engine) and then press the 'Y' key</li>
	  <li>Depending on the model of car, it may ask you other questions as well, just answer them with the 'Y' and 'N' keys</li>
	  <li>The Bluefin will then begin reading the standards tune from the car. It will display 'Saving Original', and a progress bar to show you how it is going. Depending on the make of car, this could take from 1 to 20 mins</li>
	  <li>When Bluefin has finished, it will beep. It may ask you to turn the ignition off etc, and then it will display 'Install CD-ROM'.</li>
	  <li>Unplug the Bluefin from the car, and take it inside to your computer. Don't plug it in just yet though.</li>
	  <li>Download the latest version of the Bluefin Desktop Software from the <a href=\"http://www.superchips.co.uk/software\">Superchips Website</a>, and install it on your computer.</li>
	  <li>Start the software, and enter your contact information.</li>
	  <li>Now plug the Bluefin into the computer using the supplied USB cable. The drivers will be installed automatically. It may take a minute.</li>
	  <li>Click on the big CONNECT button in the middle of the screen. The Bluefin will now send your original tune off to Superchips in the UK</li>
	  <li>Superchips will send you an email when your tune is ready to download. This typically happens within about 10 mins, but could take upto 8 hours</li>
	  <li>When you have received the email, just plug the Blufin back into the computer, press that big CONNECT button again, and the Bluefin will now get and get your new tune from Superchips.</li>
	  <li>Once the tune has been downloaded, the Bluefin will now hold your Original Tune, and the new Superchips Tune. You can use the Bluefin to swap between the two as you see fit.</li>
	  <li>Take the Bluefin back out to the car and plug it into the OBD port again. The process will be very similar to what you did last time, but instead you will now install the Superchips tune into your car</li>
	  <li>Unplug the Bluefin, and take the car for a spin and enjoy the difference!</li>
	 </ul>" . INFOBOX_END;
	}
	

sub infobox_bluefinenable 
	{
	return INFOBOX_START . INFOBOX_FULL . "<h2>BLUEFIN ENABLE REQUIRED!</h2><hr /><p>PLEASE NOTE: Before the Superchips Bluefin can be used on this car, the ECU needs to be 'Bluefin Enabled'.<br>This requires the ECU to be removed from the car, and then carefully opened up, and the encryption on the ECU defeated. We need to be in touch with Superchips in the UK during the course of this process, and so that means it can only be done overnight, and on a weeknight. This is delicate and time-consuming work, and so the price above includes a \$" . BFECUOPENPRICE . " charge accordingly.<br>Tigersoft Performance is the only Superchips dealer in Australia with the expertise and equipment required to perform this service." . INFOBOX_END;
	}
	

sub infobox_product_heading 
	{
	my $product_type = $_[0];
	my $stats = $_[1];
	
	return INFOBOX_START . INFOBOX_FULL . "<h1>" . $product_type . " to suit:</h1><hr />" . $stats . INFOBOX_END;
	}
	

sub infobox_powercurve 
	{
	my $dyno_graph = $_[0];
	
	if (!length ($dyno_graph))
		{
		return '';
		}
	
	return INFOBOX_START . INFOBOX_HALF . "<h2>Power Curve</h2><hr />" . "<p><a href=\"http://www.superchips.co.uk/curves/$dyno_graph\"><img src=\"images/icon_curve.png\"></img></a>" . INFOBOX_END;
	}
	

sub infobox_unknowntune 
	{
	return INFOBOX_START . INFOBOX_HALF . "<h2>Unknown Tune Type</h2><hr />" . "<p>Our online store is unable to determine if this tune is able to be applied vi the OBD Port (ie: a Flash Tune) or of the ECU needs to be removed from the car (ie: a Bench Tune). This will have an impact on the final price. Please Contact Us for further information" . INFOBOX_END;
	}
	

sub infobox_otherbenefits 
	{
	return INFOBOX_START . INFOBOX_HALF . "<h2>Other Benefits</h2><hr />" . "<p>The real benefits that come from the tune are <ul class=\"infobox_list\"><li>Improved Fuel Economy</li><li>Improved Power and Torque</li><li>Noticeably smoother running</li> <li>Sharper throttle response</li></ul> <p>The car will generally feel more lively and responsive in traffic. More power is well and good, and never goes astray, but the reality is that most people only spend a few percent at most of their daily driving at maximum power. It's the other benefits listed above that are of most use to you for the vast majority of your daily driving. The differences are both noticeable and tangible.<br>You can expect an improvement in fuel economy of around 3% for Naturally Aspirated engines, 5% for Turbo-Petrol engines, and 10% or more for Turbo Diesel engines. Basically, the tune makes your car work more efficiently, giving you usable increases in torque while using less fuel overall." . INFOBOX_END;
	}
	

sub infobox_guarantee 
	{
	return INFOBOX_START . INFOBOX_HALF . "<h2>28-day Money-Back Guarantee</h2><hr />" . 
	 "<img class=\"centrePhoto\" alt=\"Money Back Guarantee at Tigersoft Performance\"
	  src=\"images/Tigersoft%20Performance/money-back-guarantee.jpg\" />
	 <ul class=\"infobox_list\">
	  <li> It's one thing to claim that a tune will give you an
	   extra 'X' kW of power, but how much is that? Will you be
	   able to notice the difference? </li>
	  <li>The Tigersoft Performance 28-day money-back guarantee
	   gives you plenty of time to make up your own mind!</li>
	  <li>Try the tune in every situation you can think of, and if
	   after 28 days you are not happy for whatever reason, just
	   return the product to us for a 100% refund.</li>
	  <li>No Questions Asked! </li> </ul></div>" .
	"<p>Superchips has been around since 1977. They are a well established Tuning House, with a proven record and an outstanding reputation. With Superchips, <strong>Reliability</strong> is always the highest priority. They will never push the standard components of your car beyond their safe operating limits. That's why Superchips is one of the only tuning companies in the world that will provide you a <strong>lifetime warranty against engine damage caused by the tune</strong>.<br>In the case of cars that are still under warranty, the Superchips warranty will supplement your standard warranty to ensure that you are fully covered." . INFOBOX_END;
	}
	
sub infobox_womostuff 
	{
	return INFOBOX_START . INFOBOX_FULL . "<h2>Word Of Mouth Online</h2><hr />" . "<p><table class=\"womoTable\"><tr><td><script type=\"text/javascript\" src=\"http://www.womo.com.au/widget-MDAxMTUyNjcw.js\"></script></td><td><center><img height=200px width=200px src=\"http://www.womo.com.au/uploadedimages/1011676.png?utm_source=womo&utm_medium=email&utm_campaign=serviceaward\"></img><br><b>Tigersoft Performance</b><br>Winners of a 2013 Service award from WOMO</center></td></tr></table>" . INFOBOX_END;
	}
	

sub infobox_flashtune
	{
	return INFOBOX_START . INFOBOX_FULL . "<h2>Flash Tune</h2><hr />" . "<p>The ECU in this car can be Flash Tuned, which is a relatively simple and painless procedure.<p>The entire process is as follows:<ul class=\"infobox_list\"><li>Make an appointment and visit us at out Cheltenham workshop</li><li>While you wait, we will read the existing tune from your car</li><li>We send your information off to Superchips in the UK, and they will send a Superchips Tune for your car back overnight</li><li>You come and visit us again in Cheltenham, and this time we write the new Superchips Tune to your car</li></ul>" . INFOBOX_END;
	}


sub infobox_benchtune
	{
	return INFOBOX_START . INFOBOX_FULL . "<h2>Bench Tune</h2><hr />" . "<p>The ECU in this car has been encrypted, and so to write a tune to the ECU, we need to bypass the encryption and go direct to the ECU itself. This must be done overnight so that we can communicate with Superchips in the UK while the ECU is open, and that means we will need the car (or at least the ECU) overnight. This is a complex and time-consuming proceduren, and so the listed price includes a \$" . BFECUOPENPRICE . " installation fee accordingly" . INFOBOX_END;
	}

sub infobox_chipchange
	{
	return INFOBOX_START . INFOBOX_FULL . "<h2>Chip Change</h2><hr />" . "<p>The ECU in this car uses a Chip (or EPROM) to hold the tune. To replace the tune, we must replace the Chip that holds the tune. This must be done overnight so that we can communicate with Superchips in the UK while the ECU is open, and that means we will need the car (or at least the ECU) overnight. This is a complex and time-consuming procedure, and so the listed price includes a \$" . BFECUOPENPRICE . " installation fee accordingly" . INFOBOX_END;
	}
	
sub infobox_stage2
	{
	return INFOBOX_START . INFOBOX_FULL . "<h2>Stage 2 Tune</h2><hr />" . "<p>This product requires that you already have the Superchips Stage 1 tune (ie the default Superchips tune)" . INFOBOX_END;
	}

sub infobox_stage3
	{
	return INFOBOX_START . INFOBOX_FULL . "<h2>Stage 3 Tune</h2><hr />" . "<p>This product requires that you already have the Superchips Stage 2 tune" . INFOBOX_END;
	}

sub infobox_stage4
	{
	return INFOBOX_START . INFOBOX_FULL . "<h2>Stage 4 Tune</h2><hr />" . "<p>This product requires that you already have the Superchips Stage 3 tune" . INFOBOX_END;
	}

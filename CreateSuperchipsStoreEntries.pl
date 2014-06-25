#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';

use constant LOG => "./log_superchips_entries.TXT";
open (my $logfh, ">", LOG) or die "cannot open " . LOG; 

use constant BFECUOPENPRICE => 400; 
use constant TUNENASPPRICE1 => 599;
use constant TUNENASPPRICE2 => 599;
use constant TUNETURBOPRICE1 =>999;
use constant TUNETURBOPRICE2 => 1099;
use constant TUNETURBOPRICE3 => 1299;

use constant BFNASPPRICE => 499;
use constant BFFORDPRICE => 649;
use constant BFVAGPRICE  => 699;
use constant BFOPELPRICE => 749;

use constant PRO2PRICE => 899;

use constant NONTURBO    => "Non-Turbo Petrol";
use constant TURBOPETROL => "Turbocharged Petrol";
use constant TURBODIESEL => "Turbo-Diesel";

use constant PPBLUEFIN    => "BF"; # Product suffix for Bluefin
use constant PPPRO2       => "P2"; # Product prefix for Pro2
use constant PPFLASHTUNE  => "FT"; # Product prefix for Flash tune
use constant PPBENCHTUNE  => "BT"; # Product prefix for Bench Tune
use constant PPCHIPCHANGE => "CC"; # Product prefix for Bench Tune
use constant PPUNKNOWN    => "UK"; # Product prefix for Bluefin
use constant PPNONE       => "NO"; # Product prefix for None

use constant PNBLUEFIN    => "Superchips Bluefin"; # Product Name for Bluefin
use constant PNPRO2       => "Superchips Pro2"; # Product Name for Pro2
use constant PNFLASHTUNE  => "Superchips Flash Tune"; # Product Name for Flash tune
use constant PNBENCHTUNE  => "Superchips Bench Tune"; # Product Name for Bench Tune
use constant PNCHIPCHANGE => "Superchips Chip Change"; # Product Name for Bench Tune
use constant PNUNKNOWN    => "Superchips Tune"; # Product Name for Bluefin
use constant PNNONE       => "No Tune Whatsoever"; # Product Name for None

use constant SORT_ORDER_START => 100;
use constant SORT_ORDER_INCREMENT => 50;
my $sortorder = SORT_ORDER_START;

$OFS = ',';

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
	SELECT * FROM Categories WHERE idCars = ? AND active = 'Y'
") or die $dbh->errstr;

#
# This is where the grunt work happens
# This main loop reads each row from the Cars table
#
print 'v_products_model,v_products_type,v_products_image,v_products_name_1,v_products_description_1,v_products_url_1,v_specials_price,v_specials_date_avail,v_specials_expires_date,v_products_price,v_products_weight,v_product_is_call,v_products_sort_order,v_products_quantity_order_min,v_products_quantity_order_units,v_products_priced_by_attribute,v_product_is_always_free_shipping,v_date_avail,v_date_added,v_products_quantity,v_manufacturers_name,v_categories_name_1,v_tax_class_title,v_status,v_metatags_products_name_status,v_metatags_title_status,v_metatags_model_status,v_metatags_price_status,v_metatags_title_tagline_status,v_metatags_title_1,v_metatags_keywords_1,v_metatags_description_1' . "\n";
my $car_data = {};
while ($car_data = $sth->fetchrow_hashref)
	{
	my $superchips_website = &get_tune_info ($car_data->{superchips_tune}, $get_tune_sth);
	unless (defined $superchips_website)
		{
		next;
		}
	my $percentpowerincrease = $car_data->{original_bhp} ? int ($superchips_website->{gain_bhp} / $car_data->{original_bhp} * 100) : 0;
	my $percenttorqueincrease = $car_data->{original_nm} ? int ($superchips_website->{gain_nm} / $car_data->{original_nm} * 100) : 0;
	my $powerincreasekw = int (($superchips_website->{gain_bhp} * 0.746) + 0.5);
	my $powercurve = $superchips_website->{dyno_graph} ? "<p><a href=\"http://www.superchips.co.uk/curves/$superchips_website->{dyno_graph}\"><img src=\"images/icon_curve.png\"></img></a>" : "";

	my $guarantee = "<p>When you buy through Tigersoft Performance&#44 you get a 28-day money-back guarantee. That means that you get 28 days to try the tune out in every situation you can think of&#44 and if you are not happy&#44 we will set your car back to stock and give you a full refund&#44 no questions asked.<p>Superchips has been around since 1977. They are a well established Tuning House&#44 with a proven record and an outstanding reputation. With Superchips&#44 Reliability is always the highest priority. They will never push the standard components of your car beyond their safe operating limits. That's why Superchips is one of the only tuning companies in the world that will provide you a lifetime warranty against engine damage caused by the tune.<br>In the case of cars that are still under warranty&#44 the Superchips warranty will supplement your standard warranty to ensure that you are fully covered.";
	my $otherbenefits = "<p>The real benefits that come from the tune are noticeably smoother running&#44 sharper throttle response&#44 and the car will generally feel more lively and responsive. More power is well and good&#44 and never goes astray&#44 but the reality is that most people only spend a few percent at most of their daily driving at maximum power. It's the other benefits listed above that are of most use to you for the vast majority of your daily driving. The differences are both noticeable and tangible.<br>On top of all that&#44 you will also notice an improvement in fuel economy of around 3% for Naturally Aspirated engines&#44 5% for Turbo-Petrol engines&#44 and 10% or more for Turbo Diesel engines. Basically&#44 the tune makes your car work more efficiently&#44 giving you usable increases in torque while using less fuel overall.";
	#my $advert1 = "<br><table width=100%><tr><td><center><big><b>Christmas Special!</b></big><p>Receive 5 Litres of Martini Racing Fully Synthetic Motor Oil <b>ABSOLUTELY FREE</b> when you purchase this tune!</center></td><td><center><img height=200px width=200px src=\"images/sint20_online_store.jpg\"></img></center></td></tr></table>";
	my $advert1 = "";
	my $womostuff = "<p><table width=100%><tr><td><script type=\"text/javascript\" src=\"http://www.womo.com.au/widget-MDAxMTUyNjcw.js\"></script></td><td><center><img height=200px width=200px src=\"http://www.womo.com.au/uploadedimages/1011676.png?utm_source=womo&utm_medium=email&utm_campaign=serviceaward\"></img><br><b>Tigersoft Performance</b><br>Winners of a 2013 Service award from WOMO</center></td></tr></table>";

#### populate the output line:
#
# $1 =	v_products_model,
	my $products_model = sprintf ("TPC%06d", $car_data->{idCars});
# $2 =	v_products_type,
	my $v_products_type = 1;
# $6 =	v_products_url_1,
	my $v_products_url_1 = "";
# $7 =	v_specials_price,
	my $v_specials_price = "";
# $8 =	v_specials_date_avail,
	my $v_specials_date_avail = "";
# $9 =	v_specials_expires_date,
	my $v_specials_expires_date = "";
# $11 =	v_products_weight,
	my $v_products_weight = 0;
# $12 =	v_product_is_call,
	my $v_product_is_call = 0;
# $13 =	v_products_sort_order,
	my $v_products_sort_order = $sortorder;
	$sortorder += SORT_ORDER_INCREMENT;
# $14 =	v_products_quantity_order_min,
	my $v_products_quantity_order_min = 1;
# $15 =	v_products_quantity_order_units,
	my $v_products_quantity_order_units = 1;
# $16 =	v_products_priced_by_attribute,
	my $v_products_priced_by_attribute = 0;
# $17 =	v_product_is_always_free_shipping,
	my $v_product_is_always_free_shipping = 1;
# $18 =	v_date_avail,
	my $v_date_avail = "0000-00-00 00:00:00";
# $19 =	v_date_added,
	my $v_date_added = "2013-12-27 00:25:30";
# $20 =	v_products_quantity,
	my $v_products_quantity = 100;
# $21 =	v_manufacturers_name,
	my $v_manufacturers_name = "Superchips";
# $22 =	v_categories_name_1,
	$get_cat_sth->execute($car_data->{idCars}) or die;
	my $categories = $get_cat_sth->fetchrow_hashref;
	my $v_categories_name_1 = $categories->{longname};
	unless (defined ($v_categories_name_1))
		{
		print $logfh "Can't find Category Name for car $car_data->{idCars}\n";
		next;
		}

# $23 =	v_tax_class_title,
	my $v_tax_class_title = "--none--";
# $24 =	v_status,
	my $v_status = 1;
# $25 =	v_metatags_products_name_status,
	my $v_metatags_products_name_status = 1;
# $26 =	v_metatags_title_status,
	my $v_metatags_title_status = 1;
# $27 =	v_metatags_model_status,
	my $v_metatags_model_status = 1;
# $28 =	v_metatags_price_status,
	my $v_metatags_price_status = 0;
# $29 =	v_metatags_title_tagline_status,
	my $v_metatags_title_tagline_status = 1;
# $30 =	v_metatags_title_1,
	my $v_metatags_title_1 = "";
# $31 =	v_metatags_keywords_1,
	my $v_metatags_keywords_1 = "";
# $32 =	v_metatags_description_1
	my $v_metatags_description_1 = "";

	my $no_tune = 1;
	my $v_products_price  = 0;
	my $v_products_image = "";
	my $v_products_model = "";
	my $v_products_name_1 = "";



	my $carkw = ($car_data->{original_kw} ? " " . $car_data->{original_kw} . "kW": "");
	my $complete_model = $car_data->{make} . " " . (length ($car_data->{variant}) ? $car_data->{variant} : "All Models") . $carkw;
	
	# my $hiddenstats = "<DIV ID=\"hiddenstats1\" STYLE=\"POSITION: absolute; z-index: 4; VISIBILITY: hidden;\">$complete_model. Original Power: $car_data->{original_kw} kW ($car_data->{original_bhp} bhp). Original Torque: $car_data->{original_nm} Nm. Power Gain: $powerincreasekw kW ($superchips_website->{gain_bhp} bhp) = $percentpowerincrease% increase.Torque Gain: $superchips_website->{gain_nm} Nm = $percenttorqueincrease% increase</DIV>";
	my $hiddenstats = "";
	my $openingstats = "<p><b>Vehicle:</b> $complete_model<br><b>Engine Type:</b> $superchips_website->{engine_type}<br><b>Engine Capacity:</b> $superchips_website->{capacity} cc<br><b>Original Power:</b> $car_data->{original_kw} kW ($car_data->{original_bhp} bhp)<br><b>Original Torque:</b> $car_data->{original_nm} Nm<p><font color=\"green\"><b>Power Gain:</b> $powerincreasekw kW ($superchips_website->{gain_bhp} bhp) = $percentpowerincrease% increase<br><b>Torque Gain:</b> $superchips_website->{gain_nm} Nm = $percenttorqueincrease% increase</font>";

	my $v_products_description_1 = "";
#
# This is for BLUEFIN
#
	if ($no_tune && $superchips_website->{bluefin} ne "N")
		{
		$no_tune = 0;
		$v_products_price = &get_bluefin_price ($superchips_website->{make}, $superchips_website->{model}, $superchips_website->{engine_type}, $superchips_website->{capacity});
		$v_products_image = "bluefin_pic.jpg";
		$v_products_model = $products_model . PPBLUEFIN;
		$v_products_name_1 = PNBLUEFIN . " for $complete_model";

		$v_products_description_1 = PNBLUEFIN . " to suit:" . $hiddenstats . "<br>" . $openingstats . $powercurve . $advert1;
		$v_products_description_1 = $v_products_description_1 . "<p><h2>How does the Superchips Bluefin work?</h2><The Bluefin is a small handheld device that allows you to install the Superchips tune for your car by yourself. It is very simple to use&#44 it has just 3 buttons (Y&#44 N and <) and a 2-line display. It walks you through the process of installing the tune.<p>The entire process is as follows:<ol><li>Take the Bluefin out to your car&#44 and plug it into the standard OBD port&#44 usually located under the dash</li><li>The Bluefin will walk you through the process of reading the standard tune from your car&#44 which will be stored on the Bluefin from now on</li><li>Install the supplied software onto your computer (PC only)&#44 and then plug the Bluefin into the computer usng the supplied USB cable</li><li>Press the large CONNECT button in the centre of the screen. This will send your standard tune off to Superchips in the UK.</li><li>Within 8 hours&#44 you will receive and email advising you that your Superchips tune is ready to be downloaded</li><li>Connect the Bluefin to the computer once more and press the big CONNECT button. The software will automatically download the Superchips tune and store it on the Bluefin unit</li><li>Take the Bluefin back out to the car&#44 plug it into the OBD port&#44 and install the Superchips tune</li><li>Take your car for a spin and enoy the difference!</li><li>The car can be swapped between the standard and Superchips tunes as you see fit.</li></ol>";
		$v_products_description_1 = $v_products_description_1 . $otherbenefits;
		if ($superchips_website->{bluefin} eq 'E')
			{
			$v_products_description_1 = $v_products_description_1 . "<p><i>PLEASE NOTE: Before the Superchips Bluefin can be used on this car&#44 the ECU needs to be 'Bluefin Enabled'.<br>This requires the ECU to be removed from the car&#44 and then carefully opened up&#44 and the encryption on the ECU defeated. We need to be in touch with Superchips in the UK during the course of this process&#44 and so that means it can only be done overnight&#44 and on a weeknight. This is delicate and time-consuming work&#44 and so the price above includes a \$" . BFECUOPENPRICE . " charge accordingly.<br>Tigersoft Performance is the only Superchips dealer in Australia with the expertise and equipment required to perform this service.</i>";
			}
			
		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";
		}

#
# This is for PRO2
#
	if ($no_tune && $superchips_website->{pro2} eq "Y")
		{
		$v_products_price = PRO2PRICE;
		$v_products_image = "Superchips Pro2 box picture.jpg";
		$v_products_model = $products_model . PPPRO2;
		$v_products_name_1 = PNPRO2 . " for $complete_model";
			
		$v_products_description_1 = PNPRO2 . " to suit:" . $hiddenstats . "<br>" . $openingstats . $powercurve . $advert1;
		$v_products_description_1 = $v_products_description_1 . $otherbenefits;
		$v_products_description_1 = $v_products_description_1 . "<p>The ECU in this car is of a type that we are unable to tune directly. This is where Superchips' newest product&#44 the Pro2 comes in. It is a Piggy-Back unit that intercepts some of the signals going to the ECU to convince it to produce more power. This approach has several advantagesn&#44 none more important than the fact that it can be installed or removed in only 5 minutes&#44 and once it has been removed&#44 it leaves behind no evidence that it was ever installed!<p>The Pro2 is a sophisticated product&#44 boasting a dual-core 32-bit ARM CPU to ensure that it always keeps ahead of the cars ECU.";

		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";
		}

#
# This is for UNKNOWN TUNE TYPE
#
	if ($no_tune && $superchips_website->{tune_type} eq "?")
		{
		$v_products_price = &get_tune_price ($superchips_website->{uk_price}, $superchips_website->{engine_type});
		$v_products_image = "unknown_tune.jpg";
		$v_products_model = $products_model . PPUNKNOWN;
		$v_products_name_1 = PNUNKNOWN . " for $complete_model";
			
		$v_products_description_1 = PNUNKNOWN . " to suit:" . $hiddenstats . "<br>" . $openingstats . $powercurve . $advert1;
		$v_products_description_1 = $v_products_description_1 . "<p>Our online store is currently unable to determine if this tune is Flash Tune&#44 Bench Tune&#44 or Chip Change&#44 and this will have an impact on the final price. Please Contact Us for more information";
		$v_products_description_1 = $v_products_description_1 . $otherbenefits;

		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";
		}

#
# This is for FLASH TUNE
#
	if ($no_tune && $superchips_website->{tune_type} eq "F")
		{
		$v_products_price = &get_tune_price ($superchips_website->{uk_price}, $superchips_website->{engine_type});
		$v_products_image = "flash_tune.jpg";
		$v_products_model = $products_model . PPFLASHTUNE;
		$v_products_name_1 = PNFLASHTUNE . " for $complete_model";
			
		$v_products_description_1 = PNFLASHTUNE . " to suit:" . $hiddenstats . "<br>" . $openingstats . $powercurve . $advert1;
		$v_products_description_1 = $v_products_description_1 . "<p>The ECU in this car can be Flash Tuned&#44 which is a relatively simple and painless procedure.<p>The entire process is as follows:<ol><li>Make an appointment and visit us at out Cheltenham workshop</li><li>While you wait&#44 we will read the existing tune from your car</li><li>We send your information off to Superchips in the UK&#44 and they will send a Superchips Tune for your car back overnight</li><li>You come and visit us again in Cheltenham&#44 and this time we write the new Superchips Tune to your car</li></ol>";
		$v_products_description_1 = $v_products_description_1 . $otherbenefits;

		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";
		}

#
# This is for BENCH TUNE
#
	if ($no_tune && $superchips_website->{tune_type} eq "B")
		{
		$v_products_price = &get_tune_price ($superchips_website->{uk_price}, $superchips_website->{engine_type}) + BFECUOPENPRICE;
		$v_products_image = "bench_tune.jpg";
		$v_products_model = $products_model . PPBENCHTUNE;
		$v_products_name_1 = PNBENCHTUNE . " for $complete_model";
			
		$v_products_description_1 = PNBENCHTUNE . " to suit:" . $hiddenstats . "<br>" . $openingstats . $powercurve . $advert1;
		$v_products_description_1 = $v_products_description_1 . "<p>The ECU in this car has been encrypted&#44 and so to write a tune to the ECU&#44 we need to bypass the encryption and go direct to the ECU itself. This must be done overnight so that we can communicate with Superchips in the UK while the ECU is open&#44 and that means we will need the car (or at least the ECU) overnight. This is a complex and time-consuming proceduren&#44 and so the listed price includes a \$" . BFECUOPENPRICE . " installation fee accordingly";
		$v_products_description_1 = $v_products_description_1 . $otherbenefits;

		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";
		}

#
# This is for CHIP CHANGE
#
	if ($no_tune && $superchips_website->{tune_type} eq "C")
		{
		$v_products_price = &get_tune_price ($superchips_website->{uk_price}, $superchips_website->{engine_type}) + BFECUOPENPRICE;
		$v_products_image = "chip_change.jpg";
		$v_products_model = $products_model . PPCHIPCHANGE;
		$v_products_name_1 = PNCHIPCHANGE . " for $complete_model";
			
		$v_products_description_1 = PNCHIPCHANGE . " to suit:" . $hiddenstats . "<br>" . $openingstats . $powercurve . $advert1;
		$v_products_description_1 = $v_products_description_1 . "<p>The ECU in this car uses a Chip (or EPROM) to hold the tune. To replace the tune&#44 we must replace the Chip that holds the tune. This must be done overnight so that we can communicate with Superchips in the UK while the ECU is open&#44 and that means we will need the car (or at least the ECU) overnight. This is a complex and time-consuming procedure&#44 and so the listed price includes a \$" . BFECUOPENPRICE . " installation fee accordingly";
		$v_products_description_1 = $v_products_description_1 . $otherbenefits;

		$v_metatags_title_1 = $v_products_name_1;
		$v_metatags_keywords_1 = $v_products_name_1;
		$v_metatags_description_1 = "The $v_products_name_1 provides a performance increases of $powerincreasekw kW and $superchips_website->{gain_nm} Nm along with better fuel economy and smooth flexible driving";
		}

	$v_products_description_1 = $v_products_description_1 . $guarantee . $womostuff;
	print $v_products_model, $v_products_type, $v_products_image, $v_products_name_1, $v_products_description_1, $v_products_url_1, $v_specials_price, $v_specials_date_avail, $v_specials_expires_date, $v_products_price, $v_products_weight, $v_product_is_call, $v_products_sort_order, $v_products_quantity_order_min, $v_products_quantity_order_units, $v_products_priced_by_attribute, $v_product_is_always_free_shipping, $v_date_avail, $v_date_added, $v_products_quantity, $v_manufacturers_name, $v_categories_name_1, $v_tax_class_title, $v_status, $v_metatags_products_name_status, $v_metatags_title_status, $v_metatags_model_status, $v_metatags_price_status, $v_metatags_title_tagline_status, $v_metatags_title_1, $v_metatags_keywords_1, $v_metatags_description_1 . "\n";	
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

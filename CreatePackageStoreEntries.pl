#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use TP;

use constant BLUEFIN_PRICE => 739;
use constant BLUEFIN_SPECIAL_PRICE => 0.925;
use constant BMC_SPECIAL_PRICE => 0.80;
use constant SPECIAL_START => "2014-06-01 00:00:00";
use constant SPECIAL_END => "2014-11-30 00:00:00";


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
my $dsn = "DBI:$driver:;" . "mysql_read_default_file=$my_cnf" . ";mysql_read_default_group=TigersoftPerformance";
my $dbh = DBI->connect($dsn, undef, undef,
	{
	RaiseError => 1, PrintError => 1, mysql_enable_utf8 => 1
	}
) or die $DBI::errstr;

#
# Select all rows from BMCproducts
#
my $get_bmc_sth = $dbh->prepare("
	SELECT * FROM BMCProducts WHERE active = 'Y'
") or die $dbh->errstr;

$get_bmc_sth->execute;

#
# Select a row from BMCStockedProducts based on bmc_part_id
#
my $get_bmcsp_sth = $dbh->prepare("
	SELECT * FROM BMCStockedProducts WHERE bmc_part_id = ?
") or die $dbh->errstr;

my $cars_query = "SELECT * FROM Cars WHERE bmc_car > 0 AND active = 'Y'";
my $sth = $dbh->prepare($cars_query) or die $dbh->errstr;
$sth->execute() or die $dbh->errstr;

#
# Select a row from Categories based on partidnline
#
my $get_cat_sth = $dbh->prepare("
	SELECT * FROM Categories WHERE partid = ? AND active = 'Y'
") or die $dbh->errstr;

#
# Select a row from SuperchipsWebsite based on variant_id
#
my $get_tune_sth = $dbh->prepare("
	SELECT * FROM SuperchipsWebsite WHERE variant_id = ?
") or die $dbh->errstr;

#
# Update/Insert row into ZenCartStoreEntries table
#
my $insertth = $dbh->prepare("
	REPLACE INTO ZenCartStoreEntries VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) 
") or die $dbh->errstr;

#
# Read the joined products from the BMCProducts table
#
my $get_products_sth = $dbh->prepare("
	SELECT u.*, s.*
	FROM BMCProducts u
	    inner join BMCFitment s on u.bmc_part_id = s.BMCProducts_bmc_part_id
	WHERE s.BMCCars_idBMCCars = ?;
") or die $dbh->errstr;

#### populate the output line:
#
# $1 =	v_products_model,
	#my $products_model = ""; sprintf ("TPC%06d", $car_data->{idCars});
# $2 =	v_products_type,
	my $v_products_type = 1;
# $6 =	v_products_url_1,
	my $v_products_url_1 = "";
# $7 =	v_specials_price,
	my $v_specials_price = "";
# $8 =	v_specials_date_avail,
	my $v_specials_date_avail = SPECIAL_START;
# $9 =	v_specials_expires_date,
	my $v_specials_expires_date = SPECIAL_END;
# $11 =	v_products_weight,
	my $v_products_weight = 0;
	my $v_products_qty_box_status = 1;
# $12 =	v_product_is_call,
	my $v_product_is_call = 0;
# $13 =	v_products_sort_order,
	my $v_products_sort_order = $sortorder;
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
	my $v_date_added = "2014-09-13 00:00:00";
# $20 =	v_products_quantity,
	my $v_products_quantity = 100;
# $21 =	v_manufacturers_name,
	my $v_manufacturers_name = "Tigersoft Performance";
# $22 =	v_categories_name_1,

# $23 =	v_tax_class_title,
	my $v_tax_class_title = "Taxable Goods";
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

	my $v_products_price = 0;
	my $v_products_image = "";
	my $v_products_model = "";
	my $v_products_name_1 = "";
	my $v_products_description_1 = "";
	my $v_categories_name_1;



#
# This is where the grunt work happens
# This main loop reads each row from the Cars table
#
my $bmc_data = {};
my $car_data = {};
while ($car_data = $sth->fetchrow_hashref)
	{
	$sortorder = 1000;
	
	if (!$car_data->{superchips_tune} || !$car_data->{bmc_car} || $car_data->{fuel_type} eq "Non-Turbo Petrol")
		{
		next;
		}
	$get_tune_sth->execute ($car_data->{superchips_tune}) or die "could not execute get_tune for car $car_data->{idCars}";
	my $tune_data = $get_tune_sth->fetchrow_hashref;
	if (!defined $tune_data)
		{
		&alert ("ERROR: Found NO Tune Data $car_data->{idCars}, SC Variant $car_data->{superchips_tune}");
		next;
		}
		
	next if $tune_data->{bluefin} ne 'Y';
	my $openingstats = &create_superchips_stats_table ($car_data, $tune_data);






	$get_products_sth->execute ($car_data->{bmc_car}) or die "could not execute get_products for car $car_data->{idCars}";
	my $records = 0;
	while ($bmc_data = $get_products_sth->fetchrow_hashref)
		{
		next if $bmc_data->{type} eq "ACCESSORIES";

		&screen ("Found car $car_data->{idCars} with Bluefin and BMC Product $bmc_data->{bmc_part_id}, $bmc_data->{type}");
		&build_record ($car_data->{idCars}, $openingstats, ++$records);
		
		}
	
	next if !$records;
	
	
		
	
	}

exit 0;




sub build_record
	{
	my ($partid, $openingstats, $record) = @_;
	
	$get_cat_sth->execute ($partid) or die $dbh->errstr;
	my $category = $get_cat_sth->fetchrow_hashref;
	if (!defined $category->{longname})
		{
		&alert ("ERROR: Could not find category for $partid");
		return;
		}
	$v_categories_name_1 = $category->{longname};

	$get_bmcsp_sth->execute($bmc_data->{bmc_part_id}) or die $dbh->errstr;
	my $bmcsp = $get_bmcsp_sth->fetchrow_hashref;
	
	if (!defined $bmcsp->{tp_price})
		{
		&log ("WARNING: Could not find Stocked Products for $bmc_data->{bmc_part_id}");
		return;
		}
	$v_products_price = BLUEFIN_PRICE + $bmcsp->{tp_price};
	$v_specials_price = (BLUEFIN_PRICE * BLUEFIN_SPECIAL_PRICE) + ($bmcsp->{tp_price} * BMC_SPECIAL_PRICE);
	$v_products_image = "package-deal.jpg";


	##############################
	$v_products_model = sprintf ("TPC%06dPK%1d", $partid, $record);
	my $type = $bmc_data->{type};
	if ($type eq "CAR FILTERS")
		{
		$type = "BMC AIR FILTER";
		}
	elsif ($type =~ m/[A-Z][A-Z]A - (.+)/)
		{
		$type = "BMC " . $1;
		}
	else
		{
		&screen ("ERROR: Unknown BMC Product type $type");
		return;
		}
		
	$v_products_name_1 = "Superchips Bluefin + $type";

	$v_products_description_1 = INFOBOX_CONTAINER;
	$v_products_description_1 .= INFOBOX_START . INFOBOX_FULL . "<h1>" . "Superchips Bluefin + BMC $type</h1>" . INFOBOX_END;
	$v_products_description_1 .= INFOBOX_START . INFOBOX_FULL . "<h2>Superchips Bluefin:</h2>" . $openingstats . INFOBOX_END;

	my $title = '<h2 class="bmc_title">' . $bmc_data->{type} ." - ". $bmc_data->{bmc_part_id} . '</h2>';
	my $dims = INFOBOX_SUBTEXT . WIDTH33 . '<div class="bmcdims">';
	$dims .= '<span class="inlineh3">BMC Model:</span><br />' . $bmc_data->{bmc_part_id} . '<br /><br />';
	$dims .= ($bmc_data->{dimname1} ? '<span class="inlineh3">' . $bmc_data->{dimname1} . ': </span>' . $bmc_data->{dimvalue1} . '<br />' : '');
	$dims .= ($bmc_data->{dimname2} ? '<span class="inlineh3">' . $bmc_data->{dimname2} . ': </span>' . $bmc_data->{dimvalue2} . '<br />' : '');
	$dims .= ($bmc_data->{dimname3} ? '<span class="inlineh3">' . $bmc_data->{dimname3} . ': </span>' . $bmc_data->{dimvalue3} . '<br />' : '');
	$dims .= '</div>' . INFOBOX_END;

	my $image = $bmc_data->{image};
	$image =~ s/^.*\///g;
	my $diagram = $bmc_data->{diagram};
	$diagram =~ s/^.*\///g;

	my $pic = INFOBOX_SUBPIC . WIDTH33 . '<img src="images/BMC Air Filters/' . $image . '"alt="' . $v_products_model . '">' . INFOBOX_END;
	my $diag = ($diagram ? INFOBOX_SUBPIC . WIDTH33 . '<img src="images/BMC Air Filters/' . $diagram . '"alt="' . $v_products_model . '">' . INFOBOX_END : "");

	$v_products_description_1 .= INFOBOX_START . INFOBOX_SUB . $title . $dims . $pic . $diag . INFOBOX_END;
	$v_products_description_1 .= INFOBOX_CONTAINER_END;


	$v_metatags_title_1 = $v_products_name_1;
	$v_metatags_keywords_1 = $v_products_name_1;
	$v_metatags_description_1 = $v_products_name_1;
	&insert_store_entry ();
	}




sub insert_store_entry
{
	if ($v_products_model)
		{
		&debug ("Inserting record for $v_categories_name_1, $v_products_model");
		
		$insertth->execute ($v_products_model, $v_products_type, $v_products_image, $v_products_name_1, $v_products_description_1, $v_products_url_1, $v_specials_price, $v_specials_date_avail, $v_specials_expires_date, $v_products_price, $v_products_qty_box_status, $v_products_weight, $v_product_is_call, $v_products_sort_order, $v_products_quantity_order_min, $v_products_quantity_order_units, $v_products_priced_by_attribute, $v_product_is_always_free_shipping, $v_date_avail, $v_date_added, $v_products_quantity, $v_manufacturers_name, $v_categories_name_1, $v_tax_class_title, $v_status, $v_metatags_products_name_status, $v_metatags_title_status, $v_metatags_model_status, $v_metatags_price_status, $v_metatags_title_tagline_status, $v_metatags_title_1, $v_metatags_keywords_1, $v_metatags_description_1 );
		}
}


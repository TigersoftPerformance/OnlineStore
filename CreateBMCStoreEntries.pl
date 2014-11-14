#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use TP;

my $url = 'http://au.bmcairfilters.com';


use constant SPECIAL_PRICE => 0.85;
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
# Select a row from Categories based on partid
#
my $get_cat_sth = $dbh->prepare("
	SELECT * FROM Categories WHERE partid = ? AND active = 'Y'
") or die $dbh->errstr;

#
# Update/Insert row into ZenCartStoreEntries table
#
my $insertth = $dbh->prepare("
	REPLACE INTO ZenCartStoreEntries VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
") or die $dbh->errstr;

#
# Get Rows from BMCProducts based on the corresponding BMCCar
#
my $get_products_sth = $dbh->prepare("
	SELECT u.*, s.*
	FROM BMCProducts u
	    inner join BMCFitment s on u.bmc_part_id = s.BMCProducts_bmc_part_id
	WHERE s.BMCCars_idBMCCars = ?;
") or die $dbh->errstr;

#
# Read rows from the BMCCarEquivilent table
#
my $get_bmccarequiv_sth = $dbh->prepare("
	SELECT * FROM BMCCarEquivilent WHERE BMCCar_master = ?
") or die $dbh->errstr;

#### populate the output line:
#
	#my $products_model = ""; sprintf ("TPC%06d", $car_data->{idCars});
	my $v_products_type = 1;
	my $v_products_url_1 = "";
	my $v_specials_price = "";
	my $v_specials_date_avail = SPECIAL_START;
	my $v_specials_expires_date = SPECIAL_END;
	my $v_products_weight = 0;
	my $v_products_qty_box_status = 1;
	my $v_product_is_call = 0;
	my $v_products_sort_order = $sortorder;
	my $v_products_quantity_order_min = 1;
	my $v_products_quantity_order_units = 1;
	my $v_products_priced_by_attribute = 0;
	my $v_product_is_always_free_shipping = 1;
	my $v_date_added = "2014-09-13 00:00:00";
	my $v_products_quantity = 100;
	my $v_manufacturers_name = "BMC";
	my $v_date_avail = "0000-00-00 00:00:00";

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
while ($bmc_data = $get_bmc_sth->fetchrow_hashref)
	{
	$v_products_sort_order += SORT_ORDER_INCREMENT;

	my $type = $bmc_data->{type};
	$type = "BMC ACCESSORIES" if $type eq "ACCESSORIES";
	&build_record ($bmc_data->{bmc_part_id}, $type, $bmc_data);
	}


$bmc_data = {};
my $car_data = {};
while ($car_data = $sth->fetchrow_hashref)
	{
	my @bmccars = ();
	push @bmccars, $car_data->{bmc_car};
	$get_bmccarequiv_sth->execute($car_data->{bmc_car}) or die "could not execute get_bmccarequiv_sth for car $car_data->{bmc_car}";
	while (my $bmc_car = $get_bmccarequiv_sth->fetchrow_hashref)
		{
		push @bmccars, $bmc_car->{BMCCar_slave};
		}

	my $index = 0;
	while ($index <= $#bmccars)
		{
		debug ("Finding Products for car $car_data->{idCars}, bmc car $bmccars[$index]");
		$get_products_sth->execute ($bmccars[$index]) or die "could not execute get_products for car $car_data->{idCars}";
		my $records = 0;
		while ($bmc_data = $get_products_sth->fetchrow_hashref)
			{
			&build_record (sprintf ("TPC%06d-%s", $car_data->{idCars}, $bmc_data->{bmc_part_id}), $car_data->{idCars}, $bmc_data);
			$records ++;
			}
		if ($records)
			{
			&debug ("Found $records records for Car $car_data->{idCars}, BMCCar $car_data->{bmc_car}");
			}
		else
			{
			&alert ("ERROR: Found NO records for Car $car_data->{idCars}, BMCCar $car_data->{bmc_car}");
			}
		$index ++;
		}



	}

exit 0;

sub build_record
	{
	my ($model, $catlookup, $bmc_data) = @_;

	$v_product_is_call = 0;
	$v_date_avail = "0000-00-00 00:00:00";
	$v_products_price = 0;
	$v_specials_price = 0;

	$get_cat_sth->execute ($catlookup) or die $dbh->errstr;
	my $category = $get_cat_sth->fetchrow_hashref;
	if (!defined $category->{longname})
		{
		&alert ("ERROR: Could not find category for $catlookup");
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
	if ($bmcsp->{availability} eq 'N')
		{
		&debug ("Product Not Available: $bmc_data->{bmc_part_id}");
		return;
		}

	if ($bmcsp->{available_date} !~ m/^0000/)
		{
		$v_date_avail = $bmcsp->{available_date} . " 00:00:00";
		&debug ("Product Available: $v_date_avail");
		}
	
	if ($bmcsp->{tp_price} > 0.05)
		{
		$v_products_price = $bmcsp->{tp_price};
		$v_specials_price = $v_products_price * SPECIAL_PRICE;
		}
	else
		{
		$v_product_is_call = 1;
		&debug ("Price is zero");
		}

	$v_products_image = ($bmc_data->{image} =~ /.*\/(.*)$/i ? $1 : "" ) if $bmc_data->{image};

	my $type = $bmc_data->{type};
	if ($type eq "CAR FILTERS")
		{
		$v_products_sort_order = 200;
		$type = "Replacement Air Filter";
		}
	elsif ($type =~ m/TWIN AIR/)
		{
		$v_products_sort_order = 220;
		$type = "Twin Air Conical Filter";
		}
	elsif ($type =~ m/SINGLE AIR/)
		{
		$v_products_sort_order = 210;
		$type = "Single Air Conical Filter";
		}
	elsif ($type =~ m/SPECIFIC/)
		{
		$v_products_sort_order = 230;
		$type = "Car Specific Kit";
		}
	elsif ($type =~ m/[A-Z][A-Z][AF] - (.+)/)
		{
		$type = join " ", map {ucfirst} split / /, $1;
		if ($type =~ m/(.+) - Cars/)
			{
			$type = $1;
			}
		$v_products_sort_order = 270;
		}
	elsif ($type =~ m/ACCESSORIES/)
		{
		$v_products_sort_order = 290;
		$type = "Accessories";
		}
	elsif ($type =~ m/BIKE/)
		{
		$v_products_sort_order = 299;
		$type = "Bike Filter";
		}
	elsif ($type =~ m/WASH/)
		{
		$v_products_sort_order = 295;
		$type = "Wash Kit";
		}
	else
		{
		&screen ("ERROR: Unknown BMC Product type $type");
		return;
		}


	##############################
	$v_products_model = $model;
	$v_products_name_1 = $type . " - " . $bmc_data->{bmc_part_id};
	if ($bmcsp->{availability} eq 'S')
		{
		&debug ("Product Special Order Only: $bmc_data->{bmc_part_id}");
		$v_products_name_1 .= " (Special Order)";
		}

	$v_products_description_1 = description("BMC Products",$bmc_data->{bmc_part_id},$bmc_data->{description},$bmc_data->{dimname1},$bmc_data->{dimvalue1},$bmc_data->{dimname2},$bmc_data->{dimvalue2},$bmc_data->{dimname3},$bmc_data->{dimvalue3},$bmc_data->{image},$bmc_data->{diagram},$v_products_model);

	# $v_metatags_title_1 = &create_metatags_title ($complete_model, $product_name);
	# $v_metatags_keywords_1 = &create_metatags_keywords ($complete_model, $product_name);
	# $v_metatags_description_1 = &create_metatags_description ($complete_model, $product_name);
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


sub description
########################
# Product Description
########################
{
my ($filter_type,$part,$description,$dimname1,$dimvalue1,$dimname2,$dimvalue2,$dimname3,$dimvalue3,$image,$diagram,$products_model) = @_;
$image ||= "";
$diagram ||="";
$dimname1 ||="";
$dimname2 ||="";
$dimname3 ||="";
$dimvalue1 ||="";
$dimvalue2 ||="";
$dimvalue3 ||="";
$description ||="";
$description =~ s/class=\"red\"/style=\"color:red\"/g;
&debug ("$filter_type,$part,$dimname1,$dimvalue1,$dimname2,$dimvalue2,$dimname3,$dimvalue3,$image,$diagram,$products_model\n");

my $desc = INFOBOX_CONTAINER;

$desc .= INFOBOX_START . INFOBOX_FULL . '<h1 class="bmc_title">' . $filter_type ." - ". $part . '</h1>' . INFOBOX_END;

my $dims = INFOBOX_SUBTEXT . WIDTH33 . '<div class="bmcdims">';
$dims .= '<span class="inlineh3">BMC Model:</span><br />' . $part . '<br /><br />';
$dims .= ($dimname1 ? '<span class="inlineh3">' . $dimname1 . ': </span>' . $dimvalue1 . '<br />' : '');
$dims .= ($dimname2 ? '<span class="inlineh3">' . $dimname2 . ': </span>' . $dimvalue2 . '<br />' : '');
$dims .= ($dimname3 ? '<span class="inlineh3">' . $dimname3 . ': </span>' . $dimvalue3 . '<br />' : '');
$dims .= '</div>' . INFOBOX_END;

$image =~ s/^.*\///g;
$diagram =~ s/^.*\///g;

my $pic = INFOBOX_SUBPIC . WIDTH33 . '<img src="images/BMC Air Filters/' . $image . '"alt="' . $products_model . '">' . INFOBOX_END;
my $diag = ($diagram ? INFOBOX_SUBPIC . WIDTH33 . '<img src="images/BMC Air Filters/' . $diagram . '"alt="' . $products_model . '">' . INFOBOX_END : "");

$desc .= INFOBOX_START . INFOBOX_SUB . $dims . $pic . $diag . INFOBOX_END;

my $avail = ($description =~ /(<table\s*id=\"available\".*?<\/table>)/sgi) ? $1 : '';
$avail =~ s/<th colspan="2" scope="col">(Available For)<\/th>/<h2 class="availablefor">$1<\/h2>/;
$avail =~ s/style="color:red"/class="inlineh3"/g;
$avail =~ s/style=".+"//g;

$desc .= INFOBOX_START . INFOBOX_FULL . $avail . INFOBOX_END;

my $finalbit = ($description =~ /<div class="testo".+?>(.*)<\/div>$/) ? $1 : '';

if (length ($finalbit))
	{
	# must omit the INFOBOX_END here because we left a closing div tag in the finalbit
	$desc .= INFOBOX_START . INFOBOX_FULL . $finalbit;
	}

$desc .= INFOBOX_CONTAINER_END;

$desc =~ s/,/&#44;/g;
return $desc;
}

sub create_metatags_title
	{
	my ($complete_model, $product_name) = @_;
	
	return "$complete_model $product_name Performance Tune Melbourne Australia | Tigersoft Performance Cheltenham"
	}

sub create_metatags_keywords
	{
	my ($complete_model, $product_name) = @_;
	
	return "$complete_model performance tune - $complete_model performance tuning - $complete_model bluefin tune - $complete_model bluefin tuning - $complete_model superchips tune - $complete_model superchips tuning - $complete_model fuel economy - $complete_model save fuel - performance tune - tigersoft performance";
	}

sub create_metatags_description
	{
	my ($complete_model, $product_name) = @_;
	
	return "$complete_model Superchips Performance Tuning in Melbourne Australia by Tigersoft Performance";
	}

#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use TP;


use constant SPECIAL_START => "2014-06-01 00:00:00";
use constant SPECIAL_END => "2014-12-31 00:00:00";


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
# Select all rows from BCFWWebsite
#
my $get_bcfw_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsWebsite WHERE active = 'Y'
") or die $dbh->errstr;
$get_bcfw_sth->execute;

#
# Select base price from BCFWPrices
#
my $get_base_price_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsPrices WHERE series = ? ORDER BY tp_price ASC LIMIT 1
") or die $dbh->errstr;

#
# Select base image from BCFWImages
#
my $get_base_pic_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsImages WHERE model = ? AND title = 'Title Pic'
") or die $dbh->errstr;

#
# Select a row from Categories based on Series
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
	my $v_products_qty_box_status = 0;
# $12 =	v_product_is_call,
	my $v_product_is_call = 0;
# $13 =	v_products_sort_order,
	my $v_products_sort_order = $sortorder;
# $14 =	v_products_quantity_order_min,
	my $v_products_quantity_order_min = 1;
# $15 =	v_products_quantity_order_units,
	my $v_products_quantity_order_units = 1;
# $16 =	v_products_priced_by_attribute,
	my $v_products_priced_by_attribute = 1;
# $17 =	v_product_is_always_free_shipping,
	my $v_product_is_always_free_shipping = 1;
# $18 =	v_date_avail,
	my $v_date_avail = "0000-00-00 00:00:00";
# $19 =	v_date_added,
	my $v_date_added = "2014-09-13 00:00:00";
# $20 =	v_products_quantity,
	my $v_products_quantity = 100;
# $21 =	v_manufacturers_name,
	my $v_manufacturers_name = "BC Forged Wheels";
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
my $bc_data = {};
while ($bc_data = $get_bcfw_sth->fetchrow_hashref)
	{
	debug ("Wheel: $bc_data->{model}");

	$sortorder += SORT_ORDER_INCREMENT;

	# find the series name from the type
	my $series = $1 if $bc_data->{type} =~ m/(\S+ Series)$/;
	unless (defined $series)
		{
		&alert ("Could not determine series from $bc_data->{type}");
		next;
		}

	$get_cat_sth->execute($series) or die;
	my $categories = $get_cat_sth->fetchrow_hashref;
	$v_categories_name_1 = $categories->{longname};
	unless (defined ($v_categories_name_1))
		{
		&alert ("Can't find Category Name for wheel $bc_data->{model}");
		next;
		}
	
	$get_base_price_sth->execute ($series)  or die $dbh->errstr;

	my $bcp = $get_base_price_sth->fetchrow_hashref;
	if (!defined $bcp->{tp_price})
		{
		&alert ("WARNING: Could not find a base price for $series");
		next;
		}
	$v_products_price = $bcp->{RRP} * 4;
	$v_specials_price = $bcp->{tp_price} * 4;

	$get_base_pic_sth->execute ($bc_data->{model})  or die $dbh->errstr;
	my $bcbp = $get_base_pic_sth->fetchrow_hashref;

	$v_products_image = $bcbp->{image};
	if (!defined $v_products_image)
		{
		&log ("WARNING: Could not find a base image for $bc_data->{model}");
		}
	else
		{
		&log ("WARNING: Found Image $v_products_image");
		}
		


	##############################
	$v_products_model = "BCFW" . $bc_data->{model};
	$v_products_name_1 = $bc_data->{model} . " (Set of 4)";
	$v_metatags_title_1 = $v_products_name_1;
	$v_metatags_keywords_1 = $v_products_name_1;
	$v_metatags_description_1 = $v_products_name_1;

	$v_products_description_1 = '<div class="infobox_container"><div class="infobox fullbox bcfwtitle">';
	$v_products_description_1 .= "<h1>$bc_data->{model}</h1>";
	$v_products_description_1 .= "<h3>$bc_data->{type}</h3>";
	$v_products_description_1 .= "<h3>$bc_data->{description}</h3>";
	$v_products_description_1 .= '</div>';

	$v_products_description_1 .= '<div class="infobox halfbox">';
	$v_products_description_1 .= '<h2>Custom Made to Order</h2>';
	$v_products_description_1 .= "<p>All BC Forged Wheels are custom-made to your specificiations.</p>";
	$v_products_description_1 .= "<p>You specify all dimensions and options for your wheels, and then once your order is placed, your wheels will be on your doorstep within 30 days!</p>";
	$v_products_description_1 .= '</div>';
	
	$v_products_description_1 .= '<div class="infobox halfbox">';
	$v_products_description_1 .= '<h2>Why Forged Wheels?</h2>';
	$v_products_description_1 .= "<p>A Forged Wheel is much stronger and lighter than the equivalent ordinary cast wheel, and that means that you can go for a bigger wheel while at the same time getting a lighter and stronger wheel.</p>";
	$v_products_description_1 .= '</div>';
	
	

	if (length $bc_data->{colours})
		{
		my $desc = '<div class="infobox fullbox bcfwcaac"><h2>Colours and Accessories</h2>';
		my @colours = split (/,/, $bc_data->{colours});
		foreach my $colour (@colours)
			{
			if ($colour eq "01")
				{
				$desc .= "<h3>Wheel Stripe Colours</h3>";
				$desc .= '<img alt="BC Forged Wheels Wheel Stripe Colours"
				 title="BC Forged Wheels Wheel Stripe Colours"
				 src = "images/BCWheels/WheelStripeColour.jpg"></img>';
				$desc .= "<h3>Diamond Cut</h3>";
				$desc .= '<img alt="BC Forged Wheels Diamond Cut"
				 title="BC Forged Wheels Diamond Cut"
				 src = "images/BCWheels/DiamondCut.jpg"></img>';
				}
			elsif ($colour eq "02")
				{
				$desc .= "<h3>Standard Colours</h3>";
				$desc .= '<img alt="BC Forged Wheels Standard Colours"
				 title="BC Forged Wheels Standard Colours"
				 src = "images/BCWheels/StandardColours2pc.jpg"></img>';
				$desc .= "<h3>Optional Colours</h3>";
				$desc .= '<img alt="BC Forged Wheels Optional Colours"
				 title="BC Forged Wheels Optional Colours"
				 src = "images/BCWheels/OptionalColours2pc.jpg"></img>';
				}
			elsif ($colour eq "03")
				{
				$desc .= "<h3>Standard Accessories</h3>";
				$desc .= '<img alt="BC Forged Wheels Standard Accessories"
				 title="BC Forged Wheels Standard Accessories"
				 src = "images/BCWheels/CentreCaps1.jpg"></img>';
				$desc .= '<img alt="BC Forged Wheels Standard Accessories"
				 title="BC Forged Wheels Standard Accessories"
				 src = "images/BCWheels/CentreCaps2.jpg"></img>';
				}
			elsif ($colour eq "CAAC")
				{
				$desc .= "<h3>Standard Colours</h3>";
				$desc .= '<img alt="BC Forged Wheels Standard Colours"
				 title="BC Forged Wheels Standard Colours"
				 src = "images/BCWheels/StandardColours1pc.jpg"></img>';
				$desc .= "<h3>Optional Colours 1</h3>";
				$desc .= '<img alt="BC Forged Wheels Optional Colours"
				 title="BC Forged Wheels Optional Colours"
				 src = "images/BCWheels/OptionalColours11pc.jpg"></img>';

				$desc .= "<h3>Optional Colours 2</h3>";
				$desc .= '<img alt="BC Forged Wheels Optional Colours"
				 title="BC Forged Wheels Optional Colours"
				 src = "images/BCWheels/OptionalColours21pc.jpg"></img>';
				$desc .= "<h3>Standard Accessories</h3>";
				$desc .= '<img alt="BC Forged Wheels Standard Accessories"
				 title="BC Forged Wheels Standard Accessories"
				 src = "images/BCWheels/CentreCaps1.jpg"></img>';
				$desc .= '<img alt="BC Forged Wheels Standard Accessories"
				 title="BC Forged Wheels Standard Accessories"
				 src = "images/BCWheels/CentreCaps2.jpg"></img>';
				}
			elsif ($colour eq "CAAC1")
				{
				$desc .= "<h3>Standard Colours</h3>";
				$desc .= '<img alt="BC Forged Wheels Standard Colours"
				 title="BC Forged Wheels Standard Colours"
				 src = "images/BCWheels/StandardColours1pc.jpg"></img>';
				$desc .= "<h3>Optional Colours 1</h3>";
				$desc .= '<img alt="BC Forged Wheels Optional Colours"
				 title="BC Forged Wheels Optional Colours"
				 src = "images/BCWheels/OptionalColours11pc.jpg"></img>';
				}
			elsif ($colour eq "CAAC2")
				{
				$desc .= "<h3>Optional Colours 2</h3>";
				$desc .= '<img alt="BC Forged Wheels Optional Colours"
				 title="BC Forged Wheels Optional Colours"
				 src = "images/BCWheels/OptionalColours21pc.jpg"></img>';
				$desc .= "<h3>Standard Accessories</h3>";
				$desc .= '<img alt="BC Forged Wheels Standard Accessories"
				 title="BC Forged Wheels Standard Accessories"
				 src = "images/BCWheels/CentreCaps1.jpg"></img>';
				$desc .= '<img alt="BC Forged Wheels Standard Accessories"
				 title="BC Forged Wheels Standard Accessories"
				 src = "images/BCWheels/CentreCaps2.jpg"></img>';
				}
			else
				{
				&alert ("Unknown Color $colour");
				}
			}
		$v_products_description_1 .= $desc . '</div>';		
		}
	
	$v_products_description_1 .= &infobox_womostuff ();
	$v_products_description_1 .= '</div>';
	$v_products_description_1 =~ s/,/&#44;/g;

	&insert_store_entry ();

	}



exit 0;


sub insert_store_entry
{
	if ($v_products_model)
		{
		$insertth->execute ($v_products_model, $v_products_type, $v_products_image, $v_products_name_1, $v_products_description_1, $v_products_url_1, $v_specials_price, $v_specials_date_avail, $v_specials_expires_date, $v_products_price, $v_products_qty_box_status, $v_products_weight, $v_product_is_call, $v_products_sort_order, $v_products_quantity_order_min, $v_products_quantity_order_units, $v_products_priced_by_attribute, $v_product_is_always_free_shipping, $v_date_avail, $v_date_added, $v_products_quantity, $v_manufacturers_name, $v_categories_name_1, $v_tax_class_title, $v_status, $v_metatags_products_name_status, $v_metatags_title_status, $v_metatags_model_status, $v_metatags_price_status, $v_metatags_title_tagline_status, $v_metatags_title_1, $v_metatags_keywords_1, $v_metatags_description_1 );
		}
}






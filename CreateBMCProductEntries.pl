#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';

my $url = 'http://au.bmcairfilters.com';
use constant LOGFILE    => "./Logs/MatchCars.log";
use constant ALERTFILE  => "./Logs/MatchCars.alert";
use constant DEBUGFILE  => "./Logs/MatchCars.debug";

open(my $logfh, ">", LOGFILE)     or die "cannot open LOGFILE $!";
open(my $alertfh, ">", ALERTFILE) or die "cannot open ALERTFILE $!";
open(my $debugfh, ">", DEBUGFILE) or die "cannot open DEBUGFILE $!";
$logfh->autoflush;
$alertfh->autoflush;
$debugfh->autoflush;

use constant SPECIAL_PRICE => 0.85;
use constant SPECIAL_START => "2014-06-01 00:00:00";
use constant SPECIAL_END => "2014-07-31 00:00:00";


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
	REPLACE INTO ZenCartStoreEntries VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) 
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
	my $v_manufacturers_name = "BMC";
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
while ($bmc_data = $get_bmc_sth->fetchrow_hashref)
	{
	$sortorder += SORT_ORDER_INCREMENT;

	$get_cat_sth->execute ($bmc_data->{type}) or die $dbh->errstr;
	my $category = $get_cat_sth->fetchrow_hashref;
	if (!defined $category->{longname})
		{
		&screen ("ERROR: Could not find category for $bmc_data->{type}");
		next;
		}
	$v_categories_name_1 = $category->{longname};

	$get_bmcsp_sth->execute($bmc_data->{bmc_part_id}) or die $dbh->errstr;
	my $bmcsp = $get_bmcsp_sth->fetchrow_hashref;
	
	if (!defined $bmcsp->{tp_price})
		{
		&log ("WARNING: Could not find Stocked Products for $bmc_data->{bmc_part_id}");
		next;
		}
	$v_products_price = $bmcsp->{tp_price} - ($bmcsp->{tp_price} / 11);
	$v_specials_price = $v_products_price * SPECIAL_PRICE;
	$v_products_image = ($bmc_data->{image} =~ /.*\/(.*)$/i ? $1 : "" ) if $bmc_data->{image};


	##############################
	$v_products_model = $bmc_data->{bmc_part_id};
	$v_products_name_1 = $bmc_data->{bmc_part_id};
	$v_products_description_1 = description("BMC Products",$bmc_data->{bmc_part_id},$bmc_data->{description},$bmc_data->{dimname1},$bmc_data->{dimvalue1},$bmc_data->{dimname2},$bmc_data->{dimvalue2},$bmc_data->{dimname3},$bmc_data->{dimvalue3},$bmc_data->{image},$bmc_data->{diagram},$v_products_model);
	$v_metatags_title_1 = $v_products_name_1;
	$v_metatags_keywords_1 = $v_products_name_1;
	$v_metatags_description_1 = $v_products_name_1;
	&insert_store_entry ();
	&debug ("CR $bmc_data->{bmc_part_id} ==>");

	}



close $logfh;
exit 0;


sub insert_store_entry
{
	if ($v_products_model)
		{
		$insertth->execute ($v_products_model, $v_products_type, $v_products_image, $v_products_name_1, $v_products_description_1, $v_products_url_1, $v_specials_price, $v_specials_date_avail, $v_specials_expires_date, $v_products_price, $v_products_weight, $v_product_is_call, $v_products_sort_order, $v_products_quantity_order_min, $v_products_quantity_order_units, $v_products_priced_by_attribute, $v_product_is_always_free_shipping, $v_date_avail, $v_date_added, $v_products_quantity, $v_manufacturers_name, $v_categories_name_1, $v_tax_class_title, $v_status, $v_metatags_products_name_status, $v_metatags_title_status, $v_metatags_model_status, $v_metatags_price_status, $v_metatags_title_tagline_status, $v_metatags_title_1, $v_metatags_keywords_1, $v_metatags_description_1 );
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
my $products_description = sprintf("<table style=\"margin:0 auto&#59\"><thead><tr><th colspan=\"3\" style=\"font-family: Impact&#44 Arial&#44 sans-serif&#59font-size: 1.40em&#59font-weight: normal&#59padding: 8px 8px 8px 16px&#59\"> %s </th></tr></thead><tbody><tr>", $filter_type ." - ".$part);
   $products_description .= sprintf("<td width=\"130\" valign=\"top\"><span><font color=\"red\"><b>Code:</b></font></span> %s <br><br><span><font color=\"red\"><b>%s </b></font></span> %s <br><span><font color=\"red\"><b>%s </b></font></span> %s <br><span><font color=\"red\"><b>%s </b></font></span> %s <br></td><td>", $part, ($dimname1 ? "$dimname1:" : ""),$dimvalue1,($dimname2 ? "$dimname2:" : ""),$dimvalue2,($dimname3 ? "$dimname3:" : ""),$dimvalue3);
   $products_description .= sprintf("<img style=\"max-width:200px\" src=\"http://au.bmcairfilters.com/%s\" alt=\"%s\"><br><br></td>",$image,$products_model);
   $products_description .= ($diagram ? sprintf("<td><img style=\"max-width:200px\" src=\"http://au.bmcairfilters.com%s\" alt=\"%s\"><br><br></td></tr></tbody></table>",$diagram,$products_model) : '</tr></tbody></table>');
   $products_description .= (($description =~ /(<table\s*id=\"available\".*?<\/table>)/sgi) ? $1 : '');
   # replace commas with slash to avoid disorder in csv
   $products_description =~ s/\,/\//g;
   $products_description =~ s/\;//g;
return $products_description;
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
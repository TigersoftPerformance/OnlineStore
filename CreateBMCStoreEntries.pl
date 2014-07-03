#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';

use constant LOG => "./log_bmc_entries.TXT";
open (my $logfh, ">", LOG) or die "cannot open " . LOG; 

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
my $dsn = "DBI:$driver:;" . "mysql_read_default_file=$my_cnf";
my $dbh = DBI->connect($dsn, undef, undef,
	{
	RaiseError => 1, PrintError => 1, mysql_enable_utf8 => 1
	}
) or die $DBI::errstr;


my $cars_query = "SELECT * FROM Cars WHERE active = 'Y'";
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
# Select a row from CarFilters based on carID
#
my $get_bmccar_sth = $dbh->prepare("
	SELECT * FROM CarFilters WHERE carID = ?
") or die $dbh->errstr;

#
# Select a row from BMCAirFilters based on part_id
#
my $get_bmc_sth = $dbh->prepare("
	SELECT * FROM BMCAirFilters WHERE part_id = ? AND active = 'Y'
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
#my bmcpartid = {};
while ($car_data = $sth->fetchrow_hashref)
	{
	my $bmcpartids = &get_bmc_info ($car_data->{idCars}, $get_bmccar_sth);
	unless (defined $bmcpartids)
		{
		next;
		}

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
	my $v_specials_date_avail = SPECIAL_START;
# $9 =	v_specials_expires_date,
	my $v_specials_expires_date = SPECIAL_END;
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
	my $v_manufacturers_name = "BMC";
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
	my $v_products_price = 0;
	my $v_products_image = "";
	my $v_products_model = "";
	my $v_products_name_1 = "";
	my $v_products_description_1 = "";

	#my $complete_model = $car_data->{make} . " " . $car_data->{model} . " " . ($car_data->{model_code} ? "(" . $car_data->{model_code} . ") ": "") . (length ($car_data->{variant}) ? $car_data->{variant} : "All Models") . $carkw . $short_date;
	#my $complete_model = $car_data->{model} . " " . (length ($car_data->{variant}) ? $car_data->{variant} : "All Models") . $carkw . $short_date;
	my $carkw = ($car_data->{original_kw} ? " " . $car_data->{original_kw} . "kW": "");
	my $complete_model = $car_data->{make} . " " . (length ($car_data->{variant}) ? $car_data->{variant} : "All Models") . $carkw;

	#print $logfh "$bmcpartids->{carID}\n";
	# Car Filters
	my $bmcpartid = {};
	my $flag = 0;
	if ($bmcpartids->{CR})
		{
		if ($bmcpartid = &get_bmc_info ($bmcpartids->{CR}, $get_bmc_sth))
			{
			$v_products_price = $bmcpartid->{RRP} || 0;
			$v_specials_price = $v_products_price * SPECIAL_PRICE;
			$v_products_image = ($bmcpartid->{image} =~ /.*\/(.*)$/i ? $1 : "" ) if $bmcpartid->{image};
			$v_products_model = $products_model . 'CR';
			$v_products_name_1 = "BMC Air Filter for $complete_model";
			$v_products_description_1 = description("CAR FILTERS",$bmcpartid->{part},$bmcpartid->{dimname1},$bmcpartid->{dimvalue1},$bmcpartid->{dimname2},$bmcpartid->{dimvalue2},$bmcpartid->{dimname3},$bmcpartid->{dimvalue3},$bmcpartid->{image},$bmcpartid->{diagram},$v_products_model);
			$v_metatags_title_1 = $v_products_name_1;
			$v_metatags_keywords_1 = $v_products_name_1;
			$v_metatags_description_1 = $v_products_description_1;
			print $v_products_model, $v_products_type, $v_products_image, $v_products_name_1, $v_products_description_1, $v_products_url_1, $v_specials_price, $v_specials_date_avail, $v_specials_expires_date, $v_products_price, $v_products_weight, $v_product_is_call, $v_products_sort_order, $v_products_quantity_order_min, $v_products_quantity_order_units, $v_products_priced_by_attribute, $v_product_is_always_free_shipping, $v_date_avail, $v_date_added, $v_products_quantity, $v_manufacturers_name, $v_categories_name_1, $v_tax_class_title, $v_status, $v_metatags_products_name_status, $v_metatags_title_status, $v_metatags_model_status, $v_metatags_price_status, $v_metatags_title_tagline_status, $v_metatags_title_1, $v_metatags_keywords_1, $v_metatags_description_1 . "\n";	
			print $logfh "CR $bmcpartids->{CR} ==>";
			}
		else
			{
			$flag++;	
			}		
		}	
	# Carbon Dynamic Airbox	
	if ($bmcpartids->{CDA})
		{
		if ($bmcpartid = &get_bmc_info ($bmcpartids->{CDA}, $get_bmc_sth))
			{
			$v_products_price = $bmcpartid->{RRP} || 0;
			$v_specials_price = $v_products_price * SPECIAL_PRICE;
			$v_products_image = ($bmcpartid->{image} =~ /.*\/(.*)$/i ? $1 : "" ) if $bmcpartid->{image};
			$v_products_model = $products_model . 'CDA';
			$v_products_name_1 = "BMC Carbon Dynamic Airbox for $complete_model";
			$v_products_description_1 = description("CARBON DYNAMIC AIRBOX",$bmcpartid->{part},$bmcpartid->{dimname1},$bmcpartid->{dimvalue1},$bmcpartid->{dimname2},$bmcpartid->{dimvalue2},$bmcpartid->{dimname3},$bmcpartid->{dimvalue3},$bmcpartid->{image},$bmcpartid->{diagram},$v_products_model);
			$v_metatags_title_1 = $v_products_name_1;
			$v_metatags_keywords_1 = $v_products_name_1;
			$v_metatags_description_1 = $v_products_description_1;
			print $v_products_model, $v_products_type, $v_products_image, $v_products_name_1, $v_products_description_1, $v_products_url_1, $v_specials_price, $v_specials_date_avail, $v_specials_expires_date, $v_products_price, $v_products_weight, $v_product_is_call, $v_products_sort_order, $v_products_quantity_order_min, $v_products_quantity_order_units, $v_products_priced_by_attribute, $v_product_is_always_free_shipping, $v_date_avail, $v_date_added, $v_products_quantity, $v_manufacturers_name, $v_categories_name_1, $v_tax_class_title, $v_status, $v_metatags_products_name_status, $v_metatags_title_status, $v_metatags_model_status, $v_metatags_price_status, $v_metatags_title_tagline_status, $v_metatags_title_1, $v_metatags_keywords_1, $v_metatags_description_1 . "\n";	
			print $logfh "CDA $bmcpartids->{CDA} ==>";
			}
		else
			{
			$flag++;	
			}	
		}	
	# Carbon Racing Filter		
	if ($bmcpartids->{CRF})
		{
		if ($bmcpartid = &get_bmc_info ($bmcpartids->{CRF}, $get_bmc_sth))
			{
			$v_products_price = $bmcpartid->{RRP} || 0;
			$v_specials_price = $v_products_price * SPECIAL_PRICE;
			$v_products_image = ($bmcpartid->{image} =~ /.*\/(.*)$/i ? $1 : "" ) if $bmcpartid->{image};
			$v_products_model = $products_model . 'CRF';
			$v_products_name_1 = "BMC Carbon Racing Filter for $complete_model";
			$v_products_description_1 = description("CARBON RACING FILTERS",$bmcpartid->{part},$bmcpartid->{dimname1},$bmcpartid->{dimvalue1},$bmcpartid->{dimname2},$bmcpartid->{dimvalue2},$bmcpartid->{dimname3},$bmcpartid->{dimvalue3},$bmcpartid->{image},$bmcpartid->{diagram},$v_products_model);
			$v_metatags_title_1 = $v_products_name_1;
			$v_metatags_keywords_1 = $v_products_name_1;
			$v_metatags_description_1 = $v_products_description_1;
			print $v_products_model, $v_products_type, $v_products_image, $v_products_name_1, $v_products_description_1, $v_products_url_1, $v_specials_price, $v_specials_date_avail, $v_specials_expires_date, $v_products_price, $v_products_weight, $v_product_is_call, $v_products_sort_order, $v_products_quantity_order_min, $v_products_quantity_order_units, $v_products_priced_by_attribute, $v_product_is_always_free_shipping, $v_date_avail, $v_date_added, $v_products_quantity, $v_manufacturers_name, $v_categories_name_1, $v_tax_class_title, $v_status, $v_metatags_products_name_status, $v_metatags_title_status, $v_metatags_model_status, $v_metatags_price_status, $v_metatags_title_tagline_status, $v_metatags_title_1, $v_metatags_keywords_1, $v_metatags_description_1 . "\n";	
			print $logfh "CRF $bmcpartids->{CRF} ==>";
			}
		else
			{
			$flag++;	
			}	
		}	
	# Oval Trumpet Airbox	
	if ($bmcpartids->{OTA})
		{
		if ($bmcpartid = &get_bmc_info ($bmcpartids->{OTA}, $get_bmc_sth))
			{
			$v_products_price = $bmcpartid->{RRP} || 0;
			$v_specials_price = $v_products_price * SPECIAL_PRICE;
			$v_products_image = ($bmcpartid->{image} =~ /.*\/(.*)$/i ? $1 : "" ) if $bmcpartid->{image};
			$v_products_model = $products_model . 'OTA';
			$v_products_name_1 = "BMC Oval Trumpet Airbox for $complete_model";
			$v_products_description_1 = description("OVAL TRUMPET AIRBOX",$bmcpartid->{part},$bmcpartid->{dimname1},$bmcpartid->{dimvalue1},$bmcpartid->{dimname2},$bmcpartid->{dimvalue2},$bmcpartid->{dimname3},$bmcpartid->{dimvalue3},$bmcpartid->{image},$bmcpartid->{diagram},$v_products_model);	
			$v_metatags_title_1 = $v_products_name_1;
			$v_metatags_keywords_1 = $v_products_name_1;
			$v_metatags_description_1 = $v_products_description_1;
			print $v_products_model, $v_products_type, $v_products_image, $v_products_name_1, $v_products_description_1, $v_products_url_1, $v_specials_price, $v_specials_date_avail, $v_specials_expires_date, $v_products_price, $v_products_weight, $v_product_is_call, $v_products_sort_order, $v_products_quantity_order_min, $v_products_quantity_order_units, $v_products_priced_by_attribute, $v_product_is_always_free_shipping, $v_date_avail, $v_date_added, $v_products_quantity, $v_manufacturers_name, $v_categories_name_1, $v_tax_class_title, $v_status, $v_metatags_products_name_status, $v_metatags_title_status, $v_metatags_model_status, $v_metatags_price_status, $v_metatags_title_tagline_status, $v_metatags_title_1, $v_metatags_keywords_1, $v_metatags_description_1 . "\n";	
			print $logfh "OTA $bmcpartids->{OTA} ==>";
			}
		else
			{
			$flag++;	
			}	
		}	
	# Special Kit	
	if ($bmcpartids->{SPK})
		{
		if ($bmcpartid = &get_bmc_info ($bmcpartids->{SPK}, $get_bmc_sth))
			{
			$v_products_price = $bmcpartid->{RRP} || 0;
			$v_specials_price = $v_products_price * SPECIAL_PRICE;
			$v_products_image = ($bmcpartid->{image} =~ /.*\/(.*)$/i ? $1 : "" ) if $bmcpartid->{image};
			$v_products_model = $products_model . 'SPK';
			$v_products_name_1 = "BMC Special Kit for $complete_model";
			$v_products_description_1 = description("SPECIAL KIT",$bmcpartid->{part},$bmcpartid->{dimname1},$bmcpartid->{dimvalue1},$bmcpartid->{dimname2},$bmcpartid->{dimvalue2},$bmcpartid->{dimname3},$bmcpartid->{dimvalue3},$bmcpartid->{image},$bmcpartid->{diagram},$v_products_model);	
			$v_metatags_title_1 = $v_products_name_1;
			$v_metatags_keywords_1 = $v_products_name_1;
			$v_metatags_description_1 = $v_products_description_1;
			print $v_products_model, $v_products_type, $v_products_image, $v_products_name_1, $v_products_description_1, $v_products_url_1, $v_specials_price, $v_specials_date_avail, $v_specials_expires_date, $v_products_price, $v_products_weight, $v_product_is_call, $v_products_sort_order, $v_products_quantity_order_min, $v_products_quantity_order_units, $v_products_priced_by_attribute, $v_product_is_always_free_shipping, $v_date_avail, $v_date_added, $v_products_quantity, $v_manufacturers_name, $v_categories_name_1, $v_tax_class_title, $v_status, $v_metatags_products_name_status, $v_metatags_title_status, $v_metatags_model_status, $v_metatags_price_status, $v_metatags_title_tagline_status, $v_metatags_title_1, $v_metatags_keywords_1, $v_metatags_description_1 . "\n";	
			print $logfh "SPK $bmcpartids->{SPK} ==>";
			}
		else
			{
			$flag++;	
			}	
		}		
	next if $flag>0;	

	}

#
# Disconnect from database
#
$sth->finish;
$get_bmc_sth->finish;
$get_bmccar_sth->finish;
$get_cat_sth->finish;
$dbh->disconnect;

close $logfh;
exit 0;


sub get_bmc_info
##########################
# Gets a row from the
# Superchipswebsite table
##########################
{
	my ($part_id, $sth)  = @_;	
	$sth->execute($part_id) or die $dbh->errstr;
	my $bmc_results = $sth->fetchrow_hashref;
	return $bmc_results;
}

sub description
########################
# Product Description
########################
{
my ($filter_type,$part,$dimname1,$dimvalue1,$dimname2,$dimvalue2,$dimname3,$dimvalue3,$image,$diagram,$products_model) = @_;	
print $logfh "$filter_type,$part,$dimname1,$dimvalue1,$dimname2,$dimvalue2,$dimname3,$dimvalue3,$image,$diagram,$products_model\n";
my $products_description = sprintf("<table style=\"margin:0 auto&#59\"><thead><tr><th colspan=\"3\" style=\"font-family: Impact&#44 Arial&#44 sans-serif&#59font-size: 1.40em&#59font-weight: normal&#59padding: 8px 8px 8px 16px&#59\"> %s </th></tr></thead><tbody><tr>", $filter_type ." - ".$part);
   $products_description .= sprintf("<td width=\"130\" valign=\"top\"><span><font color=\"red\"><b>Code:</b></font></span> %s <br><br><span><font color=\"red\"><b>%s </b></font></span> %s <br><span><font color=\"red\"><b>%s </b></font></span> %s <br><span><font color=\"red\"><b>%s </b></font></span> %s <br></td><td>", $part, ($dimname1 ? "$dimname1:" : ""),$dimvalue1,($dimname2 ? "$dimname2:" : ""),$dimvalue2,($dimname3 ? "$dimname3:" : ""),$dimvalue3);
   $products_description .= sprintf("<img style=\"max-width:200px\" src=\"http://au.bmcairfilters.com/%s\" alt=\"%s\"><br><br></td><td><img style=\"max-width:200px\" src=\"http://au.bmcairfilters.com%s\" alt=\"%s\"><br><br></td></tr></tbody></table>",$image,$products_model,$diagram,$products_model);
   # replace commas with slash to avoid disorder in csv
   $products_description =~ s/\,/\//g;
   $products_description =~ s/\;//g;
return $products_description;
}


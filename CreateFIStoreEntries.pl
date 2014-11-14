#!/usr/bin/perl
# Create FI Store Entries.
#######################################################

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
# Select all rows from FIStoreLayout 
#
my $get_fistore_sth = $dbh->prepare("
	SELECT * FROM TP.FIStoreLayout 
") or die $dbh->errstr;
$get_fistore_sth->execute() or die $dbh->errstr;

#
# Select one row from FIProducts
#
my $get_fiproduct_sth = $dbh->prepare("
	SELECT * FROM TP.FIProducts WHERE partid = ? and active='Y'
") or die $dbh->errstr;

#
# Select a row from Categories based on idCars
#
my $get_cat_sth = $dbh->prepare("
	SELECT * FROM TP.Categories WHERE shortname = ?
") or die $dbh->errstr;

#
# Update/Insert row into ZenCartStoreEntries table
#
my $insertth = $dbh->prepare("
	REPLACE INTO TP.ZenCartStoreEntries VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
") or die $dbh->errstr;

#
# Global Variables
#
my $v_products_type = 1;
my $v_products_url_1 = "";
my $v_specials_price;
my $v_specials_date_avail;
my $v_specials_expires_date;
my $v_products_qty_box_status = 1;
my $v_products_weight = 0;
my $v_product_is_call = 0;
my $v_products_sort_order;
my $v_products_quantity_order_min = 1;
my $v_products_quantity_order_units = 1;
my $v_products_priced_by_attribute = 0;
my $v_product_is_always_free_shipping = 0;
my $v_date_avail = "0000-00-00 00:00:00";
my $v_date_added = "2014-06-00 00:00:00";
my $v_products_quantity = 100;
my $v_manufacturers_name;
my $v_categories_name_1;
my $v_tax_class_title = "Taxable Goods";
my $v_status = 1;
my $v_metatags_products_name_status = 1;
my $v_metatags_title_status = 1;
my $v_metatags_model_status = 1;
my $v_metatags_price_status = 0;
my $v_metatags_title_tagline_status = 1;
my $v_metatags_title_1;
my $v_metatags_keywords_1;
my $v_metatags_description_1;
my $v_products_price;
my $v_products_image;
my $v_products_model;
my $v_products_name_1;
my $v_products_description_1;

my $fistore = {};
my $fiproduct = {};
while ($fistore = $get_fistore_sth->fetchrow_hashref)
	{
	$get_fiproduct_sth->execute($fistore->{partid}) or die;
	$fiproduct = $get_fiproduct_sth->fetchrow_hashref;
	if (!defined $fiproduct->{partid})
		{
		say "Can't find FI Product " . $fistore->{partid};
		next;
		}
	
	$v_products_model = $fistore->{partid};
	say "Part: $v_products_model";
	$v_products_price = $fiproduct->{rrprice};
	$v_specials_price = $fiproduct->{tpprice};
	$v_specials_date_avail = SPECIAL_START;
	$v_specials_expires_date = SPECIAL_END;
	$v_products_image = $fiproduct->{image};
	$v_products_name_1 = $fiproduct->{name};
	$v_products_description_1 = $fiproduct->{description};
	$v_manufacturers_name = $fiproduct->{manufacturer};
	$v_products_sort_order = $fistore->{sortorder};

	$get_cat_sth->execute($fistore->{category}) or die;
	my $categories = $get_cat_sth->fetchrow_hashref;
	$v_categories_name_1 = $categories->{longname};
	unless (defined ($v_categories_name_1))
		{
		alert ("Can't find Full Category Name for category $fistore->{category}\n");
		next;
		}
		
	$v_metatags_title_1 = $v_products_name_1;
	$v_metatags_keywords_1 = $v_products_name_1;
	$v_metatags_description_1 = $v_products_name_1;

	insert_store_entry ();
	}
exit 0;	
	
sub insert_store_entry
	{
	$insertth->execute ($v_products_model, $v_products_type, $v_products_image, $v_products_name_1, $v_products_description_1, $v_products_url_1, $v_specials_price, $v_specials_date_avail, $v_specials_expires_date, $v_products_price, $v_products_qty_box_status, $v_products_weight, $v_product_is_call, $v_products_sort_order, $v_products_quantity_order_min, $v_products_quantity_order_units, $v_products_priced_by_attribute, $v_product_is_always_free_shipping, $v_date_avail, $v_date_added, $v_products_quantity, $v_manufacturers_name, $v_categories_name_1, $v_tax_class_title, $v_status, $v_metatags_products_name_status, $v_metatags_title_status, $v_metatags_model_status, $v_metatags_price_status, $v_metatags_title_tagline_status, $v_metatags_title_1, $v_metatags_keywords_1, $v_metatags_description_1 )
		or die $dbh->errstr;
	}
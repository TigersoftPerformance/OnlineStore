#!/usr/bin/perl
# Export Store Entries.
#######################################################

use strict;
use warnings;
use DBI;
use English;
use feature 'say';

use constant LOG => "./Logs/ExportStoreEntries.log";
open (my $logfh, ">:encoding(UTF-8)", LOG) or die "cannot open " . LOG; 

$OFS=",";
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
# Select all rows from ZenCartStoreEntries table 
#
my $zcquery = "SELECT * FROM TP.ZenCartStoreEntries";

if (defined $ARGV[0])
	{
	$zcquery .= " WHERE v_categories_name_1 LIKE '" . $ARGV[0] . "%'";
	}

my $store_entries_sth = $dbh->prepare($zcquery) or die $dbh->errstr;
$store_entries_sth->execute() or die $dbh->errstr;

print 'v_products_model,v_products_type,v_products_image,v_products_name_1,v_products_description_1,v_products_url_1,v_specials_price,v_specials_date_avail,v_specials_expires_date,v_products_price,v_products_weight,v_product_is_call,v_products_sort_order,v_products_quantity_order_min,v_products_quantity_order_units,v_products_priced_by_attribute,v_product_is_always_free_shipping,v_date_avail,v_date_added,v_products_quantity,v_manufacturers_name,v_categories_name_1,v_tax_class_title,v_status,v_metatags_products_name_status,v_metatags_title_status,v_metatags_model_status,v_metatags_price_status,v_metatags_title_tagline_status,v_metatags_title_1,v_metatags_keywords_1,v_metatags_description_1' . "\n";
my $storeentries = {};
while ($storeentries = $store_entries_sth->fetchrow_hashref)
	{
	# say "Model = " . $storeentries->{v_products_model};
	# just need to remove excess quotes and new lines from the description
	my $description = $storeentries->{v_products_description_1};
	$description =~ s/\"\"/\"/g;
	$description =~ s/\n//g;

	# Zen Cart expects the specials price to be the before-tax price, so make the change
	my $specials_price = "";
	if ($storeentries->{v_specials_price} < $storeentries->{v_products_price})
	{
	$specials_price = $storeentries->{v_specials_price} - ($storeentries->{v_specials_price} / 11);
	}

	# Now add a Path to the FI Images
	my $image = $storeentries->{v_products_image};
	if ($storeentries->{v_manufacturers_name} eq "Final Inspection")
		{
		$image = "/FIStore/" . $image;
		}
	elsif ($storeentries->{v_manufacturers_name} eq "Superchips")
		{
		$image = "/Superchips/" . $image;
		}
		 
	print $storeentries->{v_products_model}, 
	$storeentries->{v_products_type}, 
	$image, 
	$storeentries->{v_products_name_1}, 
	$description, 
	$storeentries->{v_products_url_1},
	$specials_price, 
	$storeentries->{v_specials_date_avail}, 
	$storeentries->{v_specials_expires_date}, 
	$storeentries->{v_products_price}, 
	$storeentries->{v_products_weight}, 
	$storeentries->{v_product_is_call}, 
	$storeentries->{v_products_sort_order}, 
	$storeentries->{v_products_quantity_order_min}, 
	$storeentries->{v_products_quantity_order_units}, 
	$storeentries->{v_products_priced_by_attribute}, 
	$storeentries->{v_product_is_always_free_shipping}, 
	$storeentries->{v_date_avail}, 
	$storeentries->{v_date_added}, 
	$storeentries->{v_products_quantity}, 
	$storeentries->{v_manufacturers_name}, 
	$storeentries->{v_categories_name_1}, 
	$storeentries->{v_tax_class_title}, 
	$storeentries->{v_status}, 
	$storeentries->{v_metatags_products_name_status}, 
	$storeentries->{v_metatags_title_status}, 
	$storeentries->{v_metatags_model_status}, 
	$storeentries->{v_metatags_price_status}, 
	$storeentries->{v_metatags_title_tagline_status}, 
	$storeentries->{v_metatags_title_1}, 
	$storeentries->{v_metatags_keywords_1}, 
	$storeentries->{v_metatags_description_1}, "\n";
	}
exit 0;	
	

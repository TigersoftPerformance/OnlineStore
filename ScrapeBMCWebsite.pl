#!/usr/bin/perl -w

use strict;
use DBI;
use LWP::Simple;
use feature 'say';
use WWW::Mechanize::Firefox;
use Text::Unidecode;
use utf8;
use English;


# Scrape_mods.pl
BEGIN {

my $mech = WWW::Mechanize::Firefox->new();

my ($marca,$make,$modid,$model);
my $content;
my $url = 'http://au.bmcairfilters.com';
use constant LOG => "./scrape_mods_log";

open (my $logfh, ">", LOG) or die "cannot open " . LOG; 

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

#
# load BMCmod
#
my $loadmodth = $dbh->prepare("
	SELECT * FROM BMCmods where modid =?
") or die $dbh->errstr;

#
# update BMCmod
#
my $updmodth = $dbh->prepare("
	UPDATE BMCmods 
	 SET make = ?, marca = ?, model = ?
	 WHERE modid = ?
") or die $dbh->errstr;

#
# Insert a new row into BMCmod
#
my $insbmcmodth = $dbh->prepare("
	INSERT into BMCmods (make,marca,model,modid) VALUES (?,?,?,?)
") or die $dbh->errstr;


my $retries = 5;
# Try a few times in case of failure
while ($retries && !($content = get $url))
	{
	$retries --;
	}
die "Couldn't get $url" if (!$retries);

#
# collecting marca for all makes
#
$content =~ /<option value="0">(.*?)<\/select>/s;
my $part = $1;

#
# looping through each marcas
#
while ($part =~ /<option value="(\d+)">(.*?)<\/option>/gi)
	{
	$marca = $1;
	$make  = $2;	
	printf "%-20s %s", "marca: $make", " => $marca\n";
	printf $logfh "%-20s %s", "marca: $make", " => $marca\n";

	#
	# here we scrape marca site
	#
	my $marca_url = 'http://au.bmcairfilters.com/search_a.aspx?marca=' . $marca . '&lng=2';
	$retries = 5;
	# Try a few times in case of failure
	while ($retries && !($mech->get($marca_url)))
		{
		$retries --;
		}
	die "Couldn't get $marca_url" if (!$retries);	

	#
	# get marcas content to get modids
	#
	my $marca_content = $mech->content();

	$marca_content =~ /id="ComboModelli" name="ComboModelli"><(.*?)<\/select>/s;
	my $part2 = $1;

	#
	# looping through mods
	#
	while ($part2 =~ /<option value="(\d+)">(.*?)\s*<\/option>/gi)
		{
		$modid = $1;
		$model = $2;	
		&do_db($make,$marca,$model,$modid);
		}
	}


sub do_db
###################################
# Updates data if needed in BMCmods
# Inserts new row if new in BMCmods
################################### 
{
	my ($maketh,$marcath,$modelth,$modth) = @_;	
	my $need_update = 0;
	my $row;

	$loadmodth->execute($modth) or die $dbh->errstr;

	if ($row = $loadmodth->fetchrow_hashref)
		{
		if ($row->{make} ne $maketh)
			{
			$need_update++;	
			print "Make is different $maketh: $row->{make}\n";	
			print $logfh "Make is different $maketh: $row->{make}\n";	
			}	
		if ($row->{marca} != $marcath)
			{
			$need_update++;	
			print "Marca is different $marcath: $row->{marca}\n";	
			print $logfh "Marca is different $marcath: $row->{marca}\n";	
			}
		if ($row->{model} ne $modelth)
			{
			$need_update++;	
			print "Model is different $modelth: $row->{model}\n";	
			print $logfh "Model is different $modelth: $row->{model}\n";	
			}	
		}
	else
		{
		$insbmcmodth->execute($maketh,$marcath,$modelth,$modth) or die $dbh->errstr;
		print "\tNew mod added: $modth\n";	
		print $logfh "\tNew mod added: $modth\n";	
		}	
	if ($need_update>0)
		{
		$updmodth->execute($maketh,$marcath,$modelth,$modth) or die $dbh->errstr;
		print "\tThis $modth needs $need_update update!\n";	
		print $logfh "\tThis $modth needs $need_update update!\n";	
		}	
}


} 



# ScrapeBMCCategories.pl

my $content;
my $url = 'http://au.bmcairfilters.com';
use constant LOG => "./scrape_bmc_categories.log";

open (my $logfh, ">", LOG) or die "cannot open LOG $!"; 

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

#
# This selects a row based on part from BMCAirProducts
#
my $existsbmcairth = $dbh->prepare("
	SELECT * FROM BMCAirProducts WHERE part = ?
") or die $dbh->errstr;

#
# Insert a new row into BMCAirProducts
#
my $insbmcairth = $dbh->prepare("
	INSERT into BMCAirProducts (cat,part,active) VALUES (?,?,?)
") or die $dbh->errstr;

#
# Insert a new row into Categories
#
my $ins_bmccat_sth = $dbh->prepare("
	INSERT INTO Categories (longname, shortname, image, description, active) VALUES (?,?,?,?,?)
") or die $dbh->errstr;

#
# This select is only used to see if Category exists or not
#
my $existsbmccatth = $dbh->prepare("
	SELECT * FROM Categories WHERE longname = ?
") or die $dbh->errstr;

#
# Update existing row in Categories
#
my $updbmccatth = $dbh->prepare("
	UPDATE Categories SET shortname = ?, image = ?,
	 description = ?	
		WHERE longname = ?
") or die $dbh->errstr;

#
# load BMCmod
#
my $loadmodth = $dbh->prepare("
	SELECT * FROM BMCmods
") or die $dbh->errstr;
$loadmodth->execute();


my $retries = 5;
# Try a few times in case of failure
while ($retries && !($content = get $url))
	{
	$retries --;
	}
die "Couldn't get $url" if (!$retries);

my $top_cat = "BMC";
my ($curr_url,$abs_url,$cat_name,$cat_container);


# Look for main categories
while ($content =~ /<li\s+class=\"bar.*?>(.*?)<\/li>/gi)
	{
	$cat_container = $1;

	# Find the names and links of the categories
	if ($cat_container =~/<a href=\"(.*?)\">(.*?)<\/a>/)
		{
		$curr_url = $1;
		$cat_name = $2;
		$top_cat =~ s/(.*)(\^.*?)$/$1/g if $cat_name=~/(WASHING KITS|MERCHANDISING)/i;
		$top_cat .= "^$cat_name";				
		}
	else
		{
		$top_cat = "BMC";	
		if ($cat_container =~/REPLACEMENT FILTERS/i)
			{
			$top_cat .=	"^REPLACEMENT FILTERS";	
			next;
			}
		elsif ($cat_container=~/AIR INTAKE SYSTEMS/i)	
			{
			$top_cat .=	"^AIR INTAKE SYSTEMS";

			# For air intake category
			do_categorization('http://au.bmcairfilters.com/air-intake-systems_pag_ib3_2.aspx',$top_cat);
			next;
			}	
		}	
	# Absolute link of the current category	
	$abs_url = $url . $curr_url;	

	# Go deep into the current category tree
	# and look for sub categories and products
	do_categorization($abs_url,$top_cat);
	
	$top_cat =~ s/(.*)(\^.*?)$/$1/g;
	}

########################
#
# Scrape CAR FILTERS 
#
########################

$url = 'http://au.bmcairfilters.com/ajax/auto.aspx?mod=';
my ($code,$modid_url,@cf,$selected_div,$first_el);
my $product_name = 'BMC^REPLACEMENT FILTERS^CAR FILTERS';

while (my $md = $loadmodth->fetchrow_hashref)
	{
	$modid_url = $url . $md->{modid};

	my $retries = 5;
	# Try more times in case of failure
	while ($retries && !($content = get $modid_url))
		{
		$retries --;
		}
	die "Couldn't get $modid_url" if (!$retries);		
			
	# If we have Car Filters in this page		
	if ($content =~ /id="model-table"(.*?)CAR FILTERS(.*?)<\/div>/sgi)
		{
		$selected_div = $2;
		@cf =();
		while ($selected_div =~/<a href=.*?>\s*(.*?)\s*<\/a>/sgi) 
			{
			# Product Code	
			$code = $1;	
			$first_el = $cf[0] || "";

			# Get rid of repeated codes
			next if $code eq $first_el;	
			unshift @cf, $code;
			}

		# Add Product Codes into BMCAirProduct table	
		for (@cf)
			{
			$existsbmcairth->execute($_);
			my $prd_table = $existsbmcairth->fetchrow_hashref;
			unless (defined ($prd_table))
				{
				$insbmcairth->execute($product_name,$_,"Y"); 
				&screen1("\t\tNew Product: $product_name : $_");
				}
			else
				{
				&screen1("\t$product_name : $_");	
				}	

			}	

		}
	else
		{
		next;	
		}	
	
	}

close $logfh;


##############################################
############  End of main program  ###########
##############################################


sub do_categorization
#####################################
#
# Sub o_categorization
# Arg1 = Category url
# Arg2 = Category
#
#####################################
{
	my ($c_url,$c_name) = @_;
	my ($c_cont,$c_list,$c_plist);
	my ($c_short,$c_desc,$c_image,$c_note) = ('')x4;

	# Category longname
	$c_name =~ /(.*\^)(.*?)$/;

	# Category shortname
	$c_short = $2;
	  
	$retries = 5;
	# Try a few times in case of failure
	while ($retries && !($c_cont = get $c_url))
		{
		$retries --;
		}
	die "Couldn't get $c_url" if (!$retries);


	if ($c_cont =~ /<div\s*id=\"cont-page\">
				(.*?)
				<div\s*class=\"productbox\"(.*?)<\/div>
			   /xsgi
		  )	
		{

		# Description of the Category (with images)
		$c_desc = $1;

		# Product list container
		$c_plist = $2;

		# Semicolon replacement with html entity
		$c_desc =~ s/\;/\&#59/g;

		# Comma replacement
		$c_desc =~ s/,/\&#44/g;

		# Add new or Update existing category 
		do_db_c($c_name,$c_short,$c_desc,$c_image,$c_note);	

		# Loop through product lists
		while ($c_plist=~/<a href=\"(.*?)\".*?>(.*?)<\/a>/sgi)
			{
			$c_name .= "^" . $2;	

			do_categorization($url . $1,$c_name);
			$c_name =~ s/(.*)(\^.*?)$/$1/g;
			}

		}
	# Get the div id="cont-page" content
	elsif ($c_cont =~ /<div\s*id=\"cont-page\">
				(.*?)
				<\/div>
				(.*?)<input\s*type=\"hidden\"
			   /xsgi
	   )	 
		{  

		# Description of the Category (with images)
		$c_desc = $1;

		# This part contains Product lists if any
		$c_list = $2;

		# Comma replacement
		$c_desc =~ s/,/\&#44/g;

		# Semicolon replacement with html entity
		$c_desc =~ s/\;/\&#59/g;

		# Add new or Update existing category 
		do_db_c($c_name,$c_short,$c_desc,$c_image,$c_note);

		# Looping through Product lists' tables	
		while ($c_list=~/<table summary=\"Products List\"(.*?)<\/table>/sgi)
			{
			# Parse Product lists' tables 
			# and do db things
			parse_product_list($c_name,$1);
			}
		}	
}


sub parse_product_list
#####################################
#
# Sub o_categorization
# Arg1 = Category path
# Arg2 = Html part 
#
#####################################
{
	my ($p_name,$p_list) = @_;
	my ($p_short,$p_desc,$p_image,$p_note,$p_code)=('')x5;
	my (@arr,$p_part1);
	my $fl = 0;

	while ($p_list =~ /<tr>(.*?)<\/tr>/sgi)
		{
		# Table row container	
		$p_part1 = $1;	

		# Check to see table type (2 column/4 column)
		while ($p_part1 =~ /<th.*?>(.*?)<\/th>\s*/sgi) 
			{
			push @arr, $1;
			}

		# Check to see if we have subcategory	
		if (scalar @arr == 4)
			{
			$p_name .= "^" . $arr[0];
			@arr = ();	
			$fl = 1;
			next;
			}
		# Skip to the next rules 
		# when table header 	
		elsif (scalar @arr == 2)
			{
			@arr = ();	
			next;	
			}	
				
		# Parsing data	
		while ($p_part1 =~ /<td.*?
							(valign=\"top\")? 		   # image or note
							>
							(<img.*\/(.*\.jpg))?	   # image
							(<a\s*href.*?>(.*?)<\/a>)? # code
							(.*?)
							<\/td>
						   /xsgi
			)
			{
				
			# Main image of the current table	
			$p_image = $3 if $1 && $2;

			# Note of the current table
			$p_note = $6 if $1 && !$2;	

			# Remove <p> tags from Note, we may need that though
			$p_note =~ s/<\/?p>//gi;

			# BMC product code
			$p_code = $5 if $5;

			}

			# Add current BMC product code to the 
			# BMCAirProduct table if not exists
			# ScrapeBMCAirProducts.pl should be run after this
			# to scrape data for the BMC product Code
			$existsbmcairth->execute($p_code);
			my $prd_table = $existsbmcairth->fetchrow_hashref;
			unless (defined ($prd_table))
				{
				$insbmcairth->execute($p_name,$p_code,"Y"); 
				&screen1("\t\tNew Product: $p_name : $p_code");
				}
			else
				{
				&screen1("\tProduct $p_name : $p_code");	
				}	
			
		}

	# Category longname
	$p_name =~ /(.*\^)(.*?)$/;

	# Category shortname
	$p_short = $2;	

	# Add new or Update existing category if subcategory
	do_db_c($p_name,$p_short,$p_desc,$p_image,$p_note) if $fl;
}


sub do_db_c
#############################
# Add new or Update existing 
# category in Categories
#############################
{
	my ($name,$short,$desc,$image,$note) = @_;
	$desc ||= $note;
	# Add current Category data to the 
	# Categories table if not exists
	$existsbmccatth->execute($name);
	my $cat_table = $existsbmccatth->fetchrow_hashref;
	unless (defined ($cat_table))
		{	
		$ins_bmccat_sth->execute($name,$short,$image,$desc,"Y"); 
		&screen1("\tNew Category : $name");
		}
	# Look for changes if any	
	elsif ( $cat_table->{shortname} ne $short ||
			$cat_table->{description} ne $desc ||
			$cat_table->{image} ne $image
	  	  )
		{
		$updbmccatth->execute($short,$image,$desc,$name);
		&screen1("Updated category $name");	
		}
	else	
		{
		&screen1("Category $name");	
		}
}

sub screen1
	{
	my $line = shift;
	say $line;
	say $logfh $line;
	}


# ScrapeBMCProducts.pl
END {

use constant BMCWEBSITE => "http://au.bmcairfilters.com";
use constant LOGFILE    => "./ScrapeBMCAirProducts.log";
use constant ALERTFILE  => "./ScrapeBMCAirProducts.alert";
use constant DEBUGFILE  => "./ScrapeBMCAirProducts.debug";

# 
# Open log/alert/debug files
#
open(my $logfh, ">", LOGFILE)     or die "cannot open LOGFILE $!";
open(my $alertfh, ">", ALERTFILE) or die "cannot open ALERTFILE $!";
open(my $debugfh, ">", DEBUGFILE) or die "cannot open DEBUGFILE $!";

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

#
# Query to get each active known product from the BMCAirProducts table
#
my $load_filters_sth = $dbh->prepare("
	SELECT * FROM BMCAirProducts WHERE active = 'Y'
") or die $dbh->errstr;
$load_filters_sth->execute() or die $dbh->errstr;

#
# This row is used to actually get the data
#
my $getbmcairth = $dbh->prepare("
	SELECT * FROM BMCAirProducts WHERE part_id = ?
") or die $dbh->errstr;

#
# Update existing row into BMCAirProducts
#
my $updbmcairth = $dbh->prepare("
	UPDATE BMCAirProducts SET part = ?, buy_price = ?, RRP = ?, type = ?, description=?, image = ?, diagram = ?,
		dimname1 = ?, dimvalue1 = ?, dimname2 = ?, dimvalue2 = ?, dimname3 = ?, dimvalue3 = ?
		WHERE part_id = ?
") or die $dbh->errstr;

#
# Get the data from BMCAirFlters
#
my $getbmcairfilth = $dbh->prepare("
	SELECT * FROM BMCAirFilters WHERE part = ?
") or die $dbh->errstr;


# Create images directory for images and diagrams
unless (-d 'images')
	{
	mkdir "images" or die "cannot";	
	}

#
# This is the start of the main loop. It gets each product from the BMC  website, and checks for changes. 
#
while (my $filter_h = $load_filters_sth->fetchrow_hashref())
	{
	my $content;
	my $url = BMCWEBSITE;
	my $site_url = BMCWEBSITE;
	my $type = "";
	my $model_code = "";
	
	&screen ($filter_h->{part});

	#
	# Build a URL in the form of
	# http://au.bmcairfilters.com/search_c.aspx?param=ACCDASP-26&page=1&lng=2
	# and then go get the content
	#
	$url = $url . "//search_c.aspx?param=" . $filter_h->{part} . "&page=1&lng=2";
	my $retries = 5;
	# Try a few times in case of failure
	while ($retries && !($content = get $url))
		{
		$retries --;
		}
	die "Couldn't get $url" if (!$retries);	
	if ($content =~ /No Products Found/)
		{
		&alert ( "\tNo Products Found for part $filter_h->{part}");
		next;
		}		
	
	#
	# OK, so we have a page with some content, 
	# This page holds a list of products found matching the search URL above. So now we have to scan the list looking for products
	#
	&debug ($url);
	if (($content =~ /<tbody>/g) && ($content =~ /<tr>/g))
		{
		my $loop_count = 0;
		#
		# For each model listed on this page, each model is in a seperate table row
		#
		
		while ($content =~ /<td width=/g)
			{
			$loop_count ++;
			#
			# Get the "type" of filter product
			#
			$type = $1 if $content =~ /<td>(.+?)<\/td>/g;
			#
			# Now get the url for the product info page and the model_code
			if ($content =~ /<td><a href="(.+?)">(.+?)\s*<\/a>/g)
				{
				$site_url = $1;
				$model_code = $2;
				if ($loop_count == 1)
					{
					if ($model_code eq $filter_h->{part})
						{
						&get_product_info ($filter_h->{part_id}, $model_code, $type, $site_url);
						}
					}
				}
			}
		}
	}	


close $logfh;
close $alertfh;
close $debugfh;

##############################################
############  End of main program  ###########
##############################################


sub get_product_info
#####################################
#
# Sub get_product_info
# Arg1 = The Part id in the table
# Arg2 = The model code
# Arg3 = Type
# Arg3 = The URL of the product info page for the model
#
#####################################
	{
	my ($part_id, $model_code, $type, $url) = @_;
	my ($content, $myline, $make, $model);
	my ($hp, $year, $photo);
	my ($buy_price,$rrp) = ('0')x2;
	my $hpyear = "";
	my $diagram = "";
	#
	# These are the various "States" of the state machine
	#
	my ($avail, $foundmake, $dimensions, $looking_for_photo) = (0)x4;
	my ($in_photo, $looking_for_diagram, $in_diagram) = (0)x3;
	my $description = '';

	# 
	# Stuff for managing dimensions
	#
	use constant MAX_DIMENSIONS => 3;
	my (@dimension_names, @dimension_values);
	my $dimension_count = 0;

	$getbmcairfilth->execute($model_code);

	# Read price information from BMCAirFilter table
	if( my $filter = $getbmcairfilth->fetchrow_hashref)
		{
		$buy_price = $filter->{buy_price};
		$rrp = $filter->{RRP};	
		}

	# 
	# go get the product info page
	#
	my $retries = 5;
	# Try a few times in case of failure
	while ($retries && !($content = unidecode (get BMCWEBSITE . '/' . $url)))
		{
		$retries --;
		}
	die "Couldn't get $url" if (!$retries);
	
	#
	# Split the content in the lines, and start scanning down the list, AWK-style
	#

	$content =~ /<table\s*summary=\"Products\s*List\"(.*?)<\/table>\s*
				(<table\s*id=\"available\".*?<\/table>)?\s*
				(<div\s*class=\"testo\".*?<\/div>)?
	/xsgi;
	$content = $1;
	$description .= $2 if $2;
	$description .= $3 if $3;

	# Removing a tags
	$description =~s/<\/?a.*?>//g;

	# Modifications for image tag 
	$description =~ s/\/ThumbGen.ashx\?path=\/cgi-bin\///;
	$description =~ s/\&.*?(width=\d+).*?\"\s*alt/\" $1 alt/;

	$description =~ s/\&nbsp;//g;

	# Semicolon replacement with html entity
	$description =~ s/\;/\&#59/g;

	# Comma replacement
	$description =~ s/,/\&#44/g;

	foreach my $line (split qr/\R/, $content)
		{
		#
		# Check to see if we are in the dimensions section
		#
		if ($line =~ /<td  width="100" valign="top"><span class="red">Code:/)
			{
			$dimensions = 1;
			next;
			}
		#
		# Only execute this code if we are inside the dimensions section
		# Take first 3 dimensions with values if any
		#
		if ($dimensions)
			{
			if ($line =~ /<span class="red">(.+?): <\/span>(.+?)<br \/>/)
				{
				$dimension_count ++;
				if ($dimension_count <= MAX_DIMENSIONS)
					{
					$dimension_names[$dimension_count] = $1;
					$dimension_values[$dimension_count] = $2;
					}
				else
					{
					&screen ( "Too Many Dimensions for $model_code");
					}
				next;
				}
			# 
			# Check to see if we have dropped out of the dimensions section
			#
			if ($line =~ /<\/td>/)
				{
				$dimensions = 0;
				$looking_for_photo = 1;
				next;
				}
			}
		if ($looking_for_photo && $line =~ /<td >/)
			{
			$in_photo = 1;
			$looking_for_photo = 0;
			next;
			}
		#
		# So if we are inside the photo section, look for the path of the image
		#
		if ($in_photo && $line =~ /<img src="(.+?)" alt="/)
			{
			$photo = $1;
			$photo =~ s/\/ThumbGen.ashx\?path=//;
			$photo =~ s/\&.*$//;

			&debug ( "\tPhoto = $photo");
			$in_photo = 0;
			$looking_for_diagram = 1;
			next;
			}
		if ($looking_for_diagram && $line =~ /<td colspan="2" style="text-align:center;/)
			{
			$in_diagram = 1;
			$looking_for_diagram = 0;
			next;
			}
		#
		# if we are inside the diagram section, look for the path of the diagram
		#
		if ($in_diagram && $line =~ /<img src="(.+?)" alt="/)
			{
			$diagram = $1;
			$diagram =~ s/\/ThumbGen.ashx\?path=//;
			$diagram =~ s/\&.*$//;

			&debug ("\tDiagram = $diagram");
			$in_diagram = 0;
			next;
			}

		}

	&update_bmcairproducts_row ($part_id, $model_code,$buy_price,$rrp, $type, $description, $photo, $diagram, $dimension_count, \@dimension_names, \@dimension_values);
	}



sub update_bmcairproducts_row
#####################################
#
# This sub creates a new record in the BMCCars table 
#
#####################################
	{
	my ($part_id, $part,$buy_price,$rrp, $type, $description, $image, $diagram, $dimension_count, $dimnames, $dimvalues) = @_; 
	my $needchange = 0;


	# save images
	while ($description =~/<img src=\"(.*?\.jpg)\"/sgi)
		{
		my $curr_img = $1;	
		my $url_img_d = BMCWEBSITE .'/cgi-bin/' . $image;
		my $imgs = "images" . $1 if $curr_img =~ /.*(\/.+)$/;
		my $rc1 = getstore($url_img_d, $imgs);
		&alert("getstore of <$url_img_d> failed with $rc1") if (is_error($rc1));
		}

	# save image to the image folder
	if ($image) 
		{
		my $url_img = BMCWEBSITE . $image;
		my $img = "images" . $1 if $image =~ /.*(\/.+)$/;
		my $rc2 = getstore($url_img, $img);
		&alert("getstore of <$url_img> failed with $rc2") if (is_error($rc2));
		}

	# save image to the image folder
	if ($diagram) 
		{
		my $url_diag = BMCWEBSITE . $diagram;
		my $diag = "images" . $1 if $diagram =~ /.*(\/.+)$/;
		my $rc3 = getstore($url_diag, $diag);
		&alert("getstore of <$url_diag> failed with $rc3") if (is_error($rc3));
		}	


	$getbmcairth->execute ($part_id) or die $dbh->errstr;
	if (my $bmcair = $getbmcairth->fetchrow_hashref())
		{
		if ($bmcair->{'part'} ne $part)
			{
			die "Part does not match! =$bmcair->{'part'}=$part=";
			$needchange++;
			}
		if (defined $bmcair->{'buy_price'})
			{
			if ($bmcair->{'buy_price'} ne $buy_price)
				{
				&alert ( "buy_price does not match! =$bmcair->{'buy_price'}=$buy_price=");
				$needchange++;
				}
			}
		else	{$needchange++;}	

		if (defined $bmcair->{'type'})
			{
			if ($bmcair->{'type'} ne $type)
				{
				&alert ( "type does not match! =$bmcair->{'type'}=$type=");
				$needchange++;
				}
			}
		else	{$needchange++;}

		if (defined $bmcair->{'description'})
			{
			if ($bmcair->{'description'} ne $description)
				{
				&alert ( "description does not match!");
				$needchange++;
				}
			}
		else	{$needchange++;}
		
		if (defined $bmcair->{'image'})
			{
			if ($bmcair->{'image'} ne $image)
				{
				&alert ( "image does not match! =$bmcair->{'image'}=$image=");
				$needchange++;
				}
			}
		else	{$needchange++;}
				
		if (defined $bmcair->{'diagram'})
			{
			if ($bmcair->{'diagram'} ne $diagram)
				{
				&alert ( "diagram does not match! =$bmcair->{'diagram'}=$diagram=");
				$needchange++;
				}
			}
		else	{$needchange++;}
				
		if (defined $bmcair->{'dimname1'})
			{
			if ($dimension_count >= 1 && $bmcair->{'dimname1'} ne $dimnames->[1])
				{
				&alert ( "dimname1 does not match! =$bmcair->{'dimname1'}=$dimnames->[1]=");
				$needchange++;
				}
			}
		else	{$needchange++;}
				
		if (defined $bmcair->{'dimvalue1'})
			{
			if ($dimension_count >= 1 && $bmcair->{'dimvalue1'} ne $dimvalues->[1])
				{
				&alert ( "dimvalue1 does not match! =$bmcair->{'dimvalue1'}=$dimvalues->[1]=");
				$needchange++;
				}
			}
		else	{$needchange++;}
				
		if (defined $bmcair->{'dimname2'})
			{
			if ($dimension_count >= 2 && $bmcair->{'dimname2'} ne $dimnames->[2])
				{
				&alert ( "dimname2 does not match! =$bmcair->{'dimname2'}=$dimnames->[2]=");
				$needchange++;
				}
			}
		else	{$needchange++;}
				
		if (defined $bmcair->{'dimvalue2'})
			{
			if ($dimension_count >= 2 && $bmcair->{'dimvalue2'} ne $dimvalues->[2])
				{
				&alert ( "dimvalue2 does not match! =$bmcair->{'dimvalue2'}=$dimvalues->[2]=");
				$needchange++;
				}
			}
		else	{$needchange++;}
				
		if (defined $bmcair->{'dimname3'})
			{
			if ($dimension_count >= 3 && $bmcair->{'dimname3'} ne $dimnames->[3])
				{
				&alert ( "dimname3 does not match! =$bmcair->{'dimname3'}=$dimnames->[3]=");
				$needchange++;
				}
			}
		else	{$needchange++;}
				
		if (defined $bmcair->{'dimvalue3'})
			{
			if ($dimension_count >= 3 && $bmcair->{'dimvalue3'} ne $dimvalues->[3])
				{
				&alert ( "dimvalue3 does not match! =$bmcair->{'dimvalue3'}=$dimvalues->[3]=");
				$needchange++;
				}
			}
		else	{$needchange++;}
			
		if ($needchange)
			{
			&alert ("Updating record for $part");
			$updbmcairth->execute($part,$buy_price,$rrp, $type, $description, $image, $diagram, 
				$dimension_count >=1 ? $dimnames->[1] : "", $dimension_count >=1 ? $dimvalues->[1] : "", 
				$dimension_count >=2 ? $dimnames->[2] : "", $dimension_count >=2 ? $dimvalues->[2] : "", 
				$dimension_count >=3 ? $dimnames->[3] : "", $dimension_count >=3 ? $dimvalues->[3] : "",
				$part_id) or die $dbh->errstr;
			}
		}
	else
		{
		die "Could not read BMC Air Products Record!";
		}
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
	
}
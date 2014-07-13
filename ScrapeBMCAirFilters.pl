#!/usr/bin/perl
# Perl script for scraping the BMW Air filters website for product information. 
# John Robinson, Tigersoft Performance December 2013
#

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use LWP::Simple;
use utf8;
use Text::Unidecode;

use constant BMCWEBSITE => "http://au.bmcairfilters.com";
use constant LOGFILE    => "./ScrapeBMCAirFilters.log";
use constant ALERTFILE  => "./ScrapeBMCAirFilters.alert";
use constant DEBUGFILE  => "./ScrapeBMCAirFilters.debug";

# 
# Open log/aler/debug files
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
my $dsn = "DBI:$driver:;" . "mysql_read_default_file=$my_cnf" . ";mysql_read_default_group=TigersoftPerformance";
my $dbh = DBI->connect($dsn, undef, undef,
	{
	RaiseError => 1, PrintError => 1, mysql_enable_utf8 => 1
	}
) or die $DBI::errstr;

#
# Query to get each active known product from the BMCAirFilters table
#
my $load_filters_sth = $dbh->prepare("
	SELECT * FROM BMCAirFilters 
") or die $dbh->errstr;# WHERE active = 'Y'
$load_filters_sth->execute() or die $dbh->errstr;

#
# This row is used to actually get the data
#
my $getbmcairth = $dbh->prepare("
	SELECT * FROM BMCAirFilters WHERE part_id = ?
") or die $dbh->errstr;

#
# This select is only used to see if Part exists or not
#
my $existsbmcairth = $dbh->prepare("
	SELECT * FROM BMCAirFilters WHERE part = ?
") or die $dbh->errstr;

#
# Insert a new row into BMCAirFilters
#
my $insbmcairth = $dbh->prepare("
	INSERT into BMCAirFilters (part) VALUES (?)
") or die $dbh->errstr;

#
# Update existing row into BMCAirFilters
#
my $updbmcairth = $dbh->prepare("
	UPDATE BMCAirFilters SET part = ?, type = ?, image = ?, diagram = ?,
		dimname1 = ?, dimvalue1 = ?, dimname2 = ?, dimvalue2 = ?, dimname3 = ?, dimvalue3 = ?
		WHERE part_id = ?
") or die $dbh->errstr;

# Create images directory for images and diagrams
unless (-d 'images')
	{
	mkdir "images" or die "cannot";	
	}

#
# This is the start of the main loop. It gets each product from the BMC Airfilters website, and checks for changes. 
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

#
# Now just clean up and finish
#
finish $load_filters_sth;
finish $getbmcairth;
finish $existsbmcairth;
finish $insbmcairth;
finish $updbmcairth;



disconnect $dbh;
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
	my ($hp, $year, $photo, $diagram);
	my $hpyear = "";

	#
	# These are the various "States" of the state machine
	#
	my ($avail, $foundmake, $dimensions, $looking_for_photo) = (0)x4;
	my ($in_photo, $looking_for_diagram, $in_diagram) = (0)x3;

	# 
	# Stuff for managing dimensions
	#
	use constant MAX_DIMENSIONS => 3;
	my (@dimension_names, @dimension_values);
	my $dimension_count = 0;

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

		#
		# OK so now we are at the top of the list of all of the supported models
		#
		if ($line =~ /<th colspan="2" scope="col">Available For<\/th>/)
			{
			$avail = 1;
			next;
			}
		if ($avail)
			{
			if ($line =~ /<span class="red">(.+?): &nbsp;<\/span>/g)
				{
				$make = $1;
				$make =~ s/\xCB/E/g;
				$foundmake = 1;
				&debug ("\tFound $make");
				next;
				}
			}
		}

	&update_bmcairfilters_row ($part_id, $model_code, $type, $photo, $diagram, $dimension_count, \@dimension_names, \@dimension_values);
	}



sub update_bmcairfilters_row
#####################################
#
# This sub creates a new record in the BMCCars table 
#
#####################################
	{
	my ($part_id, $part, $type, $image, $diagram, $dimension_count, $dimnames, $dimvalues) = @_; 
	my $needchange = 0;

	# save image to the image folder
	if ($image) 
		{
		my $url_img = BMCWEBSITE . $image;
		my $img = "images" . $1 if $image =~ /.*(\/.+)$/;
		my $rc1 = getstore($url_img, $img);
		die "getstore of <$url_img> failed with $rc1" if (is_error($rc1)) 
		}

	# save image to the image folder
	if ($diagram) 
		{
		my $url_diag = BMCWEBSITE . $diagram;
		my $diag = "images" . $1 if $diagram =~ /.*(\/.+)$/;
		my $rc2 = getstore($url_diag, $diag);
		die "getstore of <$url_diag> failed with $rc2" if (is_error($rc2)) 
		}	


	$getbmcairth->execute ($part_id) or die $dbh->errstr;
	if (my $bmcair = $getbmcairth->fetchrow_hashref())
		{
		if ($bmcair->{'part'} ne $part)
			{
			die "Part does not match! =$bmcair->{'part'}=$part=";
			$needchange++;
			}

		if (defined $bmcair->{'type'})
			{
			if ($bmcair->{'type'} ne $type)
				{
				&alert ( "type does not match! =$bmcair->{'type'}=$type=");
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
			$updbmcairth->execute($part, $type, $image, $diagram, 
				$dimension_count >=1 ? $dimnames->[1] : "", $dimension_count >=1 ? $dimvalues->[1] : "", 
				$dimension_count >=2 ? $dimnames->[2] : "", $dimension_count >=2 ? $dimvalues->[2] : "", 
				$dimension_count >=3 ? $dimnames->[3] : "", $dimension_count >=3 ? $dimvalues->[3] : "",
				$part_id) or die $dbh->errstr;
			}
		}
	else
		{
		die "Could not read BMC Air Filters Record!";
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
	

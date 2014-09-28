#!/usr/bin/perl
# Perl script for scraping the BMW Air filters website for product information. 
# John Robinson, Tigersoft Performance July 2014
#

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use LWP::Simple;
use utf8;
use Text::Unidecode;
use IO::Handle;
use Encode;

use constant BMCWEBSITE => "http://au.bmcairfilters.com";
use constant LOGFILE    => "./Logs/ScrapeBMCProducts.log";
use constant ALERTFILE  => "./Logs/ScrapeBMCProducts.alert";
use constant DEBUGFILE  => "./Logs/ScrapeBMCProducts.debug";

use constant BMC_IMAGES_DIR => "./BMCImages";

# 
# Open log/alert/debug files
#
open(my $logfh, ">", LOGFILE)     or die "cannot open LOGFILE $!";
open(my $alertfh, ">", ALERTFILE) or die "cannot open ALERTFILE $!";
open(my $debugfh, ">", DEBUGFILE) or die "cannot open DEBUGFILE $!";
$logfh->autoflush;
$alertfh->autoflush;
$debugfh->autoflush;

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
# Query to get each active known product from the BMCProducts table
#
my $load_filters_sth = $dbh->prepare("
	SELECT * FROM BMCProducts WHERE active = 'Y'
") or die $dbh->errstr;
$load_filters_sth->execute() or die $dbh->errstr;

#
# This row is used to actually get the data
#
my $getbmcairth = $dbh->prepare("
	SELECT * FROM BMCProducts WHERE bmc_part_id = ?
") or die $dbh->errstr;

#
# Update existing row into BMCProducts
#
my $updbmcairth = $dbh->prepare("
	UPDATE BMCProducts SET type = ?, description=?, image = ?, diagram = ?,
		dimname1 = ?, dimvalue1 = ?, dimname2 = ?, dimvalue2 = ?, dimname3 = ?, dimvalue3 = ?
		WHERE bmc_part_id = ?
") or die $dbh->errstr;


# Create images directory for images and diagrams
unless (-d BMC_IMAGES_DIR)
	{
	mkdir BMC_IMAGES_DIR or die "cannot create images directory";	
	}

my $quick_scan = 0;
if (defined $ARGV[0])
	{
	if ($ARGV[0] =~ m/quick/i)
		{
		$quick_scan = 1;
		}
	else
		{
		&screen ("Error. Unknown Arguments @ARGV");
		exit 1;
		}
	}
		
#
# This is the start of the main loop. It gets each product from the BMC  website, and checks for changes. 
#
while (my $filter_h = $load_filters_sth->fetchrow_hashref())
	{
	&log ("Product $filter_h->{bmc_part_id}");
	if ($quick_scan && defined $filter_h->{image})
		{
		&debug (" ...skipped");
		next;
		}
	&get_product_info ($filter_h->{bmc_part_id}, $filter_h->{type}, $filter_h->{product_url});
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
# Arg2 = Type
# Arg3 = The URL of the product info page for the model
#
#####################################
	{
	my ($bmc_part_id, $type, $url) = @_;
	my ($content, $myline, $make, $model);
	my ($hp, $year, $photo);
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
	$content = decode_utf8 ($content);
	$content =~ s/,/&#44;/g;
	
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
					&screen ( "Too Many Dimensions for $bmc_part_id");
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

	&update_bmcairproducts_row ($bmc_part_id, $type, $description, $photo, $diagram, $dimension_count, \@dimension_names, \@dimension_values);
	}



sub update_bmcairproducts_row
#####################################
#
# This sub creates a new record in the BMCCars table 
#
#####################################
	{
	my ($part_id, $type, $description, $image, $diagram, $dimension_count, $dimnames, $dimvalues) = @_; 
	my $needchange = 0;


	# save images
	while ($description =~/<img src=\"(.*?\.jpg)\"/sgi)
		{
		my $curr_img = $1;	
		my $url_img_d = BMCWEBSITE . $image;
		my $imgs = BMC_IMAGES_DIR . $1 if $curr_img =~ /.*(\/.+)$/;
		my $rc1 = getstore($url_img_d, $imgs);
		&alert("getstore of <$url_img_d> failed with $rc1") if (is_error($rc1));
		}

	# save image to the image folder
	if ($image) 
		{
		my $url_img = BMCWEBSITE . $image;
		my $img = BMC_IMAGES_DIR . $1 if $image =~ /.*(\/.+)$/;
		my $rc2 = getstore($url_img, $img);
		&alert("getstore of <$url_img> failed with $rc2") if (is_error($rc2));
		}

	# save image to the image folder
	if ($diagram) 
		{
		my $url_diag = BMCWEBSITE . $diagram;
		my $diag = BMC_IMAGES_DIR . $1 if $diagram =~ /.*(\/.+)$/;
		my $rc3 = getstore($url_diag, $diag);
		&alert("getstore of <$url_diag> failed with $rc3") if (is_error($rc3));
		}	


	$getbmcairth->execute ($part_id) or die $dbh->errstr;
	if (my $bmcair = $getbmcairth->fetchrow_hashref())
		{
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
			&log ("Updating record for $part_id");
			$updbmcairth->execute($type, $description, $image, $diagram, 
				$dimension_count >=1 ? $dimnames->[1] : "", $dimension_count >=1 ? $dimvalues->[1] : "", 
				$dimension_count >=2 ? $dimnames->[2] : "", $dimension_count >=2 ? $dimvalues->[2] : "", 
				$dimension_count >=3 ? $dimnames->[3] : "", $dimension_count >=3 ? $dimvalues->[3] : "",
				$part_id) or die $dbh->errstr;
			}
		}
	else
		{
		die "Could not read BMC Products Record!";
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
	

#!/usr/bin/perl -w
#####################################################################################
# Scrape BC Forged Wheels Website script - John Robinson, September 2014
####################################################################################
use strict;
use DBI;
use LWP::Simple;
use feature 'say';
use WWW::Mechanize::Firefox;
use Text::Unidecode;
use utf8;
use English;
use Encode;
use IO::Handle;
use Image::Magick;
use TP qw (debug log alert screen infobox_womostuff);

use constant WEBURL => 'http://www.bcec.com.tw/wheel/new_rim_main/MAIN.html';
use constant PICURL => 'http://www.bcec.com.tw/wheel/';
use constant PICSDIR => "BCWheelsPics/";


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
# Read a record from the BCForgedWheelsWebsite Table based on model.
#
my $get_bcw_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsWebsite WHERE model = ?
") or die $dbh->errstr;

#
# Insert/Replace a new record into BCForgedWheelsWebsite Table
#
my $ins_bcw_sth = $dbh->prepare("
	REPLACE INTO BCForgedWheelsWebsite SET model = ?, type = ?, description = ?, colours = ?, active = 'Y'
") or die $dbh->errstr;

# #
# # Read a record from the BCForgedWheelsSizes Table based on model, diameter and width.
# #
# my $get_bcs_sth = $dbh->prepare("
# # Fields have changed
# #	SELECT * FROM BCForgedWheelsSizes WHERE model = ? AND diameter = ? AND width = ?
# ") or die $dbh->errstr;

# #
# # Insert/Replace a new record into BCForgedWheelsSizes Table
# #
# my $ins_bcs_sth = $dbh->prepare("
	# REPLACE INTO BCForgedWheelsSizes SET model = ?, diameter = ?, width = ?
# ") or die $dbh->errstr;

#
# Read a record from the BCForgedWheelsPCD Table based on model, holes and PCD.
#
my $get_bcpcd_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsPCD WHERE model = ? AND holes = ? AND PCD = ?
") or die $dbh->errstr;

#
# Insert/Replace a new record into BCForgedWheelsPCD Table
#
my $ins_bcpcd_sth = $dbh->prepare("
	REPLACE INTO BCForgedWheelsPCD SET model = ?, holes = ?, PCD = ?
") or die $dbh->errstr;

#
# Read a record from the BCForgedWheelsImages Table based on model, image = ?, title = ?
#
my $get_bcpics_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsImages WHERE model = ? AND image = ? AND title = ?
") or die $dbh->errstr;

#
# Insert/Replace a new record into BCForgedWheelsImages Table
#
my $ins_bcpics_sth = $dbh->prepare("
	REPLACE INTO BCForgedWheelsImages SET model = ?, image = ?, title = ?
") or die $dbh->errstr;

# #
# # Read a record from the BCForgedWheelsRemarks Table based on model, holes and PCD.
# #
# my $get_bcrem_sth = $dbh->prepare("
	# SELECT * FROM BCForgedWheelsRemarks WHERE model = ? AND sortorder = ?
# ") or die $dbh->errstr;

# #
# # Insert/Replace a new record into BCForgedWheelsRemarks Table
# #
# my $ins_bcrem_sth = $dbh->prepare("
	# REPLACE INTO BCForgedWheelsRemarks SET model = ?, sortorder = ?, remark = ?
# ") or die $dbh->errstr;



#######################################################################
# Code starts here
#######################################################################

my $mech = WWW::Mechanize::Firefox->new();
my $wheel_image = Image::Magick->new;
my $main_content;

# This will get the front page of the website
# Try a few times in case of failure
my $retries = 5;
while ($retries && !($mech->get(WEBURL)))
	{
	$retries --;
	}
die "Couldn't get " . WEBURL if (!$retries);
$main_content = decode_utf8 ($mech->content);

# pass over all of the top part of the page till we get to the <div id="MENU"> tag
$main_content =~ /<div id="MENU">/gs or die "No MENU found on main page";

# Now scroll through the list of links to individual wheel models, parsing the URL;
while ($main_content =~ /<a href=\"(.+?)\" onmouse.+?>/gs)
	{
	my $url = $1;
	&debug ($1);

	# Go and get the page for the model at the URL we just found
	$retries = 5;
	while ($retries && !($mech->get($url)))
		{
		$retries --;
		}
	die "Couldn't get $url" if (!$retries);
	my $wheel_content = decode_utf8 ($mech->content);

	# now we have the content of the page for the individual model wheel.
	# Skip down until the <div id="slide"> tag and the start of the following table
	$wheel_content =~ m/<div id="slide">\s*<table(.+?)<\/table>\s*<\/div>/s;
	my $table = $1;
	unless (defined $1)
		{
		&alert ("Could not find a table");
		next;
		}

	# OK so to get here we must have found the table that formats the page. 
	# This table has 2 rows. Row 1 has 5 cells, and Row 2 has 2 cells.
	# At this stage we are only interested in cells 3 and 5 in row 1
	my $row_count = 0;
	my $cell_count;
	my $specs;
	my $pics;
	my $colours;
	# This first loop loops through all of the table rows
	while ($table =~ m/<tr(.+?)<\/tr>/sg)
		{
		my $myrow = $1;
		$row_count ++;
		#&debug (" Found a table row -> $row_count");

		$cell_count = 0;
		# This inner loop loops through the cells within that row.
		while ($myrow =~ m/<td(.+?)<\/td>/sg)
			{
			my $mycell = $1;
			$cell_count ++;
			#&debug ("  Found a table cell");
			if ($row_count == 1 && $cell_count == 3)
				{
				$specs = $mycell;
				}
			elsif ($row_count == 1 && $cell_count == 5)
				{
				$pics = $mycell;
				}
			elsif ($row_count == 2 && $cell_count == 1)
				{
				$colours = $mycell;
				}

			}
		}

	# If we didn't find any specs, 
	if (!defined $specs)
		{
		&alert ("   Could not find any specs");
		next;
		}

	# But if we found specs without pics, then that is a problem....
	if (!defined $pics)
		{
		&alert ("   Could not find any pics");
		next;
		}

	# Check that we have colours
	if (!defined $colours)
		{
		&alert ("   Could not find any colours");
		next;
		}

	&parse_specs_and_pics ($specs, $pics, $colours);
		

		
	}
	
sub parse_specs_and_pics
	{
	my $specs = shift;
	my $pics = shift;
	my $colours = shift;
	
	
	
	$specs =~ m/<p class="style34">&nbsp;<\/p>\s*<p class="style34">(.+?)</sg;
	my $model = $1;
	return -1 if !defined $model;
	$model =~ s/\s+//g;
	
	$specs =~ m/<p class="style25 style30">\s*(.+?)\s*<\/p>/g;
	my $type = $1;
	return -1 if !defined $type;
	
	$specs =~ m/<p class="style27"><strong>\s*(.+?)\s*<\/strong><\/p>/g;
	my $description = $1;
	return if !defined $description;
	
	# First, lets take a look at which colour choices have been specified
	#&debug ("Colours:\n====\n$colours\n====\n");
	my $specified_colours = '';
	while ($colours =~ m/<img.*?src=\"(.+?)\".*?>/sg)
		{
		my $colour_pic = $1;
		if ($colour_pic =~ m/COLOR-EN-(\d+)/)
			{
			my $colour_code = $1;
			if (length $specified_colours)
				{
				$specified_colours .= ',';
				}
			$specified_colours .= $colour_code;
			}
		elsif ($colour_pic =~ m/COLOR-AND-ACCESSORIES_COMBO-new-1pc(.+)/)
			{
			my $caac = $1;
			if (length $specified_colours)
				{
				$specified_colours .= ',';
				}
			if ($caac eq '.jpg')
				{
				$specified_colours .= 'CAAC';
				}
			elsif ($caac eq '-1-en.png')
				{
				$specified_colours .= 'CAAC1';
				}
			elsif ($caac eq '-2-en.png')
				{
				$specified_colours .= 'CAAC2';
				}
				
			
			}		
		else
			{
			&screen ("Unknown colour picture $colour_pic");
			}
		}

	# Lets go and get the record to see if it already exists. 
	my $new_model = 0;
	$get_bcw_sth->execute ($model) or die "Could not read BCW table: $DBI::errstr";
	my $wheel_record = $get_bcw_sth->fetchrow_hashref;
	if (defined $wheel_record->{model})
		{
		&log ("Model: $model. Type: $type. Description: $description");
		}
	else
		{
		&screen ("NEW Model: $model. Type: $type. Description: $description");
		$ins_bcw_sth->execute ($model, $type, $description, $specified_colours) or die "Could not write BCW table: $DBI::errstr";
		}
	
	# clean up all of the unneeded html in the specs before doing any further processing		
	$specs =~ s/<\/*strong.*?>//g;
	$specs =~ s/<\/*em.*?>//g;
	$specs =~ s/<\/*span.*?>//g;
	$specs =~ s/<\/*u>//g;
	$specs =~ s/<br>//g;
	$specs =~ s/&nbsp;/ /g;
	$specs =~ s/  +/ /g;

	$specs =~ m/<ul class="style31">(.+?)<\/ul>/sg;
	my $size = $1;
	return -1 if !defined $size;

	$size =~ m/<li class="style31">H &amp; P.C.D(.+?)<\/ul>/sg;
	my $holeslist = $1;
	return -1 if !defined $holeslist;

	$specs =~ m/<p class="style27">Remark:<\/p>\s*<ul class="style31">(.+?)<\/ul>/sg;
	my $remark = $1;
	return -1 if !defined $remark;
	#&debug ("Specs:\n====\n$specs\n====\n$size\n====\n$holeslist\n====\n$remark\n====\n");
	
	# my $size_records = 0;
	# while ($size =~ m/(\d\d)\"\s*is now avail.*?wheel width\s*(.+?)\s*\n/sg)
		# {
		# my $diameter = $1;
		# my $width = $2;
		
		# my @widths = split /, /, $width;
		# foreach (@widths)
			# {
			# my $width_inches = $_;
			# $width_inches = $1 if $width_inches =~ m/([\d\.]+)J/;
			
			# $get_bcs_sth->execute ($model, $diameter, $width_inches) or die "Could not read BCS table: $DBI::errstr";
			# my $wheel_size_record = $get_bcs_sth->fetchrow_hashref;
			# if (defined $wheel_size_record->{model})
				# {
				# &log ("    Size Record already exists");
				# }
			# else
				# {
				# &screen ("NEW Wheel Size: $model. Diameter: $diameter. Width: $width_inches");
				# $ins_bcs_sth->execute ($model, $diameter, $width_inches) or die "Could not write BCS table: $DBI::errstr";
				# }
			# $size_records ++;
			# }
		# }

	# if size-records == 0, then it means that the size information was not in the format we were expecting.
	# It probably looks like 20", 21".
	# if (!$size_records)
		# {
		# say $size;
		# while ($size =~ m/(\d\d)"/sg)
			# {
			# my $diameter = $1;
			# my $width_inches = 0;
			

			# $get_bcs_sth->execute ($model, $diameter, $width_inches) or die "Could not read BCS table: $DBI::errstr";
			# my $wheel_size_record = $get_bcs_sth->fetchrow_hashref;
			# if (defined $wheel_size_record->{model})
				# {
				# &log ("    Size Record already exists");
				# }
			# else
				# {
				# &screen ("NEW Wheel Size: $model. Diameter: $diameter. Width: $width_inches");
				# $ins_bcs_sth->execute ($model, $diameter, $width_inches) or die "Could not write BCS table: $DBI::errstr";
				# }
			
			# }
		# }	

	

	while ($holeslist =~ m/(\d)H x ([\d\.]+)/sg)
		{
		my $holes = $1;
		my $pcd = $2;
		
		$get_bcpcd_sth->execute ($model, $holes, $pcd) or die "Could not read BCPCD table: $DBI::errstr";
		my $pcd_record = $get_bcpcd_sth->fetchrow_hashref;
		if (defined $pcd_record->{model})
			{
			&log ("    PCD Record already exists");
			}
		else
			{
			&screen ("NEW PCD: $model. Holes: $holes. PCD: $pcd");
			$ins_bcpcd_sth->execute ($model, $holes, $pcd) or die "Could not write BCPCD table: $DBI::errstr";
			}
		
		}
		
		
		
	# my $order = 1;
	# while ($remark =~ m/<li class="style32">(.+?)\s*<\/li>/sg)
		# {
		# my $line = $1;
		# $line =~ s/\n/ /g;

		# $get_bcrem_sth->execute ($model, $order) or die "Could not read BCrem table: $DBI::errstr";
		# my $remark_record = $get_bcrem_sth->fetchrow_hashref;
		# if (defined $remark_record->{model})
			# {
			# &log ("    Remark Record already exists");
			# }
		# else
			# {
			# &screen ("NEW Remark: $line.");
			# $ins_bcrem_sth->execute ($model, $order, $line) or die "Could not write BCrem table: $DBI::errstr";
			# }
		# $order ++;
		# }
	
	$pics =~ m/<img src="(.+?)"/;
	my $titlepic = $1;
	return -1 if !defined $titlepic;

	$titlepic =~ m/^\.\.\/(.+)$/;
	my $picurl = PICURL . $1;

	$titlepic =~ m/^.*\/(.+)$/;
	my $picname = $1;
	$picname =~ s/(^$model).*?\.(.*)$/$1.$2/;

	&get_pic ($model, $picurl, $picname, "Title Pic");

	
	while ($pics =~ m/<a id="thumb1" href="(.+?)".+?> <img src=".+?" title="(.+?)"/g)
		{
		my $pic = $1;
		my $title = $2;
		
		$pic =~ m/^\.\.\/(.+)$/;
		$picurl = PICURL . $1;

		$pic =~ m/^.*\/(.+)$/;
		$picname = $1;
		$picname =~ s/(^$model)/$1_/ if $picname ne $model;
		
		&get_pic ($model, $picurl, $picname, $title);
		}
	}

sub get_pic
	{
	my ($model, $picurl, $picname, $title) = @_;

	&debug ("Getting $picname from $picurl");
	$mech->save_url ($picurl, PICSDIR . $picname);

	$picname =~ m/^(.+)\.(.+)$/;
	my $fname = $1, my $ftype = $2;
	if ($ftype ne "jpg")
		{
		my $newpicname = $1 . ".jpg";
		&debug ("Converting $picname to $newpicname");

		$wheel_image->Read (PICSDIR . $picname);
		my $filename = PICSDIR . $newpicname;
		$wheel_image->Write(filename=>$filename);
		@$wheel_image = ();
		unlink PICSDIR . $picname;
		$picname = $newpicname;
		}

	$get_bcpics_sth->execute ($model, $picname, $title) or die "Could not read BCpics table: $DBI::errstr";
	my $pic_record = $get_bcpics_sth->fetchrow_hashref;
	if (defined $pic_record->{model})
		{
		&log ("    Picture Record already exists");
		}
	else
		{
		&screen ("NEW Pic: $picname.");
		$ins_bcpics_sth->execute ($model, $picname, $title) or die "Could not write BCpics table: $DBI::errstr";
		}
	
	
	}



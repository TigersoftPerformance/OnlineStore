#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use LWP::Simple;
use TP;

use constant SUPERCHIPS_DOMAIN => "http://www.superchips.co.uk";
open(my $newcarfh, ">>", "AASuperchipsNewCars.csv") or die "cannot open New Car file $!";
$newcarfh->autoflush;
$OFS = ",";

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

# Now to select a matching entry from SuperchipsMakes
my $loadmakesth = $dbh->prepare("
	SELECT * FROM SuperchipsMakes
") or die $dbh->errstr;
$loadmakesth->execute() or die $dbh->errstr;

my $selvariantth = $dbh->prepare("
	SELECT * FROM SuperchipsWebsite WHERE variant_id = ?
") or die $dbh->errstr;

my $updvariantth = $dbh->prepare("
	UPDATE SuperchipsWebsite 
	 SET make = ?, model = ?, year = ?, engine_type = ?, capacity = ?, 
	  cylinders = ?, original_bhp = ?, original_nm = ?, gain_bhp = ?, gain_nm = ?, 
	   uk_price = ?, bluefin = ?, epc = ?, tune_type = ?, dyno_graph = ?,
	    road_test = ?, warning = ?, related_media = ?, active = ?, comments = ?, mark = ?
	 WHERE variant_id = ?
") or die $dbh->errstr;

my $unmarkvariantth = $dbh->prepare("
	UPDATE SuperchipsWebsite 
	 SET mark = 'N'
	 WHERE variant_id = ?
") or die $dbh->errstr;

my $markvariantsth = $dbh->prepare("
	UPDATE SuperchipsWebsite 
	 SET mark = 'Y'
	 WHERE variant_id > 0
") or die $dbh->errstr;


# Insert new row into model_code
my $insvariantth = $dbh->prepare("
		INSERT into SuperchipsWebsite VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
") or die $dbh->errstr;

my $makes_hr = $loadmakesth->fetchall_hashref ('make');
my $make = (defined $ARGV[0]) ? $ARGV[0] : "ALL";
if ($make eq "ALL")
	{
	###########################################################################
	# 20140714 JR
	# When all makes will be scraped, we will first of all mark every variant currently listed in the
	# SuperchipsWebsite table. Then, as each variant is is scraped, it can be unmarked, and this
	# will allow easy identification of variants that have been deleted from the Superchips webiste
	###########################################################################
	
	$markvariantsth->execute ();
		
	my $i;
	for $i (sort (keys $makes_hr))
		{
			get_variants_for_make ($makes_hr->{$i}->{make}, $makes_hr->{$i}->{make_num});
		}
	}
else
	{
	if (defined $makes_hr->{$make})
		{
		get_variants_for_make ($makes_hr->{$make}->{make}, $makes_hr->{$make}->{make_num});
		}
	else
		{
		die "Can't find Make: " . $make;
		}
	}


###############################################

sub get_variants_for_make 
	{
	my $make = $_[0];
	my $make_num = $_[1];

	screen ("Searching for all variants from $make");
	for my $fueltype (1..6)
		{
		my $variant_list_url = SUPERCHIPS_DOMAIN . "/search?make=" . $make_num . "&fueltype=". $fueltype;
		my $content = get $variant_list_url;
		die "Couldn't get $variant_list_url" unless defined $content;
		# for my $variant_url ($content =~ /<td width="\d+%">\s+<a href="([a-z0-9&=\/]+)">/g)
		for my $variant_url ($content =~ /<td width="\d+%">\s+<a href="(\/search.+)">/g)
			{
			# say $variant_url;
			extract_info_for_variant ($make, $variant_url);
			}
		}	
	}	

sub extract_info_for_variant
	{
	my $make = $_[0];
	my $variant_url = SUPERCHIPS_DOMAIN . $_[1];
	my $variant_id = 0;
	my $selected_model = "No Model Found";
	my $year = "";
	my $engine_type = "";
	my $capacity = 0;
	my $cylinders = 0;
	my $original_bhp = 0;
	my $original_nm = 0;
	my $gain_bhp = 0;
	my $gain_nm = 0;
	my $uk_price = 0;
	my $bluefin = "N";
	my $epc = "N";
	my $tune_type = "?";
	my $dyno_graph = '';
	my $road_test = '';
	my $warning = '';
	my $related_media = '';
	my $need_update = 0;
	my $variant_hr;
	my $active = "Y";
	my $comments = "No comments";
	my $content = "";
	my $retries = 5;
	while ($retries && !($content = get $variant_url))
		{
		$retries --;
		}
	die "Couldn't get $variant_url" if (!$retries);	
	
	# Find the Selected Model
	$content =~ /<h2 class="no-margin">Selected model<\/h2>/g;
	$content =~ /<h2 class="no-margin" style="font-size: 26px; margin: 0 0 10px 0">/g;
	$selected_model = $1 if $content =~ /(.*?)\s*<\/h2>/g;
	log ("\t$selected_model ");

	$variant_id = $1 if $variant_url =~ /variant=(\d+)/;
	die "Variant ID is $variant_id" if ($variant_id <= 0);
	
	# All of this stuff comes righ after Selected Model, and the code counts on it.
	$year = $1 if $content =~ /\s*(.*)<hr \/>/g;
	$year =~ s/^\s*//;
	$engine_type = $1 if $content =~ /<b>Engine type :<\/b>\s*(.+)<hr \/>/g;
	$capacity = $1 if $content =~ /<b>Engine size :<\/b>\s*(.+) cm3<hr \/>/g;
	$cylinders = $1 if $content =~ /<b>Cylinders :<\/b>\s*(.+)<hr \/>/g;
	$original_bhp = $1 if $content =~ /<b>Original bhp :<\/b>\s*(.+)<hr \/>/g;
	$original_nm = $1 if $content =~ /<b>Original nm :<\/b>\s*(.+)<hr \/>/g;
	$gain_bhp = $1 if $content =~ /<b>BHP increase :<\/b>\s*(.+)<hr \/>/g;
	$gain_nm = $1 if $content =~ /<b>NM gain :<\/b>\s*(.+)<hr \/>/g;
	debug ("$year $engine_type $capacity cm3 $original_bhp bhp");
	
	# See if Bluefin is supported
	$bluefin = "Y" if $bluefin eq "N" && $content =~ /bluefin is available for your/;
	$bluefin = "E" if $content =~ /bluefin enabled/;
	$epc = "Y" if $content =~ /modified using Superchips EPC/;
	$tune_type = "F" if $bluefin eq "Y";
	$tune_type = "B" if $bluefin eq "E";
	
	# Now find the UK Price
	$content =~ /Pricing info SC/g;
	$uk_price = $1 if $content =~ /&pound;(\d+)/g;

	$dyno_graph = $1 if $content =~ /<a href="\/curves\/(.*?)"><img src="images\/icons\/icon_curve.png">/ms;
	$road_test = $1 if $content =~ /<a href="\/roadtest\/(.*?)"><img src="images\/icons\/icon_road.png">/ms;
	$related_media = $1 if $content =~ /<div.*?id='related_media_id'>.*?<embed src='(.*?)'/ms;
	
	# if ($content =~ m/<div id="allwarns">/g)
	# {
		# screen ("Found id = allwarns");	
	# }
	$warning = $1 if $content =~ /<div id="warnings">.*?<div style="text-align.*?">(.+?)<div style="clear: both">/ms;
	$warning =~ s/,/&#44;/g;	
	
	my $model = substr ($selected_model, length ($make));
	# my @modelarray = split (/ /, $selected_model);
	# my $make = $modelarray[0];
	# $modelarray[0] = '';
	# my $model = join (" ", @modelarray);
	$model =~ s/^ +//;

	#say "\t:$make:$model:$year:$engine_type:";
	$selvariantth->execute($variant_id) or die "Failed to execute SQL Variant request";

	if ($variant_hr = $selvariantth->fetchrow_hashref)
		{
		$tune_type = $variant_hr->{tune_type} if ($tune_type eq "?");
		if ($original_bhp =~ m/[^0-9]/)
			{
			screen ("Original BHP is not numeric!");
			}
		if ($original_bhp != $variant_hr->{original_bhp})
			{
			alert ("\t\tOriginal BHP is DIFFERENT. : $original_bhp : $variant_hr->{original_bhp} :");
			$need_update ++;
			}
		if ($original_nm != $variant_hr->{original_nm})
			{
			alert ("\t\tOriginal NM is DIFFERENT. : $original_nm : $variant_hr->{original_nm} :");
			$need_update ++;
			}
		if ($gain_bhp != $variant_hr->{gain_bhp})
			{
			alert ("\t\tGain BHP is DIFFERENT. : $gain_bhp : $variant_hr->{gain_bhp} :");
			$need_update ++;
			}
		if ($gain_nm != $variant_hr->{gain_nm})
			{
			alert ("\t\tGain NM is DIFFERENT. : $gain_nm : $variant_hr->{gain_nm} :");
			$need_update ++;
			}
		if ($uk_price != $variant_hr->{uk_price})
			{
			alert ("\t\tuk_price is DIFFERENT. : $uk_price : $variant_hr->{uk_price} :");
			$need_update ++;
			}
		if ($bluefin ne $variant_hr->{bluefin})
			{
			alert ("\t\tbluefn is DIFFERENT. : $bluefin : $variant_hr->{bluefin} :");
			$need_update ++;
			}
		if ($epc ne $variant_hr->{epc})
			{
			alert ("\t\tepc is DIFFERENT. : $epc : $variant_hr->{epc} :");
			$need_update ++;
			}
		if ($dyno_graph ne $variant_hr->{dyno_graph})
			{
			alert ("\t\tdyno_graph is DIFFERENT. : $dyno_graph : $variant_hr->{dyno_graph} :");
			$need_update ++;
			}
		if ($road_test ne $variant_hr->{road_test})
			{
			alert ("\t\troad_test is DIFFERENT. : $road_test : $variant_hr->{road_test} :");
			$need_update ++;
			}
		if ($warning ne $variant_hr->{warning})
			{
			alert ("\t\twarning is DIFFERENT. : $warning : $variant_hr->{warning} :");
			$need_update ++;
			}
		if ($related_media ne $variant_hr->{related_media})
			{
			alert ("\t\trelated_media is DIFFERENT. : $related_media : $variant_hr->{related_media} :");
			$need_update ++;
			}
		if ($year ne $variant_hr->{year})
			{
			alert ("\t\tyear is DIFFERENT. : $year : $variant_hr->{year} :");
			$need_update ++;
			}
		if ($cylinders ne $variant_hr->{cylinders})
			{
			alert ("\t\tcylinders is DIFFERENT. : $cylinders : $variant_hr->{cylinders} :");
			$need_update ++;
			}
		if ($engine_type ne $variant_hr->{engine_type})
			{
			alert ("\t\tengine_type is DIFFERENT. : $engine_type : $variant_hr->{engine_type} :");
			$need_update ++;
			}
		if ($capacity ne $variant_hr->{capacity})
			{
			alert ("\t\tcapacity is DIFFERENT. : $capacity : $variant_hr->{capacity} :");
			$need_update ++;
			}
		}
	else
		{
		screen ("\t\tThis model needs to be added!");
		alert ("Adding New Record $variant_id, $make, $model, $year, $engine_type, $capacity, $cylinders, $original_bhp, $original_nm, $gain_bhp, $gain_nm, $uk_price, $bluefin, $epc, $tune_type, $dyno_graph, $road_test, $warning, $related_media, $active, $comments");
		my ($start_date, $end_date) = parse_superchips_date ($year);
		say $newcarfh '', $make, $model, '', '', $engine_type, $start_date, $end_date, int ($capacity / 100) / 10, $cylinders, '', $original_bhp, int (($original_bhp * 0.746) + 0.5), $original_nm, $variant_id, 0, 0, 0, 0, 0, 'Y', 'No Comments'; 
		
		$insvariantth->execute($variant_id, $make, $model, $year, $engine_type, $capacity, $cylinders, $original_bhp, $original_nm, $gain_bhp, $gain_nm, $uk_price, $bluefin, $epc, $tune_type, $dyno_graph, $road_test, $warning, $related_media, $active, $comments, 'N');
		}	
	if ($need_update)
		{
		debug ("\t\tThis car needs $need_update updates!");
		alert ("Updating: $variant_id, $make, $model, $year, $engine_type, $capacity, $cylinders, $original_bhp, $original_nm, $gain_bhp, $gain_nm, $uk_price, $bluefin, $epc, $tune_type, $dyno_graph $road_test, $warning, $related_media, $active, $comments");
		$updvariantth->execute($make, $model, $year, $engine_type, $capacity, $cylinders, $original_bhp, $original_nm, $gain_bhp, $gain_nm, $uk_price, $bluefin, $epc, $tune_type, $dyno_graph, $road_test, $warning, $related_media, $active, $comments, 'N', $variant_id);
		}
	else
		{
		$unmarkvariantth->execute ($variant_id);
		}
	}


sub parse_superchips_date
	{
	my $scdate = $_[0];
	
	my $start_day = "1";
	my $start_month = "1";
	my $start_year = "1970";
	my $end_day = "31";
	my $end_month = "12";
	my $end_year = "2050";
	my $gooddate = 0;
	
	# Blank Date
	if ($scdate eq "")
	{
		$gooddate = 1;
	}

	# 2008 onwards
	if ($scdate =~ /^(\d{4}) onwards$/)
	{
		$start_year = $1;
		$gooddate = 1;
	}

	# 9/2008 onwards
	if ($scdate =~ /^(\d{1,2})\/(\d{4}) onwards$/)
	{
		$start_month = $1;
		$start_year = $2;
		$gooddate = 1;
	}

	# up to 1998
	if ($scdate =~ /^up to (\d{4})$/)
	{
		$end_year = $1;
		$gooddate = 1;
	}

	# up to 9/1998
	if ($scdate =~ /^up to (\d{1,2})\/(\d{4})$/)
	{
		$end_month = $1;
		$end_year = $2;
		$gooddate = 1;
	}

	# 1997 - 1998
	if ($scdate =~ /^(\d{4}) - (\d{4})$/)
	{
		$start_year = $1;
		$end_year = $2;
		$gooddate = 1;
	}

	# 1997 - 9/1998
	if ($scdate =~ /^(\d{4}) - (\d{1,2})\/(\d{4})$/)
	{
		$start_year = $1;
		$end_month = $2;
		$end_year = $3;
		$gooddate = 1;
	}

	# 3/1997 - 1998
	if ($scdate =~ /^(\d{1,2})\/(\d{4}) - (\d{4})$/)
	{
		$start_month = $1;
		$start_year = $2;
		$end_year = $3;
		$gooddate = 1;
	}

	# 3/1997 - 9/1998
	if ($scdate =~ /^(\d{1,2})\/(\d{4}) - (\d{1,2})\/(\d{4})$/)
	{
		$start_month = $1;
		$start_year = $2;
		$end_month = $3;
		$end_year = $4;
		$gooddate = 1;
		}

	if ($gooddate == 0)
		{
		print "Unknown Date Format: " . $scdate;
		}

	my $start_date = sprintf ("%4s-%02s-%02s", $start_year, $start_month, $start_day);
	my $end_date = sprintf ("%4s-%02s-%02s", $end_year, $end_month, $end_day);
	return ($start_date, $end_date);
	}

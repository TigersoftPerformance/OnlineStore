#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use LWP::Simple;

use constant SUPERCHIPS_DOMAIN => "http://www.superchips.co.uk";
use constant UPDATE_LOG => "./update_log";

open (my $logfh, ">", UPDATE_LOG) or die "cannot open " . UPDATE_LOG; 
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
	    road_test = ?, warning = ?, related_media = ?, active = ?, comments = ?
	 WHERE variant_id = ?
") or die $dbh->errstr;

# Insert new row into model_code
my $insvariantth = $dbh->prepare("
		INSERT into SuperchipsWebsite VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
") or die $dbh->errstr;

my $makes_hr = $loadmakesth->fetchall_hashref ('make');
my $make = (defined $ARGV[0]) ? $ARGV[0] : "ALL";
if ($make eq "ALL")
{
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
close ($logfh);

###############################################

sub get_variants_for_make 
{
	my $make = $_[0];
	my $make_num = $_[1];

	say "Searching for all variants from " . $make;
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
	print "\t$selected_model ";
	print $logfh "\t$selected_model ";

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
	print "$year $engine_type $capacity cm3 $original_bhp bhp\n";
	print $logfh "$year $engine_type $capacity cm3 $original_bhp bhp\n";
	
	# See if Bluefin is supported
	$bluefin = "Y" if $bluefin eq "N" && $content =~ /bluefin is available for your/;
	$bluefin = "E" if $content =~ /bluefin enabled/;
	$epc = "Y" if $content =~ /modified using Superchips EPC/;
	$tune_type = "F" if $bluefin eq "Y";
	$tune_type = "B" if $bluefin eq "E";
	
	# Now find the UK Price
	$content =~ /Pricing info SC/g;
	$uk_price = $1 if $content =~ /&pound;(\d+)/g;

	$dyno_graph = $1 if $content =~ /<a href="\/curves\/([^"]*?)"><img src="images\/icons\/icon_curve.png">/;
	$road_test = $1 if $content =~ /<a href="\/roadtest\/([^"]*?)"><img src="images\/icons\/icon_road.png">/;
	$related_media = $1 if $content =~ /<a href="([^"]*?)" target="_blank"><img src="images\/icons\/icon_related_n.png">/;
	
	if ($content =~ /<div id="warnings">/g)
	{
		$warning = $1 if $content =~ /<div style="text-align: left; [^"]+">\s*(.+?)\s*<div style="clear: both"><\/div>/ms;	
	}
		
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
		if ($original_bhp != $variant_hr->{original_bhp})
		{
			say $logfh "\t\tOriginal BHP is DIFFERENT. : $original_bhp : $variant_hr->{original_bhp} :";
			$need_update ++;
		}
		if ($original_nm != $variant_hr->{original_nm})
		{
			say $logfh "\t\tOriginal NM is DIFFERENT. : $original_nm : $variant_hr->{original_nm} :";
			$need_update ++;
		}
		if ($gain_bhp != $variant_hr->{gain_bhp})
		{
			say $logfh "\t\tGain BHP is DIFFERENT. : $gain_bhp : $variant_hr->{gain_bhp} :";
			$need_update ++;
		}
		if ($gain_nm != $variant_hr->{gain_nm})
		{
			say $logfh "\t\tGain NM is DIFFERENT. : $gain_nm : $variant_hr->{gain_nm} :";
			$need_update ++;
		}
		if ($uk_price != $variant_hr->{uk_price})
		{
			say $logfh "\t\tuk_price is DIFFERENT. : $uk_price : $variant_hr->{uk_price} :";
			$need_update ++;
		}
		if ($bluefin ne $variant_hr->{bluefin})
		{
			say $logfh "\t\tbluefn is DIFFERENT. : $bluefin : $variant_hr->{bluefin} :";
			$need_update ++;
		}
		if ($epc ne $variant_hr->{epc})
		{
			say $logfh "\t\tepc is DIFFERENT. : $epc : $variant_hr->{epc} :";
			$need_update ++;
		}
		if ($dyno_graph ne $variant_hr->{dyno_graph})
		{
			say $logfh "\t\tdyno_graph is DIFFERENT. : $dyno_graph : $variant_hr->{dyno_graph} :";
			$need_update ++;
		}
		if ($road_test ne $variant_hr->{road_test})
		{
			say $logfh "\t\troad_test is DIFFERENT. : $road_test : $variant_hr->{road_test} :";
			$need_update ++;
		}
		if ($warning ne $variant_hr->{warning})
		{
			say $logfh "\t\twarning is DIFFERENT. : $warning : $variant_hr->{warning} :";
			$need_update ++;
		}
		if ($related_media ne $variant_hr->{related_media})
		{
			say $logfh "\t\trelated_media is DIFFERENT. : $related_media : $variant_hr->{related_media} :";
			$need_update ++;
		}
	}
	else
	{
		say "\t\tThis model needs to be added!";
		print $logfh "Adding New Record $variant_id, $make, $model, $year, $engine_type, $capacity, $cylinders, $original_bhp, $original_nm, $gain_bhp, $gain_nm, $uk_price, $bluefin, $epc, $tune_type, $dyno_graph, $road_test, $warning, $related_media, $active, $comments\n";
		$insvariantth->execute($variant_id, $make, $model, $year, $engine_type, $capacity, $cylinders, $original_bhp, $original_nm, $gain_bhp, $gain_nm, $uk_price, $bluefin, $epc, $tune_type, $dyno_graph, $road_test, $warning, $related_media, $active, $comments);
	}
	if ($need_update)
	{
		say "\t\tThis car needs $need_update updates!";
		print $logfh "Updating: $variant_id, $make, $model, $year, $engine_type, $capacity, $cylinders, $original_bhp, $original_nm, $gain_bhp, $gain_nm, $uk_price, $bluefin, $epc, $tune_type, $dyno_graph $road_test, $warning, $related_media, $active, $comments\n";
		$updvariantth->execute($make, $model, $year, $engine_type, $capacity, $cylinders, $original_bhp, $original_nm, $gain_bhp, $gain_nm, $uk_price, $bluefin, $epc, $tune_type, $dyno_graph, $road_test, $warning, $related_media, $active, $comments, $variant_id);
	}
}




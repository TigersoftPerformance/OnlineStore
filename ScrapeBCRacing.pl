#!/usr/bin/perl -w

use strict;
use DBI;
use LWP::Simple;
use feature 'say';
use TP;

my $content;
#
# From this url we extract all useful links for further extractions
# like PQRS.htm, ZF.htm, KLM.htm, GHIJ.htm etc ..
my $url ='http://www.bcec.com.tw/products_all/ZA.htm';

use constant URL => 'http://www.bcec.com.tw/products_all/';

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
# Load BCRacingCoilovers
#
my $loadbcth = $dbh->prepare("
	SELECT * FROM BCRacingCoilovers where make = ? AND model = ? AND item_no =?
") or die $dbh->errstr;

#
# Update BCRacingCoilovers
#
my $updbcth = $dbh->prepare("
	UPDATE BCRacingCoilovers 
	 SET make =?,model =?,model_code =?,year =?,VS =?,
	 VT =?,VL =?,VN =?,VH =?,VA =?,VM =?,RS =?,RA =?,
	 RH =?,RN =?,MA =?,MH =?,SA =?,ER =?
	 WHERE item_no = ?
") or die $dbh->errstr;

#
# Insert a new row into BCRacingCoilovers
#
my $insbcth = $dbh->prepare("
	INSERT into BCRacingCoilovers (make,model,model_code,year,item_no
	,VS,VT,VL,VN,VH,VA,VM,RS,RA,RH,RN,MA,MH,SA,ER) 
	VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
") or die $dbh->errstr;

#####################################
my $retries = 5;
# Try a few times in case of failure
while ($retries && !($content = get $url ))
	{
	$retries --;
	}
die "Couldn't get $url" if (!$retries);

#
# Collecting valid unique relative urls for further use
# e.g. PQRS.htm, ZF.htm, KLM.htm, GHIJ.htm
my %urls;
while ($content =~ /<td.*?><a href=\"([^"=]+)\"><img.*?><\/a><\/td>/gi)
	{
	$urls{$1}++ unless defined($urls{$1});
	}

#####################################
# Looping through urls and scraping table's data
foreach my $key (sort keys %urls)
	{
	# Make an absolute url like	
	$url = URL . $key;
	debug ("URL = $url");
	$retries = 5;
	# Try a few times in case of failure
	while ($retries && !($content = get $url))
		{
		$retries --;
		}
	die "Couldn't get $url" if (!$retries);

	$content =~ s/&.*?;//gi;													 # Remove all html entities e.g &nbsp;
	$content =~ s/<(\/)?strong.*?>|<\/?div.*?>|<\/?span(.*?)>|<\/?p(.*?)>//sgi;  # Remove some tags
	$content =~ s/(<td.*?>)\s*(.*?)\s*(<\/td>)/$1$2$3/sgi; 						 # Remove empty lines inside <td>
	 
	my $td_counter = 0;
	my @param = ();
	my $after_no = 0;
	my $make;

	# split html contents into array of lines 
	my @lines = split '\n', $content;
	# Looping through the data to get things out
	foreach my $line (@lines)
	 	{
		debug (" line = $line");
	 	# Remove all spaces	
	 	$line =~ s/\s+/ /g;
	 	# Skip everything before NO.	
	 	$after_no = 1 if $line =~/NO\./;
	 	next if $after_no == 0;
	 		
	 	if ($line =~ /<(\/)?tr(.*?)>/i)	
	 		{
	 		# Skip </tr> element	
	 		next unless defined $param[0];	
	 		
	 		# If array contains a row of data of the table
	 		if ($td_counter == 19)
	 			{
	 			&do_db($make,@param);
	 			@param = (); # Initialize array for next loop
	 			}
	 		# If array contains only the name of the make	
	 		elsif ($td_counter == 1)				
	 			{
	 			# Take the last element as make as there could be some
	 			# more unuseful data when scraping
	 			$make = pop @param;
	 			@param = (); # Initialize array for next loop
	 			}
	 		# initialize td counter	
	 		$td_counter = 0; # Initialize <td> counter for next loop
	 		next;
	 		}
	 	# Gather data and store into @param array	
	 	if ($line =~ /<td.*?>\s*(.*?)\s*<\/td>/i)	
	 		{
	 		$td_counter++;
	 		push @param, $1;
	 		}	
	 	}
	} 	


sub do_db
#############################################
# Updates data if needed in BCRacingCoilovers
# Inserts new row if new in BCRacingCoilovers
#############################################
{
	my ($make,$item_no,$year,$model,$model_code,$vs,$vt,$vl,$vn,$vh,$va,$vm,$rs,$ra,$rh,$rn,$ma,$mh,$sa,$er) = @_;	
	my $need_update = 0;
	my ($row,$stored_row,$new_row);
	return 0 if $year =~ /YEAR/i; # skip first bad match

	# Form a common list from new data
	$new_row = join ':', @_;

	$loadbcth->execute($make,$model,$item_no) or die $dbh->errstr;
	#
	# If row exists in BCRacingCoilovers table
	if ($row = $loadbcth->fetchrow_hashref)
		{
		# Form a common list from stored data
		$stored_row = join ':',$row->{make},$row->{item_no},$row->{year},$row->{model},$row->{model_code},$row->{VS},$row->{VT},$row->{VL},$row->{VN},$row->{VH},$row->{VA},$row->{VM},$row->{RS},$row->{RA},$row->{RH},$row->{RN},$row->{MA},$row->{MH},$row->{SA},$row->{ER};	

		#
		# This condition shows us if any of the parameters 
		# were modified after last run of this script then consider updating data
		if ($stored_row ne $new_row)
			{
			$need_update++;	
			&screen("Updated $make : $model : $model_code:$year:$item_no ==> $row->{make} : $row->{model} : $row->{model_code}:$row->{year}:$row->{item_no}");	
			}
		# If nothing is modified then just 
		# log data from BCRacingCoilovers table	
		else
			{
			&screen(" ==>  $make : $model : $model_code : $year : $item_no");
			}		
		}
	# Insert new row and log data	
	else
		{
		$insbcth->execute($make,$model,$model_code,$year,$item_no,$vs,$vt,$vl,$vn,$vh,$va,$vm,$rs,$ra,$rh,$rn,$ma,$mh,$sa,$er) or die $dbh->errstr;
		&screen("\tNew BC Racing Coilovers => $make : $model : $model_code : $year : $item_no");
		}	
	# Update data in BCRacingCoilovers table if needed	
	if ($need_update>0)
		{
		$updbcth->execute($make,$model,$model_code,$year,$vs,$vt,$vl,$vn,$vh,$va,$vm,$rs,$ra,$rh,$rn,$ma,$mh,$sa,$er,$item_no) or die $dbh->errstr;
		}	
}


#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use TP;


$OFS = ',';

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
# Select all rows from BCFWWebsite
#
my $get_bcfw_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsWebsite WHERE active = 'Y'
") or die $dbh->errstr;
$get_bcfw_sth->execute;

#
# Select all rows from BCFWPrices
#
my $get_all_bcfw_prices_records_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsPrices ORDER BY series, diameter, width
") or die $dbh->errstr;

#
# Select all rows from BCFWColours based on component
#
my $get_all_bcfw_colours_records_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsColours WHERE component = ?
") or die $dbh->errstr;

#
# Select all rows from BCFWColours based on colour and component
#
my $get_one_bcfw_colours_record_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsColours WHERE colour = ? AND component = ?
") or die $dbh->errstr;

##
# Select one row from BCFWPrices 
#
my $get_one_bcfw_prices_record_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsPrices WHERE series = ? AND diameter = ? AND width = ?
") or die $dbh->errstr;

#
# Select all rows from BCFWPrices based on series
#
my $get_bcfwprices_by_series_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsPrices WHERE series = ?
") or die $dbh->errstr;

#
# replace a row into BCFWPrices
#
my $repl_bcfwprices_sth = $dbh->prepare("
	INSERT INTO BCForgedWheelsPrices SET series = ?, diameter = ?, width = ? ON DUPLICATE KEY UPDATE sortorder = ?
") or die $dbh->errstr;

#
# Select base price from BCFWPrices
#
my $get_base_price_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsPrices WHERE series = ? ORDER BY tp_price ASC LIMIT 1
") or die $dbh->errstr;

#
# Select all rows from BCFWPCD
#
my $get_all_bcfw_pcd_records_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsPCD ORDER BY model, holes, PCD
") or die $dbh->errstr;

#
# Select all rows from BCFWPCD based on model
#
my $get_bcfwpcd_by_model_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsPCD WHERE model = ?
") or die $dbh->errstr;

#
# Select one row from BCFWPCD based 
#
my $get_one_bcfwpcd_record_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsPCD WHERE model = ? AND holes = ? and PCD = ?
") or die $dbh->errstr;

#
# replace a row into BCFWPCD
#
my $repl_bcfwpcd_sth = $dbh->prepare("
	INSERT INTO BCForgedWheelsPCD SET model = ?, holes = ?, PCD = ? ON DUPLICATE KEY UPDATE sortorder = ?
") or die $dbh->errstr;

#
# Select a rows from BCFWWebsite based on Model
#
my $get_bcfw_by_model_sth = $dbh->prepare("
	SELECT * FROM BCForgedWheelsWebsite WHERE model = ? AND active = 'Y'
") or die $dbh->errstr;

###########################################################
# Start of main program
###########################################################

if (defined $ARGV[0])
	{
	&update_sortorders ();
	&create_detailed_attrib_file ($ARGV[0]);
	}
else
	{
	&create_basic_attrib_file ();
	}

exit 0;

###########################################################
# End of main program
###########################################################


sub update_sortorders
	{
	
	my $sortorder = 10;
	
	$get_all_bcfw_pcd_records_sth->execute or die $dbh->errstr;
	while (my $bpcd = $get_all_bcfw_pcd_records_sth-> fetchrow_hashref)
		{
		$repl_bcfwpcd_sth->execute ($bpcd->{model}, $bpcd->{holes}, $bpcd->{PCD}, $sortorder)  or die $dbh->errstr;
		$sortorder += 10;
		&debug ("pcd sort order = $sortorder");
		}
	
	$sortorder = 10;
	
	$get_all_bcfw_prices_records_sth->execute or die $dbh->errstr;
	while (my $bprices = $get_all_bcfw_prices_records_sth-> fetchrow_hashref)
		{
		$repl_bcfwprices_sth->execute ($bprices->{series}, $bprices->{diameter}, $bprices->{width}, $sortorder)  or die $dbh->errstr;
		$sortorder += 10;
		&debug ("price sort order = $sortorder");
		}
	
	}



sub create_detailed_attrib_file
	{
	open(my $infile, "<", $_[0])     or die "cannot open input file $!";

	use constant DCSV => "./Attrib-Detailed-EPTigersoft.csv";
	open (my $attrib, ">", DCSV) or die "Cannot open " . DCSV;

	while (my $line = <$infile>)
		{
		my @columns = split (/,/, $line);
		
		if ($columns[2] =~ m/BCFW(.+)/)
			{
			my $model = $1;
			$model =~ s/\"+//g;
			my $option_name = $columns[4];
			my $option_value = $columns[7];
			$option_value =~ s/\"//g;
			
			my $series; my $bcp; my $baseprice;
			
			if ($option_name =~ m/Wheel Size/)
				{
				if ($option_value =~ m/(\d+) x ([\d\.]+)J/)
					{
					my $diameter = $1, my $width = $2;
					&debug ("Wheel Size. $model, $diameter, $width");
					
					$get_bcfw_by_model_sth->execute ($model)  or die $dbh->errstr;
					my $bc_data = $get_bcfw_by_model_sth->fetchrow_hashref;
					if (defined $bc_data)
						{
						$series = $1 if $bc_data->{type} =~ m/(\S+ Series)$/;
						unless (defined $series)
							{
							&alert ("Could not determine series from $bc_data->{type}");
							}
						
						$get_base_price_sth->execute ($series)  or die $dbh->errstr;
						$bcp = $get_base_price_sth->fetchrow_hashref;
						unless (defined $bcp->{tp_price})
							{
							&alert ("WARNING: Could not find a base price for $series");
							}
						undef $baseprice; $baseprice = $bcp->{tp_price};
					
						$get_one_bcfw_prices_record_sth->execute ($series, $diameter, $width)  or die $dbh->errstr;
						$bcp = $get_one_bcfw_prices_record_sth->fetchrow_hashref;
						unless (defined $bcp->{tp_price})
							{
							&alert ("WARNING: Could not find a price for $series");
							}

						if (defined $bcp->{tp_price} && defined $baseprice)
							{
							my $pricediff = ($bcp->{tp_price} - $baseprice) * 2;
							&debug ("Prices: $bcp->{tp_price}, $baseprice, $pricediff");
							$columns[8] = $pricediff - ($pricediff / 11);
							$columns[9] = '+';
							$columns[16] = 0;
							}
						}

					if (defined $bcp->{sortorder})
						{
						$columns[10] = $bcp->{sortorder};
						}
					}

				}
			elsif ($option_name =~ m/Wheel Offset/)
				{
				if ($option_value =~ m/ET(\d+)/)
					{
					$columns[10] = $1;
					}
				}
			elsif ($option_name =~ m/PCD/)
				{
				if ($option_value =~ m/(\d+) x ([\d\.]+)/)
					{
					my $holes = $1, my $PCD = $2;
					
					$get_one_bcfwpcd_record_sth->execute ($model, $holes, $PCD)  or die $dbh->errstr;
					my $bcp = $get_one_bcfwpcd_record_sth->fetchrow_hashref;
					if (!defined $bcp->{sortorder})
						{
						&alert ("WARNING: Could not find a PCD record for $model");
						}
					else
						{
						$columns[10] = $bcp->{sortorder};
						}
					
					}
				}
			elsif ($option_name =~ m/Colour/)
				{
				$columns[9] = '+';
				$columns[16] = 0;
				&debug ("Option name = $option_name");
				if ($option_name =~ m/Wheel Col/)
					{
					($columns[8], $columns[10]) = &get_color_price ($option_value, "Wheel");
					}
				if ($option_name =~ m/Rim/)
					{
					($columns[8], $columns[10]) = &get_color_price ($option_value, "Rim");
					}
				if ($option_name =~ m/Centre/)
					{
					($columns[8], $columns[10]) = &get_color_price ($option_value, "Centre");
					}
				if ($option_name =~ m/Wheel Str/)
					{
					($columns[8], $columns[10]) = &get_color_price ($option_value, "Stripe");
					}
				if ($option_name =~ m/Diamond/)
					{
					($columns[8], $columns[10]) = &get_color_price ($option_value, "Diamond");
					}
				}
			&debug ("Option name 2= $option_name");

			}
		
		print $attrib @columns;
		}

	close $infile;
	close $attrib;
	}




sub get_color_price
	{
	my ($option_value, $component) = @_;
	debug ("Getting Color price for $option_value, $component");

	
	$get_one_bcfw_colours_record_sth->execute ($option_value, $component)  or die $dbh->errstr;
	my $bccolour = $get_one_bcfw_colours_record_sth->fetchrow_hashref;
	if (!defined $bccolour)
		{
		&alert ("Could not find color record for $option_value, $component");
		return 0;
		}
	debug ("Color price for $option_value, $component is $bccolour->{tp_price}");
	my $temp = $bccolour->{tp_price} * 4;
	return ($temp - ($temp / 11), $bccolour->{sortorder});
	}


sub create_basic_attrib_file
	{
	use constant BCSV => "./Attrib-Basic-EPTigersoft.csv";
	open (my $attrib, ">", BCSV) or die "Cannot open " . BCSV;
			
	print $attrib "v_products_model,v_products_options_type,v_products_options_name_1,v_products_options_values_name_1\n";
	my $diamondcut;
	my $bc_data = {};
	while ($bc_data = $get_bcfw_sth->fetchrow_hashref)
		{
		&debug ("Wheel: $bc_data->{model}");
		my $model = "BCFW" . $bc_data->{model};

		# Generate a size list for this model
		# find the series name from the type
		my $series = $1 if $bc_data->{type} =~ m/(\S+ Series)$/;
		unless (defined $series)
			{
			&alert ("Could not determine series from $bc_data->{type}");
			next;
			}
			
		$get_bcfwprices_by_series_sth->execute ($series)  or die $dbh->errstr;
		my $bcp = {};
		my $sizelist = '';
		while ($bcp = $get_bcfwprices_by_series_sth->fetchrow_hashref)
			{
			my $size = $bcp->{diameter} . " x " . sprintf ("%2.1f", $bcp->{width}) . "J";
			$sizelist .= "," if length $sizelist;
			$sizelist .= $size;
			$diamondcut = $bcp->{diamondcut};
			}
		
		unless (length $sizelist)
			{
			&alert ("Could not find prices for model $bc_data->{model}");
			next;
			}
			
			
		# Create options for Front Wheel Size
		&output_basic_attribute ($attrib, $model, 0, "Front Wheel Size", $sizelist);
		
		# Create options for Rear Wheel Size
		&output_basic_attribute ($attrib, $model, 0, "Rear Wheel Size", $sizelist);

		# Create options for Front Wheel Offset
		my $offsetlist = "ET10,ET15,ET20,ET25,ET30,ET35,ET40,ET45,ET50";
		&output_basic_attribute ($attrib, $model, 0, "Front Wheel Offset", $offsetlist);
		
		# Create options for Rear Wheel Offset
		&output_basic_attribute ($attrib, $model, 0, "Rear Wheel Offset", $offsetlist);
		
		# Create options for PCD
		$get_bcfwpcd_by_model_sth->execute ($bc_data->{model})  or die $dbh->errstr;
		my $bcpcd = {};
		my $pcdlist = 'Not Sure';
		while ($bcpcd = $get_bcfwpcd_by_model_sth->fetchrow_hashref)
			{
			my $pcd = $bcpcd->{holes} . " x " . $bcpcd->{PCD};
			$pcdlist .= "," . $pcd;
			}
		&output_basic_attribute ($attrib, $model, 0, "PCD", $pcdlist);

		# Create Options for colours
		# First do the 1-piece designs
		if ($series =~ m/RS|RT/)
			{
			&create_colour_attributes ($attrib, $model, "Wheel", "Wheel Colour");
			}
		else
			{
			&create_colour_attributes ($attrib, $model, "Rim", "Rim Colour");
			&create_colour_attributes ($attrib, $model, "Centre", "Centre Disk Colour");
			&create_colour_attributes ($attrib, $model, "Stripe", "Wheel Stripe Colour");
			if ($diamondcut == 1)
				{
				&create_colour_attributes ($attrib, $model, "Diamond", "Diamond Cut Colour");
				
				}
			}
		}
	}
	
	
sub create_colour_attributes
	{
	my ($attrib, $model, $component, $name) = @_;
	
	$get_all_bcfw_colours_records_sth->execute ($component)  or die $dbh->errstr;
	my $bccolours = {};
	my $colourslist = '';
	while ($bccolours = $get_all_bcfw_colours_records_sth->fetchrow_hashref)
		{
		if (length $colourslist)
			{
			$colourslist .= ",";
			}
		$colourslist .= $bccolours->{colour};
		}
	&output_basic_attribute ($attrib, $model, 0, $name, $colourslist);
	
	}
	
sub output_basic_attribute
	{
	my ($attrib, $model, $type, $name, $values) = @_;
	
	print $attrib $model, $type, $name, "\"". "$values" . "\"\n";
	}
	
	
	
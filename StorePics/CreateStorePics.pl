#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use English;
use feature 'say';
use feature 'switch';
use POSIX;

my $main_font = " -family 'Linux Libertine' -style Normal";
my $driver = "mysql";   # Database driver type
my $database = "TP";  # Database name
my $user = "root";          # Database user name
my $password = "doover111";      # Database user password

use constant STOREPICSDIR => "StorePics/";

#
# Connect to database
#
my $dbh = DBI->connect(
"DBI:$driver:$database", $user, $password,
	{
	RaiseError => 1, PrintError => 1,
	}
) or die $DBI::errstr;

my $get_model_code_sth = $dbh->prepare("
	SELECT * FROM ModelCodes WHERE make = ? AND model = ? AND model_code = ?
") or die $dbh->errstr;

# Usage:
# CreateStorePics.pl [make [model]]
# CreateStorePics.pl [idCars1 [idCars2]]
#
my $cars_query = "SELECT * FROM Cars WHERE active = 'Y'";
if (defined $ARGV[0])
	{
	if ($ARGV[0] =~ /^\d+$/)
		{
		if (defined $ARGV[1])
			{
			$cars_query = "$cars_query AND idCars BETWEEN $ARGV[0] AND $ARGV[1]";
			}
		else
			{
			$cars_query = "$cars_query AND idCars ='$ARGV[0]'";
			}
		}
	else
		{
		$cars_query = "$cars_query AND make ='$ARGV[0]'";
		if (defined $ARGV[1])
			{
			$cars_query = "$cars_query AND model ='$ARGV[1]'";
			}
		}
	}
#
# prepare the sql statements
#
my $sth = $dbh->prepare($cars_query) or die $dbh->errstr;
$sth->execute() or die $dbh->errstr;

#
# This is where the grunt work happens
# This main loop reads each row from the Cars table
#
my $car = {};
my $counter = 0;
my $background_pic;
while ($car = $sth->fetchrow_hashref)
	{
	$counter++;

	my $make = $car->{make};
	$make =~ s/ +//g;
	$background_pic = "Backgrounds/" . $make . "Background.jpg";
	unless ( -e $background_pic)
		{
		say "$background_pic for :$make: does not exist";
		next;
		}
	
	&create_make_pic ();
	&create_model_pic ();
	&create_model_code_pic ();
	&create_variant_pic ();
	}

print "\n\tNo rows selected with this \"@ARGV\"!\n\n" if $counter == 0;	

#
# Disconnect from database
#
$sth->finish;
$get_model_code_sth->finish;
$dbh->disconnect;

exit 0;

sub create_make_pic
	{
	say "Make: $car->{make}";
	my $make_pic_name = sprintf ("Cat1%s.jpg", $car->{make});
	$make_pic_name =~ s/[ \/]+//g;
	$make_pic_name = STOREPICSDIR . $make_pic_name;
	if ( -e $make_pic_name)
		{
		return;
		}
		
	my $command = "convert $background_pic";
	$command .= &create_main_text ($car->{make});
	$command .= " " . $make_pic_name;	
	system ($command);
	}

sub create_model_pic
	{
	say "  Model: $car->{model}";
	my $model_pic_name = sprintf ("Cat2%s%s.jpg", $car->{make}, $car->{model});
	$model_pic_name =~ s/[ \/]+//g;
	$model_pic_name = STOREPICSDIR . $model_pic_name;
	if ( -e $model_pic_name)
		{
		return;
		}
		
	my $command = "convert $background_pic";
	$command .= &create_heading ($car->{make});
	$command .= &create_main_text ($car->{model});
	$command .= " " . $model_pic_name;	
	system ($command);
	}

sub create_model_code_pic
	{
	if (!length($car->{model_code}))
		{
		return;
		}
	say "    Model_Code: $car->{model_code}";
	my $model_code_pic_name = sprintf ("Cat3%s%s%s.jpg", $car->{make}, $car->{model}, $car->{model_code});
	$model_code_pic_name =~ s/[ \/]+//g;
	$model_code_pic_name = STOREPICSDIR . $model_code_pic_name;
	if ( -e $model_code_pic_name)
		{
		return;
		}
		
	my $command = "convert $background_pic";
	$command .= &create_heading ($car->{make} . " " . $car->{model});
	$command .= &create_main_text ($car->{model_code});
	
	$get_model_code_sth->execute($car->{make}, $car->{model}, $car->{model_code}) or return;
	# need some error checking here....
	my $model_code = $get_model_code_sth->fetchrow_hashref;
	my $start_year = substr ($model_code->{start_date}, 0, 4);
	my $end_year = substr ($model_code->{end_date}, 0, 4);
	$command .= &create_date_range (2, $start_year, $end_year);

	$command .= " " . $model_code_pic_name;

	system ($command);
	}

sub create_variant_pic
	{
	my $variant_pic_name = sprintf ("StorePics/TPC%06d.jpg", $car->{idCars});
	if ( -e $variant_pic_name)
		{
		return;
		}
		
	my $command = "convert $background_pic";

	# Create a heading for the image
	my $heading_text = "$car->{make} $car->{model}";
	if ($car->{model_code})
		{
		$heading_text = $heading_text . " ($car->{model_code})";
		}
	$command .= &create_heading ($heading_text);

	my $linenum = 0;
	$command .= &create_specs ($linenum++, "$car->{original_kw}kW") if $car->{original_kw};
	$command .= &create_specs ($linenum++, "$car->{original_nm}Nm") if $car->{original_nm};
	$command .= &create_specs ($linenum++, sprintf ("%1.1f litre", $car->{capacity})) if $car->{capacity};
	$command .= &create_specs ($linenum++, "$car->{cylinders} cyls") if $car->{cylinders};

	my $start_year = substr ($car->{start_date}, 0, 4);
	my $end_year = substr ($car->{end_date}, 0, 4);
	$command .= &create_date_range ($linenum, $start_year, $end_year);
		
	$command .= &create_fuel_type ();

	my $text;
	if ($car->{variant})
		{
		$text = $car->{variant};
		}
	else
		{
		$text = "$car->{original_kw} kW";
		}
	$command .= &create_main_text ($text);

	$command .= " " . $variant_pic_name;	
	system ($command);
	}
	
sub create_heading
	{
	my $headingx = 15;
	my $headingy = 35;
	my $pointsize = 20;
	my $colour = "grey15";
	
	my $heading_text = $_[0];
	my $length = length ($heading_text);
	my $width = $length * $pointsize / 2;
	$headingx = ((300 - $width) / 2);	

	my $draw_text = "\"text $headingx,$headingy \'$heading_text\'\"";
	return " $main_font -weight Normal -pointsize $pointsize -fill $colour -stroke $colour -draw $draw_text";
	}

sub create_specs
	{
	my ($linenum,$text) = @_;
	my $colour = "MidnightBlue";
	
	my $line1 = 35;
	my $lineinc = 30;
	my $specx = 320;
	my $specy = $line1 + ($lineinc * $linenum);
	my $pointsize = 22;

	my $draw_text = "\"text $specx,$specy \'$text\'\"";
	return " $main_font -weight Normal -pointsize $pointsize -fill $colour -stroke $colour -draw $draw_text";
	}
	
sub create_fuel_type
	{
	my $pointsize = 32;
	my $textx = 0;
	my $texty = 295;
	my $colour = "Grey15";
	
	my $fueltype = $car->{fuel_type};
	my $length = length ($fueltype);

	for ($fueltype)
		{
		when (/^Turbo-Diesel/) { $colour = "green"; }
		when (/^Non-Turbo Petrol/) { $colour = "MidnightBlue"; }
		when (/^Turbocharged Petrol/) { $colour = "DodgerBlue2"; }
		when (/^Twincharger/) { $colour = "gold"; }
		when (/^Supercharged/) { $colour = "OrangeRed4"; }
		
		default { say "unknown Fuel Type $fueltype"; }
		}
	
	my $width = $length * $pointsize / 2;
	 $textx = (420 - $width) / 2;
	
	my $draw_text = "\"text $textx,$texty \'$fueltype\'\"";
	return " $main_font -weight Normal -pointsize $pointsize -fill $colour -stroke $colour -draw $draw_text";
	}

sub create_main_text
	{
	my $text = $_[0];
	my $pointsize = 35;
	my $textx = 10;
	my $texty = 150;
	my $colour = "blue";
	
	my $length = length ($text);

	# if text has length > 10 , split into two lines
	if ($length > 10)
		{
		my @words = split " ", $text;	
		my $arr_len = ceil(scalar @words/2);
		my @text1 = splice(@words,0,$arr_len);
		my @text2 = @words;

		my $texty1 = 130;
		my $texty2 = 165;

		my $length1 = length (join " ", @text1);
		my $length2 = length (join " ", @text2);

		my $width1 = $length1 * $pointsize / 2;
	 	my $textx1 = int ((300 - $width1) / 2);

	 	my $width2 = $length2 * $pointsize / 2;
	 	my $textx2 = int ((300 - $width2) / 2);   
	 	   
		my $draw_text1 = "\"text $textx1,$texty1 \'@text1\'\"";
		my $draw_text2 = "\"text $textx2,$texty2 \'@text2\'\"";
		my $output = " $main_font -weight Bold -pointsize $pointsize -fill $colour -stroke $colour -draw $draw_text1";
		$output = "$output $main_font -weight Bold -pointsize $pointsize -fill $colour -stroke $colour -draw $draw_text2";
		return $output;
		}

	my $width = $length * $pointsize / 2;
	$textx = int ((300 - $width) / 2.1);
	
	my $draw_text = "\"text $textx,$texty \'$text\'\"";
	return " $main_font -weight Bold -pointsize $pointsize -fill $colour -stroke $colour -draw $draw_text";
	}

sub create_date_range
	{
	my ($linenum, $start_year, $end_year) = @_;
	my $command = "";
	
	if (!($start_year == 1970 && $end_year == 2050))
		{
		if ($start_year == 1970)
			{
			$start_year = "Up to";
			}
		if ($end_year == 2050)
			{
			$end_year = "onward";
			}
		if ($end_year eq "0000" || $end_year eq $start_year)
			{
			$end_year = "";
			}

		$linenum++;
		$command .= &create_specs ($linenum++, $start_year);
		if ($start_year =~ /^\d+$/ && $end_year =~ /^\d+$/)
			{
			$command .= &create_specs ($linenum++, "  to");
			}
		if ($start_year ne $end_year)
			{
			$command .= &create_specs ($linenum++, $end_year);
			}
		}
	return $command;
	}

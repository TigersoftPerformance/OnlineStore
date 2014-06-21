#!/usr/bin/perl -w

use strict;
use DBI;

my ($marca,$make,$modid,$model);

use constant LOG => "./updat_mc_modid_log";

open (my $logfh, ">", LOG) or die "cannot open " . LOG;

my $driver = "mysql";   # Database driver type
my $database = "TP";    # Database name
my $user = "root";      # Database user name
my $password = "";      # Database user password

#
# Connect to database
#
my $dbh = DBI->connect(
"DBI:$driver:$database", $user, $password,
	{
	RaiseError => 1, PrintError => 1, mysql_enable_utf8 => 1
	}
) or die $DBI::errstr;

#
# load BMCmod
#
my $loadmodth = $dbh->prepare("
	SELECT * FROM BMCmods where make = ? AND model =?
") or die $dbh->errstr;

#
# load ModelCodes
#
my $loadMCth = $dbh->prepare("
	SELECT * FROM ModelCodes
") or die $dbh->errstr;
$loadMCth->execute() or die $dbh->errstr;

#
# update ModelCodes
#
my $updmcth = $dbh->prepare("
	UPDATE ModelCodes 
	SET modID = ?
	WHERE make = ? AND BMCModel = ?
") or die $dbh->errstr;


#
# looping through ModelCodes table
#
while ( my $mcth = $loadMCth->fetchrow_hashref)
	{
	printf "%-20s", "$mcth->{make} $mcth->{BMCModel}";	
	print $logfh "$mcth->{make} $mcth->{BMCModel}";
	my @models = split ':', $mcth->{BMCModel};	
	my @modid;
	my ($md,$mds);
	# BMCModel contains 1 value 
	if (scalar @models == 1)
		{
		$loadmodth->execute($mcth->{make},$mcth->{BMCModel}) or die $dbh->errstr;	
		if($md = $loadmodth->fetchrow_hashref)
			{
			$updmcth->execute($md->{modid},$mcth->{make},$mcth->{BMCModel}) or die $dbh->errstr;
			printf "%10s", "\t=> $md->{modid}\n";	
	    	printf $logfh "%10s", "\t=> $md->{modid}\n";
	    	}
	    else
	    	{
	    	print "\tNo modid for this Model\n";
	    	print $logfh "\t\tNo modid for this Model\n";	
	    	}	
		}
	# BMCModel contain multiple value 	
	else
		{		
		foreach(@models)	
			{
			$loadmodth->execute($mcth->{make}, $_ ) or die $dbh->errstr;	
			$md = $loadmodth->fetchrow_hashref;	
			push @modid, $md->{modid}; 
			}
		$mds = join(":", @modid);
		
		$updmcth->execute($mds,$mcth->{make},$mcth->{BMCModel}) or die $dbh->errstr;	
		printf "%10s", "\t=> $mds\n";	
	    printf $logfh "%10s", "\t=> $mds\n";
		}	

	}


print "\n\t##############################";
print "\n\t####        Done !        ####";
print "\n\t##############################\n\n";

close $logfh;


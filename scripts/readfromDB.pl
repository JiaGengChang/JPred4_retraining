#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use File::Basename;

use lib '/cluster/gjb_lab/2472402/jpred_train/lib';

use Jpred::jnetDB;
use Jpred::Utils 0.4;
use SNNS::Pattern;
use SNNS::Network;




main();











sub main {
    # Retrieve DSSP data from Jnet DB
    my $dbh      = connect_DB('jnet-user');
    my $dsspData = get_DSSP_jiageng($dbh);
    die "ERROR - no DSSP data found" unless ( keys %$dsspData );
    $dbh->disconnect;
    
    
    # read seqIDs from ref.txt, write {seqID},{domainID} into check.txt
    my @seqIDs;
    open(FH, '<', '/cluster/gjb_lab/2472402/ref.txt');
    while (my $seqID=<FH>){
        chomp $seqID;
        die unless $seqID;
        push @seqIDs, $seqID;
    }
    close(FH);
    die unless (@seqIDs);
    
    foreach my $seqID (@seqIDs){
        die unless $dsspData->{$seqID};
        print "$dsspData->{$seqID}{'dom'},$seqID\n";
    }
}

sub get_DSSP_jiageng {
  my $dbh    = shift;

  my %data;
  my $sth;
  $sth = $dbh->prepare("SELECT seq_id,domain,dssp FROM query") or die "ERROR! unable to SELECT: ", $dbh->errstr;
  $sth->execute() or die "ERROR! unable to execute SELECT: ", $dbh->errstr;

  while ( my $row = $sth->fetchrow_arrayref ) {
    ## $row->[0] == seqID
    ## $row->[1] == domainID
    ## $row->[2] == dssp
    
    $data{ $row->[0] }{dom}  = $row->[1];
    $data{ $row->[0] }{dssp} = $row->[2];    # NB the DSSP data is in full format. Don't forget to reduce to 3-state if required.
  }
  $sth->finish;
  return ( \%data );
}


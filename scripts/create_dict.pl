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


my $DATA='/cluster/gjb_lab/2472402/snns_cross_val_21_Aug/cross-val1/data';

## get files to train against
my @files = glob "$DATA/*.pssm";
die "ERROR - no files found" if ( !@files );

## Retrieve DSSP data from Jnet DB
my $dbh      = connect_DB('jnet-user');
my $dsspData = get_DSSP($dbh);
die "ERROR - no DSSP data found" unless ( keys %$dsspData );
$dbh->disconnect;


foreach my $seqID (keys % { $dsspData } ){
    print "$dsspData->{$seqID}{'dom'},";
    print "$seqID\n";
}

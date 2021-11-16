#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

## script to prepare trained network data for scoring
## This script has now grown huge to deal with multiple
## networks saved from a single training run as essentially,
## need to retrain the 2nd layer nets for each 1st layer net

use warnings;
use strict;

use Getopt::Long;

use lib '/homes/www-jpred/jnet_train/lib';

use Jpred::jnetDB;
use Jpred::Utils;
use SNNS::Pattern;
use SNNS::Network;

my $SGE = 'source /grid.master/default/common/settings.sh && qsub -q 64bit.q -cwd ';
my $iters;

GetOptions( 'iters=i' => \$iters ) or die;

die "Please give number of iterations to use. Died " if ( !$iters );
mkdir($iters) or die "ERROR - unable to mkdir '$iters'. Died";

my @nets       = qw(hmm freq alignfreq alignblosum pssma pssmb);
my %profLookup = qw(hmm hmmprof freq freq alignfreq align alignblosum align pssma pssm pssmb pssm);

## Retrieve DSSP data from Jnet DB
my $dbh      = connect_DB('chris');
my $dsspData = get_DSSP($dbh);
die "ERROR - no DSSP data found" unless ( keys %$dsspData );
$dbh->disconnect;

my @tars = glob "*its.tar.gz";

foreach my $tarFile (@tars) {
  print "$tarFile\n";

  system("tar -C $iters -xzf $tarFile --wildcards '*1.net_$iters' --wildcards '*net.c' --wildcards '*2_blank.net'") == 0 or die "untar failed for $tarFile. Died";
  chdir($iters) or die "ERROR - unable to cd to '$iters'. Died";
  foreach my $net (@nets) {
    next unless ( $tarFile =~ /^${net}_/ );

    ## generate 1st layer binary for the required network
    system("/sw/bin/snns2c ${net}1.net_$iters ${net}1.c ${net}1") == 0 or die "ERROR - snns2c failed for '${net}1'. Died";
    system("gcc -c ${net}1.c") == 0                                    or die "ERROR - gcc failed for '${net}1'. Died ";
    system("gcc -Wall -o ${net}1net ${net}1net.c ${net}1.o -lm") == 0  or die "ERROR - gcc failed for '${net}1net'. Died ";
    system("cp ${net}1.[ch] ../jnet_src") == 0                         or die "ERROR - unable to copy file '${net}1.[ch]'";

    ## generate prediction data for training of 2nd layer
    my $numElements = 3;
    $numElements = 4 if ( $profLookup{$net} eq 'align' );

    print "Writing out SNNS pattern file...\n";
    my $fh = write_new( "${net}2.pat", 'NNN', ( $numElements * 19 ) );

    print "Generating SNNS Batch file..\n";
    make_batch( "${net}2_blank.net", "${net}2", $iters, 0.1 );

    my @files   = glob "../*.$profLookup{$net}";
    my $totPats = 0;
    printf "Reading in %d files and extracting data...\n", scalar @files;
    foreach my $dataFile (@files) {

      my $root;
      if ( $dataFile =~ /(\w+)\.\w+/ ) {
        $root = $1;
      } else {
        die "ERROR - can't parse filename for \'$dataFile\'";
      }
      my $data;
      if ( $profLookup{$net} eq 'align' ) {
        ## parse the PSI-BLAST alignment and create a 2D array with the
        ## sequence number as the 1st dimension and the residue as the
        ## 2nd dimension.
        my $align = get_alignment($dataFile);

        ## calculate the Conservation Score from the alignment as per Zvelebil et al, JMB (1987) 195, 957-961
        my @consScore = calc_cons($align);

        ## get prediction from layer 1 network and convert into input data.
        $data = get_pred( $dataFile, $net, $root, @consScore );

      } else {
        ## get prediction from layer 1 network and convert into input data.
        $data = get_pred( $dataFile, $net, $root );
      }
      die "ERROR - no data found for $dataFile" unless ( scalar @{$data} );

      ## get DSSP data for the profile in question and reduce down to 3-state definitions.
      ## Return false if nothing done.
      my @dssp = split //, reduce_dssp( $dsspData->{$root}{'dssp'} );
      die "ERROR - no DSSP data found for $root. Check that it exists in the database." if ( !@dssp );
      die "ERROR - lengths of input and DSSP don't agree for $dataFile" if ( scalar @dssp != scalar @$data );

      my @pattern;
      ## collate pattern data for current structure and add to others
      $totPats += pattern_data( $data, \@pattern, 0, 9 );

      write_patterns( $fh, \@pattern, \@dssp, $root );
    }
    close($fh);

    ## Horrible fudge to add the number of input patterns to the SNNS pattern file.
    ## Need to do it this way as we can't know beforehand how many there are.
    system("perl -i -pe 's/NNN/$totPats/' ${net}2.pat") == 0 or die "ERROR - unable to edit ${net}2.pat";

    ## edit bash code for current network - found in DATA at bottom of script
    my $pos = tell(DATA);    # remember start of <DATA>
    open( my $OUT, ">${net}2.sh" ) or die "ERROR - ${net}2: $!";
    while (<DATA>) {
      s/NN/${net}2/g;
      s/NUM/$iters/g;
      print $OUT $_;
    }
    close($OUT);
    seek( DATA, $pos, 0 );    # rewind <DATA> to start - need to use $pos as '0' is start of perl script.

    print "Training Network...\n";
    system("$SGE ${net}2.sh") == 0 or die "ERROR - unable to qsub for '${net}2'. Died";

  }
  chdir('..');
}
chdir($iters);
system("cp -a /homes/chris/projects/workspace/jnet_training/src jnet_src") == 0 or die "ERROR - unable to cp Jnet source files. Died";
system("make -C jnet_src clean") == 0                                           or die "ERROR - unable to make clean";
exit;

sub get_pred {
  my ( $file, $prefix, $root, @score ) = @_ or return;

  #print "Getting predictions for $root...\n";
  my $dssp = reduce_dssp( $dsspData->{$root}{'dssp'} );
  my @dsspData = split //, $dssp;
  create_pattern( $file, $prefix, \@dsspData );
  my $pred = `./${prefix}1net -i $root.pat` or die "ERROR - prediction failed for $root.pat";
  unlink("$root.pat");
  chomp($pred);

  #my $data = map_raw_pred($pred, \@score);
  my $data = map_struct( $pred, \@score );
  return ($data);
}

__DATA__
#!/bin/sh
echo "Training NN network..."
/sw/bin/batchman -f NN.bat
echo "Finished Training"
echo ""
echo "Converting and compiling network code..."
#/sw/bin/snns2c NN.net
/sw/bin/snns2c NN.net_NUM NN.c NN
gcc -c NN.c
gcc -Wall -o NNnet NNnet.c NN.o -lm


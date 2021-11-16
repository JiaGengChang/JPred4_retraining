#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

use strict;
use warnings;
use File::Path;

# change cross-val1 to 1-7
# my $workdir='/cluster/gjb_lab/2472402/snns_cross_val_23_Aug/cross-val1';
my $workdir='/cluster/gjb_lab/2472402/outputs/snns_cross_val_16_Sep/cross-val2/';

scoring($workdir);







sub scoring {
  my $wDir = shift;

  my $cmd;
  my $out;
  my $id;
  my @tars;
  my @jobIDs;

  my $dataDir  = "$wDir/data";
  my $validDir = "$wDir/valid";

  # get the latest version of Jnet from subversion
  my $currJnet = "$wDir/jnet_src";
  if ( -d $currJnet ) {
    warn "Warning! Old jnet source dir exists and will be deleted\n";
    rmtree($currJnet);
  }
  my $JNETSRC="/cluster/gjb_lab/2472402/jnet_src_v.2.3.1/";
  system("cp -r $JNETSRC $currJnet") == 0 or die "ERROR! can't copy Jnet data. Died ";

  # Score all networks against the training and validation sets
  chdir($wDir) or die "ERROR! unable to cd to $wDir";
  print "Calculating Scores ($wDir).\n";
  @tars = glob "*.gz";

  if ( scalar @tars != 9 ) {
    warn "Not enough network archives found for $wDir (expecting 9). Skipping scoring...\n";
    return 0;
  }

  # extract network code and binaries for scoring
  foreach my $file (@tars) {
    my $root;
    if ( $file =~ /(\w+)\.tar\.gz/ ) {
      $root = $1;
    } else {
      die "ERROR! unable to match name for $file";
    }
    system("tar -xzf $file --wildcards '*[0125]net'") == 0                or die "ERROR! unable to run tar on $file";
    system("tar -C $currJnet -xzf $file --wildcards '*[0125].[ch]'") == 0 or die "ERROR! unable to untar $file";
  }

  # submit testing of trained networks to the cluster as they can take a while
  my $SCRIPTS="$wDir/jnet_src";
  print "Structure Networks ($wDir)...\n";
  $cmd = "$SCRIPTS/score_training.pl -type all -data $dataDir -out score_train";
  $id = submit_cluster( $cmd, "Training Scoring" );
  push @jobIDs, $id;
  if ($validDir) {
    $cmd = "$SCRIPTS/score_training.pl -type all -data $validDir -out score_valid";
    $id = submit_cluster( $cmd, "Validation Scoring" );
    push @jobIDs, $id;
  } else {
      #... FIXME
  }

  if ($validDir) {
    print "Jnet Validation Scores ($validDir)...\n";

    # clean the Jnet code to ensure it's current
    system("make -C $currJnet --silent clean") == 0 or die "ERROR! unable to make clean";

    # compile but don't remake 'cmdline.c/h'. Not necessary and requires gengetopt which isn't on the cluster.
    system("touch $currJnet/cmdline/cmdline.[ch]");
    system("make -C $currJnet --silent 2>/dev/null");
    die "ERROR! Jnet failed to compile!\nDied" unless ( -e "$currJnet/jnet" );
    $cmd = "$SCRIPTS/score_jnet.pl  -data $validDir -jnet $currJnet -jnet-version 2.1 -pred-items jnetpred -out score_jnetval_custom.csv -delete";
    $id = submit_cluster( $cmd, "Jnet Scoring" );
    push @jobIDs, $id;
  }

  return (@jobIDs);
}


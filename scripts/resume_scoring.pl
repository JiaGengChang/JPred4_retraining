#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

# requires: GCC and make. Can run this in a qlogin session.


# this script is to resume scoring after crash on 25 Aug run of wrapper.pl because I specified the JNET_SRC directory wrongly. log for crash is in the err file.
# remember to activate conda environment in which gcc is installed, e.g. conda activate jnet
# otherwise it will crash at the step where it tries to 'make -C $currJnet'

use strict;
use warnings;

use File::Path;
use lib '/cluster/gjb_lab/2472402/jpred_train/lib';

my $path=shift; # ABSOLUTE PATH ONLY
my $whole;
my $DATA;
my $VALID;
my $JNETSRC='/cluster/gjb_lab/2472402/jpred_train/jnet_src_v.2.3.1';
my $SCRIPTS='/cluster/gjb_lab/2472402/jpred_train';
my $QSUB='qsub -pe smp 8 -m a -M 2472402@dundee.ac.uk -R y -mods l_hard mfree 16G -jc short -cwd';
print "scoring $path\n";
# system("unset LD_GOLD"); # this will otherwise give an error in sub submit_cluster
scoring($path);
print "scoring completed!\n"; 
#print "changing permissions to read only\n";
#system("chmod -w $path/*");
  

sub scoring {
  my $wDir = shift;
  my $cmd;
  my $out;
  my $id;
  my @tars;
  my @jobIDs;

  my $dataDir  = "$wDir/data";
  my $validDir = "$wDir/valid";
  if ($whole) {
    $dataDir  = $DATA;
    $validDir = $VALID;
  }

  # get the latest version of Jnet from subversion
  my $currJnet = "$wDir/jnet_src";
  if ( -d $currJnet ) {
    warn "Warning! Old jnet source dir exists and will be deleted\n";
    rmtree($currJnet);
  }
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
    system("tar -C $JNETSRC -xzf $file --wildcards '*[0125].[ch]'") == 0 or die "ERROR! unable to untar $file";
  }

  # submit testing of trained networks to the cluster as they can take a while
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
    # something wrong - "ERROR! Jnet failed to compile!" is always the error message.
    system("make -C $currJnet --silent clean") == 0 or die "ERROR! unable to make clean";

    # compile but don't remake 'cmdline.c/h'. Not necessary and requires gengetopt which isn't on the cluster.
    system("touch $currJnet/cmdline/cmdline.[ch]");
    system("make -C $currJnet");
    die "ERROR! Jnet failed to compile!\nDied" unless ( -e "$currJnet/jnet" );
    $cmd = "perl $SCRIPTS/score_jnet.pl  -data $validDir -jnet $currJnet -jnet-version 2.1 -pred-items jnetpred,jnetpssm,jnethmm -out score_jnetval.csv -delete &";
    #$cmd = "$SCRIPTS/score_jnet.pl  -data $validDir -jnet $currJnet -jnet-version 2.1 -pred-items jnetpred,jnetpssm,jnethmm,jnetsol0,jnetsol5,jnetsol25 -out score_jnetval.csv ";
    system($cmd);
  }

  return 1;
}

sub submit_cluster {
  my ( $cmd, $type ) = @_;

  my $out = `$QSUB $cmd`;
  #my $out = ` $QSUB $cmd`;
  my $jobid = ( split( /\s+/, $out ) )[2];
  if ( $jobid !~ /^\d+$/ ) {
    warn "ERROR! qsub didn't return a job ID for $type: $out";
    return (0);
  } else {
    print "$type has been submitted as job $jobid\n";
    return ($jobid);
  }
}



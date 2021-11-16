#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl 

=head1 NAME

  train_jnet.pl - wrapper script to train Jnet

=cut

# script to wrap the training of JNet networks.
# Needed for defining which part of the cross-validation data to train against
# and control the submissions to the cluster for each of the networks, plus
# general housekeeping stuff...

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use File::Basename;
use File::Path;

## look-up table for allowed working directories for each set of networks
my %lookup = (
  freq      => 'freq',
  hmm       => 'hmm',
  pssm0     => 'pssma',
  pssm1     => 'pssmb',
  align0    => 'alignblosum',
  align1    => 'alignfreq',
  hmmsol0   => 'hmmsol0',
  pssmsol0  => 'psisol0',
  hmmsol5   => 'hmmsol5',
  pssmsol5  => 'psisol5',
  hmmsol25  => 'hmmsol25',
  pssmsol25 => 'psisol25'
);

my $SGE      = 'source /gridware/sge/default/common/settings.sh';
my $QSUB     = 'qsub -pe smp 4 -q c6145-long.q -l qname=c6145-long.q -m a -M a.drozdetskiy@dundee.ac.uk -R y -l ram=4000M -cwd';
my $QSUB_ACC = 'qsub -pe smp 4 -q c6145-long.q -l qname=c6145-long.q -m a -M a.drozdetskiy@dundee.ac.uk -R y -l ram=4000M -cwd';
my $TRAINDIR = 'Networks';
my $nfolds   = 7;                                                                                            # num cross-validations
my $layer    = 2;                                                                                            # number of layers
my $iters    = 300;                                                                                          # number of iterations
my $nhid     = 100;                                                                                          # number of hidden nodes
my $nhidAcc  = 9;                                                                                            # number of hidden nodes for solvent accessibilty

my $SRCROOT = '/homes/www-jpred/jnet_train/code';                                                            # path to root directory to all Jpred codes
my $JNETSRC = $SRCROOT . 'sources/jnet/trunk';                                                               # source path for Jnet code
my $SCRIPTS = $SRCROOT . 'training/trunk';                                                                   # path to scripts required for training
my $current = $ENV{PWD};                                                                                     # current directory
my $DATA;                                                                                                    # Data path
my $archiveName;                                                                                             # name for final data archive
my $rootDir;                                                                                                 # working directory
my $VALID;                                                                                                   # Validation data path
my $whole = 0;                                                                                               # toggle for training on whole set
my $hard  = 0;                                                                                               # toggle for using harder 8->3 DSSP conversion
my $DEBUG = 0;
my $man;
my $help;

GetOptions(
  'data=s'      => \$DATA,
  'valid=s'     => \$VALID,
  'jnetsrc=s'   => \$JNETSRC,
  'binpath=s'   => \$SCRIPTS,
  'out=s'       => \$archiveName,
  'nhid=i'      => \$nhid,
  'acc-hid=i'   => \$nhidAcc,
  'iters=i'     => \$iters,
  'cross-val=i' => \$nfolds,
  'wdir=s'      => \$rootDir,
  'hard!'       => \$hard,

  'debug!' => \$DEBUG,
  'help|?' => \$help,
  'man'    => \$man
) or pod2usage();

pod2usage( -verbose => 1 ) if $help;
pod2usage( -verbose => 2 ) if $man;

pod2usage( -msg => "Number of folds should be > 0\n",      -verbose => 0 ) if ( 0 >= $nfolds );
pod2usage( -msg => "Specify a valid path to the data.\n",  -verbose => 0 ) if ( !$DATA or !-e $DATA );
pod2usage( -msg => "Give an output name.\n",               -verbose => 0 ) if ( !$archiveName );
pod2usage( -msg => "Specify a valid working directory.\n", -verbose => 0 ) if ( !$rootDir or !-e $rootDir );

print "\nDATA: $DATA\n";
print "VALID: $VALID\n" if ($VALID);
print "\n";

##################################################################################################################################
if ( $nfolds == 1 ) {
  print "\n----Training on whole set----\n";
  $whole = 1;
}

my $kth;
my @files;
my $overRide = 0;
if ( -e 'resume.log' ) {
  print "\n** Resuming previous Cross-Validation Run **\n";
  open( my $RES, 'resume.log' ) or die "ERROR! unable to open resume file: $!";
  while (<$RES>) {
    if (/\#SET\s(\d+)/) {
      if ($overRide) {

        # derive size of 1st set in resume file for defining kth set size
        $kth = scalar @files unless $kth;
        next;
      } else {

        # set the over-ride value for 1st cross-validation set resumed mode
        $overRide = $1;
      }
    } else {
      chomp;
      push @files, $_;
    }
  }
} else {
  if ($whole) {
    @files = glob "$DATA/*.pssm";
    die "ERROR! no data files found" unless (@files);
    $kth = 0;
    my $nfiles = $#files;
    print "$nfiles domains are being used for training\n\n";
  } else {
    @files = glob "$DATA/*.pssm";
    die "ERROR! no data files found" unless (@files);
    my $nfiles = $#files;
    print "$nfiles domains are being used for training\n";
    shuffle( \@files );

    $kth = int( ( scalar @files / $nfolds ) + 1 );

    # store list of shuffled files for easy resume.
    store_shuffle( \@files, $kth );
  }
}

##################################################################################################################################
# prepare run (either cross-validatiot run al whole-date run)
#
my %jobs;
my $set = 1;
$set = $overRide if ($overRide);    # override set number if resuming a CrossVal run
while ( $set <= $nfolds ) {
  my ( $workDir, $dataDir );
  if ($whole) {
    $workDir = "$rootDir/all";
    $dataDir = "$workDir/data";
    mkdir($workDir) or die "ERROR! unable to mkdir for '$workDir' (working directory): $!";
    mkdir($dataDir) or die "ERROR! unable to mkdir for '$dataDir' (data directory): $!";
    chdir($workDir) or die "ERROR! unable to cd to '$workDir': $!";
    $dataDir = $DATA;
  } else {
    print "\n----Cross-Validation $set----\n";

    $workDir = "$rootDir/cross-val$set";
    $dataDir = "$workDir/data";
    my $valid = "$workDir/valid";
    print "\nWorking Dir: $workDir\n" if ($DEBUG);
    die "ERROR! working dir already exists '$workDir'" if ( -e $workDir );
    mkdir($workDir) or die "ERROR! unable to mkdir for '$workDir' (working directory): $!";
    mkdir($dataDir) or die "ERROR! unable to mkdir for '$dataDir' (data directory): $!";
    mkdir($valid)   or die "ERROR! unable to mkdir for '$workDir' (validation data): $!";
    chdir($workDir) or die "ERROR! unable to cd to '$workDir': $!";

    # link to real data files and move the validation files to the valid/ directory
    print "Partitioning Cross-Validation Data...";
    system("find $DATA -type f -exec ln -s {} $dataDir \\;") == 0 or die "ERROR! unable to copy datafiles";
    my @validSet = splice @files, 0, $kth;
    foreach my $file (@validSet) {
      my $root;
      if ( $file =~ /(\w+)\.pssm/ ) {
        $root = $1;
      } else {
        die "ERROR! can't parse filename for \'$file\'";
      }
      my @store = map { "$dataDir/$root.$_" } qw(hmm pssm);
      system("mv @store $valid") == 0 or die "ERROR! unable to move validation set for $root";

    }
    my @train = glob "$dataDir/*.pssm";
    printf "Done.\nUsing %d sequences for training and %d for validation\n", scalar @train, scalar @validSet;
  }

##################################################################################################################################
  # submit SNNS training jobs to cluster and store their job ids
  #
  foreach my $profile qw(pssm hmm) {
    my $cmd;
    if ( $profile =~ /pssm/ ) {
      for my $sub ( 0 .. 1 ) {
        mkdir( $lookup{ $profile . $sub } ) or die "ERROR! unable to mkdir '$lookup{$profile.$sub}': $!\nDied at";
        $cmd = "$SCRIPTS/train_network.pl -iters $iters -nhid $nhid -dir $workDir/$lookup{$profile.$sub} -type $profile -sub $sub -layer $layer -out $workDir -data $dataDir/";
        $cmd .= " -hard" if $hard;
        print "command: $cmd\n" if ($DEBUG);
        my $id = submit_cluster( $cmd, "Profile $profile ($sub)" );
        die "ERROR! no job ID returned for profile $profile ($sub)\n" unless ($id);
        push @{ $jobs{"$workDir"} }, $id;
      }
      for my $cut qw(0 5 25) {
        my $name = "${profile}sol$cut";
        mkdir( $lookup{$name} ) or die "ERROR! unable to mkdir '$lookup{$name}': $!\nDied at";
        $cmd = "$SCRIPTS/train_solacc.pl -iters $iters -nhid $nhidAcc -dir $workDir/$lookup{$name} -type $profile -cut $cut -out $workDir -data $dataDir/";
        print "command: $cmd\n" if ($DEBUG);
        my $out = `$SGE && $QSUB_ACC $cmd` or die "ERROR! qsub failed for $name";
        my $id = ( split( /\s+/, $out ) )[2];
        if ( $id !~ /^\d+$/ ) {
          die "ERROR! qsub didn't return a job ID for $name: $out";
        }
        print "Profile $name has been submitted as job $id\n";
        push @{ $jobs{"$workDir"} }, $id;
      }
    } elsif ( $profile =~ /hmm/ ) {
      mkdir( $lookup{$profile} ) or die "ERROR! unable to mkdir '$lookup{$profile}': $!\nDied at";
      $cmd = "$SCRIPTS/train_network.pl -iters $iters -nhid $nhid -dir $workDir/$lookup{$profile} -type $profile -layer $layer -out $workDir -data $dataDir/";
      $cmd .= " -hard" if $hard;
      print "command: $cmd\n" if ($DEBUG);
      my $id = submit_cluster( $cmd, "Profile $profile" );
      die "ERROR! no job ID returned for profile $profile\n" unless ($id);
      push @{ $jobs{"$workDir"} }, $id;

      for my $cut qw(0 5 25) {
        my $name = "${profile}sol$cut";
        mkdir( $lookup{$name} ) or die "ERROR! unable to mkdir '$lookup{$name}': $!\nDied at";
        $cmd = "$SCRIPTS/train_solacc.pl -iters $iters -nhid $nhidAcc -dir $workDir/$lookup{$name} -type $profile -cut $cut -out $workDir -data $dataDir/";
        print "command: $cmd\n" if ($DEBUG);
        my $out = `$SGE && $QSUB_ACC $cmd` or die "ERROR! qsub failed for $name";
        my $id = ( split( /\s+/, $out ) )[2];
        if ( $id !~ /^\d+$/ ) {
          die "ERROR! qsub didn't return a job ID for $name: $out";
        }
        print "Profile $name has been submitted as job $id\n";
        push @{ $jobs{"$workDir"} }, $id;
      }

    } elsif ( $profile =~ /align/ ) {
      for my $sub ( 0 .. 1 ) {
        mkdir( $lookup{ $profile . $sub } ) or die "ERROR! unable to mkdir '$lookup{$profile.$sub}': $!\nDied at";
        $cmd = "$SCRIPTS/train_network.pl -iters $iters -nhid $nhid -dir $workDir/$lookup{$profile.$sub} -type $profile -sub $sub -layer $layer -out $workDir -data $dataDir/";
        $cmd .= " -hard" if $hard;
        print "command: $cmd\n" if ($DEBUG);
        my $id = submit_cluster( $cmd, "Profile $profile ($sub)" );
        die "ERROR! no job ID returned for profile $profile ($sub)\n" unless ($id);
        push @{ $jobs{"$workDir"} }, $id;
      }
    } else {
      mkdir( $lookup{$profile} ) or die "ERROR! unable to mkdir '$lookup{$profile}': $!\nDied at";
      $cmd = "$SCRIPTS/train_network.pl -iters $iters -nhid $nhid -dir $workDir/$lookup{$profile} -type $profile -layer $layer -out $workDir -data $dataDir/";
      $cmd .= " -hard" if $hard;
      print "command: $cmd\n" if ($DEBUG);
      my $id = submit_cluster( $cmd, "Profile $profile" );
      die "ERROR! no job ID returned for profile $profile\n" unless ($id);
      push @{ $jobs{"$workDir"} }, $id;
    }

  }
  ++$set;
}

##################################################################################################################################
# check network training jobs running on cluster
#
print "\nWaiting for jobs to finish...\n";
my %finishedTrain;    # hash to keep track of datasets that are finished training
my @scoreJobs;
while (%jobs) {
  sleep(120);         # every 2 minutes check that all jobs are still running
  foreach my $set ( keys %jobs ) {
    next unless exists( $jobs{"$set"} );
    my $last = scalar @{ $jobs{"$set"} } - 1;
    foreach my $i ( 0 .. $last ) {
      next unless exists( $jobs{"$set"}[$i] );
      if ( check_job( $jobs{"$set"}[$i] ) == 0 ) {
        if ( $finishedTrain{"$set"} ) {
          if ( -z "$set/score_training.pl.e$jobs{\"$set\"}[$i]" ) {
            print "scoring job $jobs{\"$set\"}[$i] has finished.\n";
            unlink("$set/score_training.pl.e$jobs{\"$set\"}[$i]");
          } elsif ( -z "$set/score_jnet.pl.e$jobs{\"$set\"}[$i]" ) {
            print "scoring job $jobs{\"$set\"}[$i] has finished.\n";
            unlink("$set/score_jnet.pl.e$jobs{\"$set\"}[$i]");
          } else {
            warn "WARNING! scoring job $jobs{\"$set\"}[$i] in set '$set' finished with errors.\n";
          }

        } else {
          if ( -z "$set/train_network.pl.e$jobs{\"$set\"}[$i]" ) {
            print "training job $jobs{\"$set\"}[$i] has finished.\n";
            unlink("$set/train_network.pl.e$jobs{\"$set\"}[$i]");
          } elsif ( -z "$set/train_solacc.pl.e$jobs{\"$set\"}[$i]" ) {
            print "solacc training job $jobs{\"$set\"}[$i] has finished.\n";
            unlink("$set/train_solacc.pl.e$jobs{\"$set\"}[$i]");
          } else {
            warn "WARNING! training job $jobs{\"$set\"}[$i] in set $set finished with errors.\n";
          }
        }
        delete $jobs{"$set"}[$i];
        if ( scalar @{ $jobs{"$set"} } == 0 ) {
          if ( $finishedTrain{"$set"} ) {
            print "\n-- All scoring for $set completed --\n";
            delete $jobs{"$set"};
            chdir($set) or warn "Unable to cd to '$set': $!";
            system("tar cf ${archiveName}.tar *.gz *.csv train*.o*") == 0 or warn "WARNING! tar failed in $set";
          } else {
            print "\n-- All training for $set completed --\n";
            chomp( my $countErr = `ls $rootDir/$set/train_network.pl.e* 2>/dev/null | wc -l` );
            if ($countErr) {
              warn "WARNING! not all training completed successfully. Skipping scoring...\n";
              next;
            }
            $finishedTrain{$set}++;

            # ...and start scoring $set...
            print "scoring NN in directory $set\n" if ($DEBUG);
            my @newJobs = scoring($set);
            if ( scalar @newJobs ) {
              push @{ $jobs{"$set"} }, @newJobs;

            } else {
              warn "Scoring failed for $set!\n";
            }
            print "-- Continuing with other training sets --\n\n";
          }
        }
      }
    }
  }
}
print "All jobs finished.\n";
unlink("$rootDir/resume.log");
exit;

##################################################################################################################################
##################################################################################################################################
##################################################################################################################################
# check and prepare jnet binary and all data for launching score_jnet.pl and score_training.pl for scoring trained networks
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
    system("tar -C $currJnet -xzf $file --wildcards '*[0125].[ch]'") == 0 or die "ERROR! unable to untar $file";
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
    system("make -C $currJnet --silent clean") == 0 or die "ERROR! unable to make clean";

    # compile but don't remake 'cmdline.c/h'. Not necessary and requires gengetopt which isn't on the cluster.
    system("touch $currJnet/cmdline/cmdline.[ch]");
    system("make -C $currJnet --silent 2>/dev/null");
    die "ERROR! Jnet failed to compile!\nDied" unless ( -e "$currJnet/jnet" );
    $cmd = "$SCRIPTS/score_jnet.pl  -data $validDir -jnet $currJnet -jnet-version 2.1 -pred-items jnetpred,jnetsol0,jnetsol5,jnetsol25 -out score_jnetval.csv -delete";
    $id = submit_cluster( $cmd, "Jnet Scoring" );
    push @jobIDs, $id;
  }

  return (@jobIDs);
}

##################################################################################################################################
# submit a job to the cluster (used for Jnet jobs inly!)
sub submit_cluster {
  my ( $cmd, $type ) = @_;

  my $out = `$SGE && $QSUB $cmd`;
  my $jobid = ( split( /\s+/, $out ) )[2];
  if ( $jobid !~ /^\d+$/ ) {
    warn "ERROR! qsub didn't return a job ID for $type: $out";
    return (0);
  } else {
    print "$type has been submitted as job $jobid\n";
    return ($jobid);
  }
}

##################################################################################################################################
# Fisher-Yates shuffle example taken from the Perl Cookbook (O'Reilly)
sub shuffle {
  my $array = shift;

  my $i;
  for ( $i = @$array ; --$i ; ) {
    my $j = int rand( $i + 1 );
    next if $i == $j;
    @$array[ $i, $j ] = @$array[ $j, $i ];
  }
}

##################################################################################################################################
# check queue to see if job is still running
# return true if it is and false if it isn't
sub check_job {
  my ($job) = @_ or return;

  chomp( my $me = `whoami` );
  my $cmd = "$SGE && qstat -u $me | grep $job";
  my $out = `$cmd`;
  return 1 if ($out);
  return 0;
}

##################################################################################################################################
# keep a note of the shuffled list of files.
# useful for when a cross-validation fails and can resume at the point of failure.
sub store_shuffle {
  my ( $list, $setSize ) = @_;

  open( my $FH, ">resume.log" ) or warn "WARNING! unable to open 'resume.log': $!";
  return unless $FH;

  my $set  = 1;
  my $size = 0;
  for my $f (@$list) {
    if ( $size == 0 ) {
      print $FH "#SET $set\n";
      ++$set;
      $size = $setSize;
    }
    print $FH "$f\n";
    --$size;
  }
  close($FH);
}

##################################################################################################################################

=head1 SYNOPSIS

wrapper.pl -data <path> -out <name> -wdir <path> [-valid <path>] [-jnetsrc <path>] [-binpath <path>] [-nhid <num>] [-acc-hid <num>] [-iters <num>] [-cross-val <num>] [-hard|-nohard] [-debug] [-help] [-man]

=head1 DESCRIPTION

Poor, but working, code to wrap the training of all the neural networks required for a new release of Jnet.

All the defaults are set to the last best settings and are best left alone unless you know what you're doing.

Essentially, you run the script in its own directory, point it at another which contains the training data 
and it does the rest. This is achieved by spawning off a series of jobs to the cluster for each of the 
individual Artificial Neural Networks (ANNs) required by each 'fold' of the cross-validation. Currently, 
there are nine ANNs trained for each. Thus, for the default 7-fold cross-validation 63 ANNs are trained in total.

The data required for training is a set HMMer and PSI-BLAST profiles, preferably as generated by Jpred. 
Other sources of profiles have not been tested and are likely to not work. Additionally, DSSP-derived 
secondary structure and solvent accessibility definitions are taken from the I<jnet> compbio MySQL database 
and are used as the 'truth' during training. The correct DSSP definition matches are made from the profile 
names which should be the query sequence ID as found in the I<jnet> database.

There are two types of training being performed on the raw data: solvent accessibility and secondary structure. 
They take the same input profiles, but are trained against different DSSP output.

Using default parameters, the solvent accessibility ANNs finish sooner than the secondary structure ones 
owing to their simpler ANN design. They tend to complete with a couple of hours. However, the secondary 
structure ANNs can take between 1-2 days to complete.


=head1 OPTIONS

=over 5

=item B<-data>

Path to *.hmm and *.pssm files.

=item B<-out>

Name for final output.

=item B<-wdir>

Full path to working directory.

=item B<-valid>

No longer used.

=item B<-jnetsrc>

Path to the Jnet source code. [default: /homes/www-jpred/svn/sources/jnet/trunk]

=item B<-binpath>

Path to code required for training. [default: /homes/www-jpred/jnet_train/code/training/trunk]

=item B<-nhid>

Number of hidden nodes to use in structure neural networks. [default: 100]

=item B<-acc-hid>

Number of hidden nodes to use in solvent accessibility neural networks. [default: 9]

=item B<-iters>

Number of interations to run training for all networks. [default: 300]

=item B<-cross-val>

n-fold cross-validation to perform. [default: 7]

=item B<-hard|-nohard>

Use (or not) hard DSSP 8->3 conversion. [default: -nohard]

=back

=head1 TECHNICAL OPTIONS

=over 15

=item B<-debug>

Switch to add debugging info.

=item B<-help>

Brief help.

=item B<-man>

Full manpage of program.

=back

=head1 AUTHOR

Chris Cole <christian@cole.name>

=cut

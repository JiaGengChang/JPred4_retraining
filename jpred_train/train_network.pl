#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

=head1 NAME

train_network.pl -- Script to create SNNS network and pattern files for training

=cut

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

my $PATH    = '/cluster/gjb_lab/2472402/jpred_train';    # to valid_patset.pl script
my $workDir;                                                # working directory
my $DATA;                                                         # location of data files
my $finalDir;                                               # final location for training data

my $numIters = 300;                                               # number of training iterations
my $numElements;                                                  # number of data elements per residue
my $numHidden     = 100;                                          # number of hidden nodes in SNNS network
my $randomWeights = 0.1;                                          # range (+-) of random initial weights on network
my $flank;                                                        # size of flanking regions in sliding window
my $profileType;                                                  # type of profile to create (user input)
my $subType = 0;                                                  # subtype of profile (user input)
my $outPrefix;                                                    # output name for network-related files
my $layer = 2;                                                    # layer to train
my $valid = 0;
my $hard  = 0;                                                    # toggle difficult 8->3 DSSP mapping
my $help;
my $man;

GetOptions(
  'type=s'  => \$profileType,
  'sub=i'   => \$subType,
  'dir=s'   => \$workDir,
  'data=s'  => \$DATA,
  'layer=i' => \$layer,
  'valid'   => \$valid,
  'iters=i' => \$numIters,
  'nhid=i'  => \$numHidden,
  'out=s'   => \$finalDir,
  'hard!'   => \$hard,
  'help|?'  => \$help,
  'man'     => \$man
) or pod2usage(0);

pod2usage( -verbose => 2 ) if $man;
pod2usage( -verbose => 1 ) if $help;
pod2usage( -msg => 'Please give a profile type to train on',                 -verbose => 0 ) if !$profileType;
pod2usage( -msg => 'Invalid layer. Try again with a valid number (1 or 2).', -verbose => 0 ) if ( ( $layer < 1 ) || ( $layer > 2 ) );
pod2usage( -msg => 'Please give the path to the data.',                      -verbose => 0 ) if ( !$DATA );

my $host = `hostname -s` or die "ERROR - hostname failed";
chomp($host);
print "Job running on: $host\n";

## Create working directory if necessary and cd to it
if ( !-e $workDir ) {
  mkdir($workDir) or die "ERROR - unable to create '$workDir': $!\n";
}
chdir($workDir) or die "ERROR - unable to cd to '$workDir': $!\n";

## Depending on which profile used set the output network name and number of data elements to expect.
if ( $profileType =~ /hmm/i ) {
  $outPrefix   = 'hmm';
  $numElements = 24;
} elsif ( $profileType =~ /freq/i ) {
  $outPrefix   = 'freq';
  $numElements = 20;
} elsif ( $profileType =~ /pssm/i ) {
  $numElements = 20;
  if ( ( $subType > 1 ) or ( $subType < 0 ) ) {
    pod2usage( -msg => "Invalid alignment sub-type ($subType). Please give a value of 0 (9 hidden nodes) or 1 (20 hidden nodes)", -verbose => 0 );
  }
  if ( $subType == 0 ) {
    $outPrefix = 'pssma';
  } else {
    $numHidden = 20;
    $outPrefix = 'pssmb';
  }
} elsif ( $profileType =~ /align/i ) {
  $numElements = 25;
  if ( ( $subType > 1 ) or ( $subType < 0 ) ) {
    pod2usage( -msg => "Invalid alignment sub-type ($subType). Please give a value of 0 (BLOSUM) or 1 (Frequency)", -verbose => 0 );
  }
  if ( $subType == 0 ) {
    $outPrefix = 'alignblosum';
  } else {
    $outPrefix = 'alignfreq';
  }
} else {
  die "ERROR - unrecognised network type \'$profileType\'";
}

## get files to train against
my @files = glob "$DATA/*.$profileType";
die "ERROR - no files found" if ( !@files );

# Retrieve DSSP data from Jnet DB
my $dbh      = connect_DB('jnet-user');
my $dsspData = get_DSSP($dbh);
die "ERROR - no DSSP data found" unless ( keys %$dsspData );
$dbh->disconnect;

# USE THIS IF YOU ONLY HAVE DOMAIN NAMES RATHER THAN SEQIDs
# my $dsspData = get_DSSP_no_DB();
# die "ERROR - no DSSP data found" unless ( keys %$dsspData );


for ( my $l = 1 ; $l <= $layer ; ++$l ) {

  print "\nLayer $l Network\n---------------\n";

  ## set layer-specific variables
  if ( $l == 1 ) {
    $flank = 8;

    #$numIters = 180 if $outPrefix eq 'hmm';
  } elsif ( $l == 2 ) {
    $flank = 9;

    #$numIters = 140 if $outPrefix eq 'pssmb';
    if ( $profileType =~ /align/i ) {
      $numElements = 4;
    } else {
      $numElements = 3;
    }
  }

  ## Write the patterns to file and add the dssp output pattern as well.
  ## Doing this here, as storing all the data in RAM for later dumping is too memory inefficient.
  ## Need to edit the file at the end to substitute NNN with the real number of input patterns.
  print "Writing out SNNS pattern file...\n";
  my $fh = write_new( "$outPrefix$l.pat", 'NNN', ( $numElements * ( 2 * $flank + 1 ) ) );

  ## work out the size of the network and create it.
  my $numUnits = $numElements * ( 2 * $flank + 1 );
  print "Generating Neural Network...\n";
  make_net( "$outPrefix${l}_blank.net", $numUnits, $numHidden, 3 );

  ## create validation patterns for testing during training
  if ($valid) {
    print "\nGenerating Validation Patterns...\n";
    system("$PATH/valid_patset.pl --type $outPrefix --dir $workDir --layer $l --data $DATA/valid") == 0 or die "ERROR - unable to create validation set";
    print "\n";
  }

  ## create the SNNS batchfile
  print "Generating SNNS Batch file..\n";
  if ($valid) {
    make_batch_valid( "$outPrefix${l}_blank.net", $outPrefix . $l, $numIters, $randomWeights );
  } else {
    make_batch( "$outPrefix${l}_blank.net", $outPrefix . $l, $numIters, $randomWeights );
  }

  ## get pattern data
  printf "Reading in %d files and extracting data...\n", scalar @files;
  my $totPats = 0;
  foreach my $dataf (@files) {

    my @pattern;
    my @dsspOut;

    my $root = basename( $dataf, ".$profileType" );
    my $extn = $profileType;

    die "ERROR - can't parse filename for \'$dataf\'" unless ($root);

    ## retrieve raw data
    my $data;
    if ( $profileType eq 'align' ) {
      ## parse the PSI-BLAST alignment and create a 2D array with the
      ## sequence number as the 1st dimension and the residue as the
      ## 2nd dimension.
      my $align = get_alignment($dataf);

      ## calculate the Conservation Score from the alignment as per Zvelebil et al, JMB (1987) 195, 957-961
      my @consScore = calc_cons($align);

      if ( $l == 1 ) {
        ## generate the data from the alignment and Conservation Score
        ## $subType: 0 = BLOSUM profile and 1 = Frequency profile
        $data = get_psi_data( $align, \@consScore, $subType );
      } elsif ( $l == 2 ) {
        ## get prediction from layer 1 network and convert into input data.
        $data = get_pred( $dataf, $root, @consScore );
      }

    } else {
      if ( $l == 1 ) {
        ## retrieve the profile data from the input fileand return as
        ## reference to an AoA
        $data = get_data( $dataf, $extn );
      } elsif ( $l == 2 ) {
        ## get prediction from layer 1 network and convert into input data.
        $data = get_pred( $dataf, $root );
      }
    }
    die "ERROR - no data found for $dataf" unless ( scalar @{$data} );

    ## get DSSP data for the profile in question and reduce down to 3-state definitions.
    ## Return false if nothing done.
    my $dssp = reduce_dssp( $dsspData->{$root}{'dssp'}, $hard );
    die "ERROR - no DSSP data found for $root. Check that it exists in the database." if ( !$dssp );
    die "ERROR - lengths of input and DSSP don't agree for $dataf" if ( length($dssp) != scalar @$data );

    ## concatenate DSSP data with all the others
    push @dsspOut, split( //, $dssp );

    ## collate pattern data for current structure and add to others
    $totPats += pattern_data( $data, \@pattern, 0, $flank );

    foreach my $pat ( 0 .. $#pattern ) {
      print $fh "# Input ${root}_$pat:\n";
      foreach my $data ( @{ $pattern[$pat] } ) {
        print $fh "$data ";
      }
      print $fh "\n# Output ${root}_$pat:\n";
      if ( $dsspOut[$pat] eq 'H' ) {
        print $fh "0 1 0";
      } elsif ( $dsspOut[$pat] eq 'E' ) {
        print $fh "1 0 0";
      } elsif ( $dsspOut[$pat] eq '-' ) {
        print $fh "0 0 1";
      } else {
        die "ERROR - disallowed dssp character: \'$dsspOut[$pat]\' at position $pat\n";
      }
      print $fh "\n";
    }
  }
  close($fh);

  ## Horrible fudge to add the number of input patterns to the SNNS pattern file.
  ## Need to do it this way as we can't know beforehand how many there are.
  system("perl -i -pe 's/NNN/$totPats/' $outPrefix$l.pat") == 0 or die "ERROR - unable to edit $outPrefix$l.pat";

  ## edit skeleton C code for current network - found in DATA at bottom of script
  my $pos = tell(DATA);    # remember start of <DATA>
  open( my $OUT, ">$outPrefix${l}net.c" ) or die "ERROR - $outPrefix${l}net.c: $!";
  while (<DATA>) {
    s/NN/$outPrefix$l/g;
    print $OUT $_;
  }
  close($OUT);
  seek( DATA, $pos, 0 );    # rewind <DATA> to start - need to use $pos as '0' is start of perl script.

  print "Training Network...\n";
  train_net( $outPrefix . $l );
}
close(DATA);

## Check that the final output directory is not the same as the working directory
## and tar up the data files and move to final location.
## If they are the same do nothing and exit.
if ( $finalDir ne $workDir ) {
  print "Moving files to $finalDir...\n";
  system("tar --exclude $outPrefix.tar.gz -czf $outPrefix.tar.gz $outPrefix*") == 0                        or die "ERROR - tar failed";
  system("mv -f $outPrefix.tar.gz $finalDir/${outPrefix}_${randomWeights}rand_${numIters}its.tar.gz") == 0 or die "ERROR - failed to mv files";
  unlink <$outPrefix*>;
}
print "Finished!\n";
exit;

sub get_pred {
  my ( $file, $root, @score ) = @_ or return;

  #print "Getting predictions for $root...\n";
  my $dssp = reduce_dssp( $dsspData->{$root}{'dssp'}, $hard );
  my @dsspData = split( //, $dssp );
  create_pattern( $file, $outPrefix, \@dsspData );
  my $pred = `./${outPrefix}1net -i $root.pat` or die "ERROR - prediction failed for $root.pat";
  unlink("$root.pat");
  chomp($pred);

  #my $data = map_raw_pred($pred, \@score);
  my $data = map_struct( $pred, \@score );
  return ($data);
}

sub get_raw_pred {
  my ( $file, $root, @score ) = @_ or return;

  #print "Getting predictions for $root...\n";
  my $dssp = reduce_dssp( $dsspData->{$root}{'dssp'}, $hard );
  my @dsspData = split( //, $dssp );
  create_pattern( $file, $outPrefix, \@dsspData );
  my $pred = `${outPrefix}1net -r -i $root.pat` or die "ERROR - prediction failed for $root.pat";

  #unlink("$root.pat");
  chomp($pred);

  my $data = map_raw( $pred, \@score );
  return ($data);
}

=head1 SYNOPSIS

train_network.pl --type <pattern type> [--sub <pattern subtype>] --dir <working dir> --out <dir> --data <dir> [--valid] [--iters <num>] [--nhid <num>] [--layer <no.>] [--hard|--nohard]

=head1 DESCRIPTION

The script does the non-trivial act of taking pre-generated data and turns it into patterns for Neural Network training with the SNNS program. The training is also done within the script and output files are generated ready to be plugged into the JNet program.

By giving the script a pattern type it searches for all files of that type and generates the appropriate pattern and network files ready for SNNS training. The file type is defined by its extension:

   .hmm       HMMer profile
   .freq      frequency profile
   .pssm      PSSM profile derived from PSI-BLAST. This requires a subtype as two networks which differ by the number of hidden nodes.
   .align     multiple sequence alignment in FASTA format generated from the PSI-BLAST output. This requires a subtype to be defined as Jnet uses the alignment to generate Frequency and BLOSUM profiles, with different networks trained for each.

The script creates nine files per trained layer:

   type_blank.net    a template network of the right size for input to SNNS
   type.net    the trained network
   type.c/h    the C code and header files generated by snns2c from the trained network file (above)
   type.bat    an SNNS batch file with the training parameters (where 'type' is the same as the --type argument)
   type.pat    the SNNS pattern which holds all the pattern data for training
   {type}net.c basic C code to take a pattern file for a sequence and apply the network against it to create a prediction
   {type}net   compile code of the above.

Where 'type' is the name of the profile suffixed by the layer number e.g. hmm2. Generally only type.c/h and {type}net files will be of interest.

=head1 OPTIONS

=over 8

=item B<--type> <pattern type>

Define which pattern type to train against. There are four options: hmm, freq, pssm, alignment

There's no default.

=item B<--sub> <pattern subtype>

For the 'align' patterns defined above there is an additional option to define which subtype of alignment profile do you require. For BLOSUM62 use 0 and for Frequency use 1.

Default is 0 (BLOSUM62)

For the 'pssm' patterns the subtype defines the number of hidden nodes to use during training. For 9 hidden nodes use 0 and for 20 hidden nodes use 1.

Default is 0 (100 nodes)

=item B<--dir> <working dir>

Set the working directory for the training file.

Default: current directory

=item B<--layer> <no.>

Set which network layer to train. Layer 1 is the sequence to structure networks and layer 2 is the structure to structure networks. Defining layer 2 will also create the layer 1 networks as required.

Default: 2

=item B<--out> <dir>

Give the full path to final location for training data once finished.

Default: current directory

=item B<--data> <dir>

Full path to the location of the training files.

=item B<--valid>

Optional. Set this option to output the Neural Network performance against the validation set during training.

=item B<--iters> <num>

Set the number of iterations to run the training for. This is used for both layers.

Default: 300

=item B<--nhid> <num>

Set the number of hidden nodes to use in the neural network. This is used for both layers, but is ignored for PSSM networks subtype '1' as this is fixed to 20. 

Default: 100

=item B<--hard|--nohard>

Toggle to setting difficult 8->3 DSSP mapping or not. [default: not]

=item B<--help>

Show brief help.

=item B<--man>

Show more detailed information and backgound.

=back

=head1 AUTHOR

Chris Cole <christian@cole.name>

=cut

__DATA__
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "NN.h"

#define MAXLINE 3800 

int main(int argc, char *argv[]) {

   FILE *patternFile;
   float *netInput, *netOutput;
   int i, n, j, flag;
   int raw = 0;
   char *inputf;
   char pred;
   char line[MAXLINE];
   char num[15];
   
   inputf = malloc(20 * sizeof(char));
   
   netInput = malloc(NNREC.NoOfInput * sizeof(float));
   netOutput = malloc(NNREC.NoOfOutput * sizeof(float));
   
	while ((argc > 1) && (argv[1][0] == '-')) {
		switch (argv[1][1]) {
			case 'r':
				raw = 1;
				break;
			case 'i':
				inputf = &argv[1][3];
				break;
			default:
				printf ("Bad option %s\n", argv[1]);
				exit(1);
		}
		argv++;
		argc--;
	}
   
   /* printf("No. input units: %d\n", NNREC.NoOfInput); */
   
   if ((patternFile = fopen(inputf, "r")) == NULL) {
      printf("ERROR - can't open file\n");
      exit(1);
   } 
   
   /*
    *  Read in pattern file line by line finding the lines with actual data
    */
   while ((fgets(line, sizeof(line), patternFile)) != NULL) {
      
      /*
       * Find lines beginning with '# Input' and set flag 
       * (this is to mark the lines that contain data)
       */
      if (line[0] == '#') {
         if (strncmp("# Input", line, 7) == 0) {
            flag = 1;
         } else {
            flag = 0;
         }
      }
      
      /*
       * If the lines starts with a number or  -ve and the flag is true
       * then this line is data
       */
      if ((isdigit(line[0]) || (line[0] == '-')) && flag) {
         n = 0;   /* data item length counter */
         j = 0;   /* number of data items counter */
         for(i = 0; i < MAXLINE; ++i) {
            switch(line[i]) {
               case ' ':
                  if (n) {
                     netInput[j] = atof(num);
                     n = 0;
                     ++j;
                  }
                  break;
               case '\n':
                  if (n) {
                     netInput[j] = atof(num);
                     n = 0;
                     ++j;
                  }
                  break;
               default:
                  num[n] = line[i];
                  ++n;
                  break;
            }
            if (line[i] == '\n') break;
         }
         
         /*
          *  Do prediction 
          */
         NN(netInput, netOutput, 0);
         
         /*
          *  Output result of prediction (either raw or 3-state)
          */
         if (raw) {
            printf("%4.2f %4.2f %4.2f,", netOutput[0], netOutput[1], netOutput[2]);
         } else {
            pred = '\0';
            if ((netOutput[0] > netOutput[1]) && (netOutput[0] > netOutput[2])) {
               pred = 'E';
            } else if ((netOutput[1] > netOutput[0]) && (netOutput[1] > netOutput[2])) {
               pred = 'H';
            } else if ((netOutput[2] > netOutput[0]) && (netOutput[2] > netOutput[1])) {
               pred = '-';
            } else {
               pred = '?';
            }
            
            if (!pred) {   /* need to watch out for when there is no prediction!! Not sure if this is still relevent?? */
               printf("?");
            } else {
               printf("%c", pred);
            }

         }
      }
   }
   fclose(patternFile);
   
   printf("\n");
   
   return(1);
}

#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

=head1 NAME

train_solacc.pl -- script to train solvent accessibility networks

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use File::Basename;

use lib '/cluster/gjb_lab/2472402/jpred_train/lib'; 

use SNNS::Pattern;
use SNNS::Network;
use Jpred::jnetDB;
use Jpred::Utils;

my $workDir  = '.';         # working directory
my $finalDir = $workDir;    # final location for training data

my $dPath;                  # location of data files
my $numIters = 300;         # number of training iterations
my $numElements;            # number of data elements per residue
my $numHidden     = 9;      # number of hidden nodes in SNNS network
my $randomWeights = 0.1;    # range (+-) of random initial weights on network
my $flank         = 8;      # size of flanking regions in sliding window
my $profileType;            # type of profile to create (user input)
my $outPrefix;              # output name for network-related files
my $cut;
my $help;
my $man;

GetOptions(
  'flank=i' => \$flank,
  'dir=s'   => \$workDir,
  'type=s'  => \$profileType,
  'cut=i'   => \$cut,
  'data=s'  => \$dPath,
  'iters=i' => \$numIters,
  'nhid=i'  => \$numHidden,
  'out=s'   => \$finalDir,
  'help|?'  => \$help,
  'man'     => \$man
) or pod2usage(0);

pod2usage( -verbose => 2 ) if $man;
pod2usage( -verbose => 1 ) if $help;
pod2usage( -msg => 'Please give a profile type to train on',                    -verbose => 0 ) if !$profileType;
pod2usage( -msg => 'Please give the path to the data',                          -verbose => 0 ) if !$dPath;
pod2usage( -msg => 'Please give a sovent accessibility cut-off value (0/5/25)', -verbose => 0 ) if !defined($cut);

my $host = `hostname -s` or die "ERROR - hostname failed";
chomp($host);
print "Job running on: $host\n";

######################################################################################################################################################
# Create working directory if necessary and cd to it
if ( !-e $workDir ) {
  mkdir($workDir) or die "ERROR - unable to create '$workDir': $!\n";
}
chdir($workDir) or die "ERROR - unable to cd to \'$workDir\': $!";

# Depending on which profile used set the output network name and number of data elements to expect.
if ( $profileType =~ /hmm/i ) {
  $outPrefix   = 'hmmsol';
  $numElements = 24;
} elsif ( $profileType =~ /pssm/i ) {
  $outPrefix   = 'psisol';
  $numElements = 20;
} else {
  die "ERROR - unrecognised network type \'$profileType\'";
}

# get files to train against
my @files = glob "$dPath/*.$profileType";
die "ERROR - no files found" if ( !@files );

# Retrieve DSSP data from Jnet DB
my $dbh     = connect_DB('jnet-user');
my $accData = get_accDB($dbh);
die "ERROR - no accessibility data found" unless ( keys %$accData );
$dbh->disconnect;

print "\n---- Training Solvent Accessibility Network on $profileType at $cut% ----\n\n";

print "Writing out SNNS pattern file...\n";
my $fh = write_new( "$outPrefix$cut.pat", 'NNN', ( $numElements * ( 2 * $flank + 1 ) ), 2 );

## work out the size of the network and create it.
my $numUnits = $numElements * ( 2 * $flank + 1 );
print "Generating Neural Network...\n";
make_net( "$outPrefix${cut}_blank.net", $numUnits, $numHidden, 2 );

## create the SNNS batchfile
make_batch( "$outPrefix${cut}_blank.net", $outPrefix . $cut, $numIters, $randomWeights );

######################################################################################################################################################
# get pattern data
printf "Reading in %d files and extracting data...\n", scalar @files;
my $totPats = 0;
foreach my $dataf (@files) {

  my @pattern;
  my @dsspOut;

  my $root = basename( $dataf, ".$profileType" );
  my $extn = $profileType;

  die "ERROR - can't parse filename for \'$dataf\'" unless ($root);

  #print ">>$root\n";

  ## retrieve raw data
  my $data = get_data( $dataf, $extn );
  die "ERROR - no data found for $dataf" unless ( scalar @{$data} );

  ## for sequence in question convert absolute accessibility data to relative %
  ## Return false if nothing done.
  my $relAcc = acc2rel( $accData->{$root}{acc}, $accData->{$root}{seq} );
  die "ERROR - no accessibility data found for $root. Check that it exists in the database." if ( !$relAcc );
  die "ERROR - lengths of input and accessibility don't agree for $dataf" if ( scalar @$relAcc != scalar @$data );

  # collate pattern data for current structure and add to others
  $totPats += pattern_data( $data, \@pattern, 0, $flank );

  write_patterns_acc( $fh, \@pattern, $relAcc, $cut, $root );
}
close($fh);

# Horrible fudge to add the number of input patterns to the SNNS pattern file.
# Need to do it this way as we can't know beforehand how many there are.
system("perl -i -pe 's/NNN/$totPats/' $outPrefix$cut.pat") == 0 or die "ERROR - unable to edit $outPrefix$cut.pat";


######################################################################################################################################################
# edit skeleton C code for current network - found in DATA at bottom of script
open( my $OUT, ">$outPrefix${cut}net.c" ) or die "ERROR - $outPrefix${cut}net.c: $!";
while (<DATA>) {
  s/NN/$outPrefix$cut/g;
  print $OUT $_;
}
close($OUT);
close(DATA);

print "Training Network...\n";
train_net( $outPrefix . $cut );


######################################################################################################################################################
# Check that the final output directory is not the same as the working directory
# and tar up the data files and move to final location.
# If they are the same do nothing and exit.
if ( $finalDir ne $workDir ) {
  print "Moving files to $finalDir...\n";
  system("tar --exclude $outPrefix$cut.tar.gz -czf $outPrefix$cut.tar.gz $outPrefix$cut*") == 0 or die "ERROR - tar failed";
  system("mv -f $outPrefix$cut.tar.gz $finalDir/") == 0                                         or die "ERROR - failed to mv files";
  unlink <$outPrefix$cut*>;
}
print "Finished!\n";
exit;

=head1 SYNOPSIS

train_solacc.pl --type <network type> --cut <accessibility cutoff> --data <data dir> --dir <working dir> --out <dir> [--iters <int>] [--nhid <int>] [--help] [--man]

=head1 OPTIONS

=over 5

=item B<--type> <network type>

Define which network you want to train. Allowed options are: pssm or hmm

=item B<--cut> <accessibility cut-off>

Define the relative solvent accessibility cut-off to use during training.

=item B<--data> <path>

Provide the path to the source data for training.

=item B<--dir> <working dir>

Provide a path to the working directory.

Default: current directory

=item B<--out> <dir>

Define the output location for the training files.

Default: current directory

=item B<--iters> <num>

Set the number of iterations/cycles to run the training for.

Default: 300

=item B<--nhid> <num>

Set the number of hidden nodes to use the neural network for training.

Default: 9

=item B<--help>

Show brief help

=item B<--man>

Show the full documentation.

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
          *  Output result of prediction (either raw or 2-state)
          */
         if (raw) {
            printf("%4.2f %4.2f,", netOutput[0], netOutput[1]);
         } else {
            pred = '\0';
            if (netOutput[0] > netOutput[1]) {
               pred = '-';
            } else {
               pred = 'B';
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

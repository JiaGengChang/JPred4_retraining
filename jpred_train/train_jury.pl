#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

=head1 NAME

train_jury.pl -- script to train non-jury positions from JNet ensemble predictions

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

use lib '/cluster/gjb_lab/2472402/jpred_train/lib';
#use lib '/homes/www-jpred/jnet_train/lib';

use Jpred::jnetDB;
use Jpred::Utils;
use SNNS::Pattern;
use SNNS::Network;

#use SNNS::paths;

my $randomWeights = 0.1;      # range (+-) of random initial weights on network
my $numElements   = 9;
my $numHidden     = 9;
my $flank         = 8;
my $numIters      = 300;
my $outPrefix     = 'cons';
my $dPath;
my $verbose = 0;
my $help;
my $man;

GetOptions(
  'verbose' => \$verbose,
  'data=s'  => \$dPath,
  'iters=i' => \$numIters,
  'nhid=i'  => \$numHidden,
  'help|?'  => \$help,
  'man'     => \$man
) or pod2usage(0);

pod2usage( -verbose => 1 )                                    if ($help);
pod2usage( -verbose => 2 )                                    if ($man);
pod2usage( -msg     => "Please give path to training data." ) if ( !$dPath );

my $host = `hostname -s` or die "ERROR - hostname failed";
chomp($host);
print "Job running on: $host\n";

my @files = glob "$dPath/*.pssm";
die "ERROR - no data found at '$dPath'!\nDied" if ( !@files );

## Retrieve DSSP data from Jnet DB
my $dbh      = connect_DB('jnet-user');
my $dsspData = get_DSSP($dbh);
die "ERROR - no DSSP data found" unless ( keys %$dsspData );
$dbh->disconnect;

print "\n------- Training Jury Network based on Profile Networks ------\n\n";

print "Writing out SNNS pattern file...\n";
my $fh = write_new( "$outPrefix.pat", 'NNN', ( $numElements * ( 2 * $flank + 1 ) ) );

## work out the size of the network and create it.
my $numUnits = $numElements * ( 2 * $flank + 1 );
print "Generating Neural Network...\n";
make_net( "${outPrefix}_blank.net", $numUnits, $numHidden, 3 );

## create the SNNS batchfile
print "Generating SNNS Batch file..\n";
make_batch( "${outPrefix}_blank.net", $outPrefix, $numIters, $randomWeights );

## get pattern data
printf "Reading in %d files and extracting data...\n", scalar @files;
my $totPats = 0;
foreach my $file (@files) {

  my $root;
  if ( $file =~ /(\w+)\.\w+/ ) {
    $root = $1;
  } else {
    die "ERROR - unable to match filename: '$file'";
  }

  #print "Running $root...\n";

  my @dssp = split //, reduce_dssp( $dsspData->{$root}{dssp} );
  my @preds = get_predictions( $root, \@dssp );
  my @nonJury = find_nonjury( \@preds );
  $totPats += scalar @nonJury;
  $preds[ ( scalar @preds ) ] = [ split //, reduce_dssp( $dsspData->{$root}{dssp} ) ];

  my @keepDssp;
  foreach my $pos (@nonJury) {
    push @keepDssp, $dssp[$pos];
  }

  my @data = reformat(@preds);
  print_data(@preds) if $verbose;
  printf "Found %d non-Jury positions\n", scalar @nonJury if $verbose;

  #print "$_, " foreach @nonJury;
  #print "\n";

  my @pattern;
  jury_pattern_data( \@data, \@pattern, \@nonJury, $flank );

  write_patterns( $fh, \@pattern, \@keepDssp, $root );

}
## Horrible fudge to add the number of input patterns to the SNNS pattern file.
## Need to do it this way as we can't know beforehand how many there are.
system("perl -i -pe 's/NNN/$totPats/' $outPrefix.pat") == 0 or die "ERROR - unable to edit $outPrefix.pat";

## edit skeleton C code for current network - found in __DATA__ at bottom of script
open( my $OUT, ">${outPrefix}net.c" ) or die "ERROR - ${outPrefix}net.c: $!";
while (<DATA>) {
  s/NN/$outPrefix/g;
  print $OUT $_;
}
close($OUT);

print "Training Network...\n";
train_net($outPrefix);
exit;

##### FUNCTIONS ######

sub jury_pattern_data {

  my ( $inData, $inPattern, $pos, $flank ) = @_ or return;

  my $idx     = 0;
  my $patSize = scalar @{ $inData->[0] };

  foreach my $row ( @{$pos} ) {    # for each sequence element that doesn't have a jury (centroid of window)
    my $winStart = $row - $flank;    # define window start...
    my $winEnd   = $row + $flank;    # ...and end
    my $patCount = 0;                # counter for number of input patterns per window

    foreach my $winPos ( $winStart .. $winEnd ) {    # for each residue in the window
      for my $i ( 0 .. $patSize - 1 ) {              # for each amino acid value
        if ( $winPos < 0 ) {                         # pad start of sequence when trying to read before the start
          $inPattern->[$idx][$patCount] = 0;
        } elsif ( $winPos > $#$inData ) {            # pad end of sequence when trying read past the end
          $inPattern->[$idx][$patCount] = 0;
        } else {
          $inPattern->[$idx][$patCount] = $inData->[$winPos][$i];
        }
        ++$patCount;
      }
    }
    ++$idx;
  }
  return ($idx);
}

sub get_predictions {
  my ( $root, $dssp ) = @_;

  my @order = qw(alignblosum alignfreq pssma pssmb hmm);
  my %nets  = qw(alignfreq align alignblosum align freq freq pssma pssm pssmb pssm hmm hmmprof);

  my $length = scalar @$dssp;

  #print "DSSP: $length\n";
  my @data;
  my @align;
  my $i = 0;
  foreach my $type (@order) {

    #print "$type\n";
    my $pred;

    ## averaged networks
    if ( $type =~ /align|pssm/ ) {    ## use this to average both aligment and pssm-based networks

      #      if ($type =~ /align/) {  ## use this to average only the alignment-based networks
      create_pattern( "$dPath/$root.$nets{$type}", $type, $dssp, 2 );
      $pred = `./${type}2net -r -i ${root}_2.pat` or die "ERROR - unable to run prediction for $type";

      #rename("${root}.pat", 'align.pat');
      #rename("${root}_2.pat", 'align2.pat');
      chomp($pred);

      ## break up raw outputs per residue
      my @outUnits = split /\,/, $pred;

      #printf "$type: %d\n", scalar @outUnits;
      my $c = 0;

      #my $string;
      foreach my $elem (@outUnits) {
        my @raw = split /\s+/, $elem;
        die "ERROR - too many elements in prediction for position $c" if ( scalar @raw > 3 );

        #$string .= float2pred(\@raw);
        $align[$c][$_] += $raw[$_] foreach ( 0 .. 2 );
        ++$c;

      }

      #print "$type: $c\n";
      #printf "$type: %s\n", length($string);
      warn "Warning - lengths don't match for $type" if ( $length != scalar @align );

      #print "$string\n";
    } else {    ## normal networks
      create_pattern( "$dPath/$root.$nets{$type}", $type, $dssp, 2 );
      $pred = `./${type}2net -i ${root}_2.pat` or die "ERROR - unable to run prediction for $type";
      chomp($pred);

      #print "$pred\n";
      die "ERROR - lengths don't match for seq $i" if ( $length != length($pred) );

    }

    ## average predictions and output a three-state string of the averaged prediction
    if ( ( $type eq 'alignfreq' ) or ( $type eq 'pssmb' ) ) {    ## use this to average both aligment and pssm-based networks

      #      if (($type eq 'alignfreq')) {  ## use this to average only the alignment-based networks
      $pred = '';
      my $j = 0;
      foreach my $ref (@align) {
        $ref->[$_] /= 2 foreach ( 0 .. 2 );
        ## use this to output any ambiguous probabilities for averaged networks.
        if ( float2pred($ref) eq '?' ) {
          open( my $LOG, '>>unsure.log' ) or die "ERROR - unable to append to LOG";
          print $LOG "$_ " foreach (@$ref);
          print $LOG "@$dssp[$j]\n";
          $pred .= '-';
          close($LOG);
          next;
        }
        ++$j;
        $pred .= float2pred($ref);
      }

      #print "$pred\n";
      $data[$i] = [ split //, $pred ];
      ++$i;
    } elsif ( ( $type eq 'alignblosum' ) or ( $type eq 'pssma' ) ) {    ## use this to average both aligment and pssm-based networks

      #      } elsif (($type eq 'alignblosum')) {  ## use this to average only the alignment-based networks
      ## don't add any data to the array for these as they haven't been averaged yet.
      next;
    } else {
      $data[$i] = [ split //, $pred ];
      ++$i;
    }
  }

  #unlink("99_2.pat") or warn "$!";
  unlink(<$root*.pat>);
  return (@data);
}

sub map_jury {
  my ($elem) = @_ or return;

  my @data;
  if ( $elem eq 'H' ) {
    $data[0] = 0;
    $data[1] = 1;
    $data[2] = 0;
  } elsif ( $elem eq 'E' ) {
    $data[0] = 1;
    $data[1] = 0;
    $data[2] = 0;
  } elsif ( $elem eq '-' ) {
    $data[0] = 0;
    $data[1] = 0;
    $data[2] = 1;
  } else {
    die "ERROR - disallowed secondary structure character: \'$elem\'\n";
  }
  return (@data);
}

sub find_nonjury {

  my ($data) = @_;

  my @jury;
  my $limit    = 60;
  my $numPreds = scalar @$data;
  my $length   = scalar @{ $data->[0] };

  for ( my $i = 0 ; $i < $length ; ++$i ) {
    $data->[$numPreds][$i] = ' ';
    for ( my $j = 0 ; $j < $numPreds ; ++$j ) {
      if ( $data->[0][$i] ne $data->[$j][$i] ) {
        $data->[$numPreds][$i] = '*';
        push @jury, $i;    # put jury positions in array
        last;              # break out of inner loop when non-jury position is found
      }
    }
  }

  return (@jury);
}

#
##  Function to convert mulitple predictions into a single SNNS pattern
#
sub reformat {

  my (@data) = @_;

  my @new;
  my $length    = scalar @{ $data[0] };
  my $numInputs = scalar @data;
  foreach my $pos ( 0 .. $length - 1 ) {
    my $i = 0;
    my $j = 0;
    while ( $data[$i][$pos] ) {

      #print "$data[$d][$pos]";
      my @conv = map_jury( $data[$i][$pos] );
      foreach my $input (@conv) {
        $new[$pos][$j] = $input;
        ++$j;
      }
      ++$i;
      last if $i == $numInputs - 2;    # skip Jury and DSSP lines
    }

    #print ",";
  }

  #print "\n";
  return (@new);
}

sub print_data {

  my (@data) = @_;

  my $limit  = 60;
  my $length = scalar @{ $data[0] };
  my @items  = qw(align pssma pssmb hmm jury DSSP);
  while ( $length > 0 ) {
    foreach my $item ( 0 .. $#items ) {
      printf "%9s ", $items[$item];
      print join( "", splice( @{ $data[$item] }, 0, $limit ) );
      print "\n";
    }
    print "\n";
    $length -= $limit;
  }

}

=head1 SYNOPSIS

train_jury.pl --data <data path> --iters <no. iterations> --nhid <no. hidden nodes> [--verbose] [--help] [--man]

=head1 DESCRIPTION


=head1 OPTIONS

=over 8

=item B<--data> <data path>

Path to data.

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

package SNNS::Network;

our $VERSION = '0.5.1';

=head1 NAME 

SNNS::Network -- Module for the creation of SNNS networks

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Chris Cole <christian@cole.name>

=head1 COPYRIGHT

Copyright 2006, Chris Cole.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

use strict;
use warnings;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(make_net make_batch make_batch_valid train_net);

## given a filename, no. input nodes, no. hidden nodes and no. output nodes
## make_net() creates a 'blank' network file for SNNS with no initial weights
sub make_net ($$$$) {
  my ( $fname, $numInputNodes, $numHiddenNodes, $numOutputNodes ) = @_ or return;

  $numHiddenNodes = 0 if ( $numHiddenNodes < 1 );

  #my $numInputNodes = 408;
  #my $numHiddenNodes = 9;
  #my $numOutputNodes = 3;
  my $numUnits = $numInputNodes + $numHiddenNodes + $numOutputNodes;
  my $numConnections;
  if ( $numHiddenNodes == 0 ) {
    $numConnections = $numInputNodes + $numOutputNodes;
  } else {
    $numConnections = ( $numInputNodes * $numHiddenNodes ) + ( $numHiddenNodes * $numOutputNodes );
  }
  my $header       = "SNNS network definition file V1.4-3D\n";
  my $threeColLine = '-------|------|----------------------------------------------------------------------------------------------------------------';
  my $sevenColLine = '---------|----------|----|--------|-------|--------------|-------------';
  my $tenColLine   = '----|----------|----------|----------|----------|----|----------|----------|----------|-------';

  open( my $FH, ">$fname" ) or die "ERROR - unable to open network file $fname: $!";
  select($FH);
  print $header;
  printf "generated at %s\n\n", scalar localtime();
  print "network name : Jnet_net\n";
  print "source files : \n";
  printf "no. of units : %d\n",       $numUnits;
  printf "no. of connections : %d\n", $numConnections;
  print "no. of unit types : 0\n";
  print "no. of site types : 0\n\n\n";
  print "learning function : Std_Backpropagation\n";
  print "update function   : Topological_Order\n\n\n";

  print "unit default section :\n\n";
  print "act      | bias     | st | subnet | layer | act func     | out func\n";
  print "$sevenColLine\n";
  print " 0.00000 |  0.00000 | h  |      0 |     1 | Act_Logistic | Out_Identity\n";
  print "$sevenColLine\n\n\n";

  print "unit definition section :\n\n";
  print "no. | typeName | unitName | act      | bias     | st | position | act func | out func | sites\n";
  print "$tenColLine\n";

  my $rows = 20;
  my $cols;
  if ( $numInputNodes % 20 ) {
    $cols = int( $numInputNodes / 20 ) + 1;
  } else {
    $cols = $numInputNodes / 20;
  }
  my $num = 1;
  my @inputNodes;
  my @hiddenNodes;
  my @outputNodes;
  for my $row ( 1 .. $rows ) {
    for my $col ( 1 .. $cols ) {
      last if $num > $numInputNodes;
      push( @inputNodes, $num );
      printf "%3d |          | unit     |  0.00000 |  0.00000 | i  | %2d,%2d,%2d |||\n", $num, $row, $col, 0;
      ++$num;
    }
  }
  for my $col ( 1 .. $numHiddenNodes ) {
    push( @hiddenNodes, $num );
    printf "%3d |          | unit     |  0.00000 |  0.00000 | h  | %2d,%2d,%2d |||\n", $num, ( $rows + 3 ), $col, 0;
    ++$num;
  }
  for my $col ( 1 .. $numOutputNodes ) {
    push( @outputNodes, $num );
    printf "%3d |          | unit     |  0.00000 |  0.00000 | o  | %2d,%2d,%2d |||\n", $num, ( $rows + 6 ), $col, 0;
    ++$num;

  }
  print "$tenColLine\n\n\n";

  print "connection definition section :\n\n";
  print "target | site | source:weight\n";
  print "$threeColLine\n";
  if ($numHiddenNodes) {
    my $last = pop(@inputNodes);
    foreach my $hid (@hiddenNodes) {
      printf "   %3d |      |", $hid;
      foreach my $in (@inputNodes) {
        printf " %3d: %7.5f,", $in, 0;
      }
      printf " %3d: %7.5f\n", $last, 0;
    }
    $last = pop(@hiddenNodes);
    foreach my $out (@outputNodes) {
      printf "   %3d |      |", $out;
      foreach my $hid (@hiddenNodes) {
        printf " %3d: %7.5f,", $hid, 0;
      }
      printf " %3d: %7.5f\n", $last, 0;
    }
  } else {
    my $last = pop(@inputNodes);
    foreach my $hid (@outputNodes) {
      printf "   %3d |      |", $hid;
      foreach my $in (@inputNodes) {
        printf " %3d: %7.5f,", $in, 0;
      }
      printf " %3d: %7.5f\n", $last, 0;
    }
  }
  print "$threeColLine\n";
  select(STDOUT);
  close($FH);

}

## given an SNNS network file (from make_net()), a root name, no. of learning cycles and initial weights
## make_batch() creates an SNNS batch file for training.
sub make_batch ($$;$$) {
  my ( $inNet, $root, $cycles, $weights ) = @_ or return;

  $cycles  = 250   unless ($cycles);
  $weights = 0.005 unless ($weights);
  my $pattern   = $root . ".pat";
  my $outNet    = $root . ".net";
  my $batchFile = $root . ".bat";

  #my $seed = 405117185;
  my $seed = time();

  open( my $FH, ">$batchFile" ) or die "$batchFile: $!";

  print $FH <<"EOF";
loadNet("$inNet")
loadPattern("$pattern")

setSeed($seed)


setShuffle(TRUE)
setInitFunc("Randomize_Weights", $weights, -$weights)
setUpdateFunc("Topological_Order")
initNet()

setLearnFunc("SCG", 0.2, 0.0, 0.0, 0.0)
setPattern("$pattern")
for i := 1 to $cycles do
   trainNet()
#   if CYCLES == 300 then
#      saveNet("$outNet")
#   endif
   if CYCLES mod 10 == 0 or CYCLES < 10 then
      testNet()
      print("train: cycles = ", CYCLES, " SSE = ", SSE, " MSE = ", MSE)
   endif
#   if CYCLES mod 10 == 0 and CYCLES > 250 then
#      name := "$outNet" + "_" + CYCLES
#      saveNet(name)
#   endif
endfor
saveNet("$outNet")
EOF

  close($FH);
}

## as for make_batch(), but includes a validation step to test the current
## network against a separate test set to verify progress.
sub make_batch_valid ($$;$$) {
  my ( $inNet, $root, $cycles, $weights ) = @_ or return;

  $cycles  = 250   unless ($cycles);
  $weights = 0.005 unless ($weights);
  my $pattern   = $root . ".pat";
  my $outNet    = $root . ".net";
  my $batchFile = $root . ".bat";

  #my $seed = 405117185;
  my $seed = time();

  open( my $FH, ">$batchFile" ) or die "$batchFile: $!";

  print $FH <<"EOF";
loadNet("$inNet")
loadPattern("$pattern")
loadPattern("${root}_valid.pat")

setSeed($seed)


setShuffle(TRUE)
setInitFunc("Randomize_Weights", $weights, -$weights)
setUpdateFunc("Topological_Order")
initNet()

setLearnFunc("SCG", 0.2, 0.0, 0.0, 0.0)
setPattern("$pattern")
for i := 1 to $cycles do
   trainNet()
   if CYCLES mod 10 == 0 or CYCLES < 10 then
      print("train: cycles = ", CYCLES, " SSE = ", SSE, " MSE = ", MSE)
      setPattern("${root}_valid.pat") 
      testNet()
      print("valid: cycles = ", CYCLES, " SSE = ", SSE, " MSE = ", MSE)
      setPattern("$pattern")
   endif
endfor
saveNet("$outNet")
EOF

  close($FH);
}

sub train_net ($) {
  my ($root) = @_ or return;

  ### FIXME bad, bad. Hardcoded path.
  system("/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/batchman -f $root.bat") == 0 or die "ERROR - failed to run batchman";
  if ( -e "$root.net" ) {
    system("/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/snns2c $root.net") == 0 or die "ERROR - failed to run snns2c";
  } else {
    die "ERROR - '$root.net' network file not found. Check that batchman ran correctly.";
  }
  if ( -e "$root.c" ) {
    system("/usr/bin/gcc -c $root.c") == 0 or die "ERROR - failed to compile '$root.c'";
  } else {
    die "ERROR - '$root.c' network file not found. Check that snns2c ran correctly.";
  }
  ## ${root}net.c is created elsewhere. Check there first if any errors.
  if ( -e "${root}net.c" ) {
    system("/usr/bin/gcc -Wall -o ${root}net ${root}net.c $root.o -lm") == 0 or die "ERROR - failed to compile '${root}net.c'.";
  } else {
    die "ERROR - '${root}net.c' not found.";
  }
}

sub make_makefile ($) {
  my ($root) = @_ or return;

  open( my $fh, ">Makefile" ) or die "Makefile: $!";
  print $fh <<"EOF";
#
# Makefile to generate and test NN code
#


# CC specific options
CC = gcc
CLIBS = -lm
CFLAGS = -Wall

# SNNS specific options
#SNNSPATH = /homes/chris/NOBACK/exbin/SNNSv4.2/tools/bin/i686-pc-linux-gnu
SNNSPATH = /sw/bin
NN_NAME = $root

#######################################################################
# compile NN test code linking in the new NN
test_\$(NN_NAME): \$(NN_NAME).o test_\$(NN_NAME).c
\t\$(CC) \$(CFLAGS) -o test_\$(NN_NAME) test_\$(NN_NAME).c \$(NN_NAME).o \$(CLIBS)

test_\$(NN_NAME).c: test_template.c
\tperl -pe 's/NN/\$(NN_NAME)/g' test_template.c > test_\$(NN_NAME).c


# compile NN code
\$(NN_NAME).o: \$(NN_NAME).c
\t\$(CC) -c \$(NN_NAME).c

# train network and convert into C code
\$(NN_NAME).c: \$(NN_NAME).pat
\t\$(SNNSPATH)/batchman -f \$(NN_NAME).bat
\t\$(SNNSPATH)/snns2c \$(NN_NAME).net

clean:
\trm -f \$(NN_NAME).c \$(NN_NAME).h \$(NN_NAME).o
\trm -f test_\$(NN_NAME).* test_\$(NN_NAME)
EOF
  close($fh);
}

1;

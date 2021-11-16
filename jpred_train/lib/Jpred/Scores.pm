package Jpred::Scores;

our $VERSION = '0.1';

=head1 NAME 

Jpred::Scores - Scoring functions for Jpred predictions

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
use Exporter;

our @ISA       = qw(Exporter);
our @EXPORT    = qw(calc_q3 calc_acc);
our @EXPORT_OK = qw(score_jnet score_simple score_per_res);

sub calc_q3 ($$$) {
  my ( $dssp, $pred, $href ) = @_;

  my @dssp = split //, $dssp;
  my @pred = split //, $pred;

  ## check whether the prediction is the same length as the DSSP output.
  my $mismatch = 0;
  $mismatch = 1 if ( scalar @dssp != scalar @pred );

  my %tots;       # total no. of predictions for each state
  my %correct;    # total correct predictions for each state
  my $tot_correct = 0;    # total correct predictions for all states

  for ( my $i = 0 ; $i < scalar @dssp ; ++$i ) {
    next if !$pred[$i];
    $tots{ $pred[$i] }++;
    if ( $dssp[$i] eq $pred[$i] ) {
      $correct{ $pred[$i] }++;
      ++$tot_correct;
    }
  }

  foreach my $type ( sort keys %tots ) {
    if ( defined( $correct{$type} ) ) {
      $href->{$type} += 100 * $correct{$type} / $tots{$type};    # cum. total of accuracies for each type
    }
  }
  my $q3 = 100 * $tot_correct / ( scalar @pred );

  $href->{'3'}    += $q3;
  $href->{'corr'} += $tot_correct;
  $href->{'pred'} += scalar @pred;

  return ( $q3, $mismatch );
}

#
## function to calculate the solvent accessibility prediction score
#
sub calc_acc ($$$) {
  my ( $predStr, $relAcc, $cut ) = @_;

  #print "cut: $cut\n";
  #print "pred: $predStr\n";

  my @pred = split //, $predStr;
  my $length = scalar @pred;
  die "ERROR - lengths for the prediction and real don't agree" if ( $length != scalar @$relAcc );

  my %tots;       # total no. of predictions for each state
  my %correct;    # total correct predictions for each state
  my $tot_correct = 0;    # total corract predictions for all states

  for ( my $i = 0 ; $i < $length ; ++$i ) {
    my $real = 'B';
    if ( $relAcc->[$i] > $cut ) {
      $real = '-';
    }

    #print "t: $real p: $pred[$i]\n";

    $tots{ $pred[$i] }++;
    if ( $real eq $pred[$i] ) {
      $correct{ $pred[$i] }++;
      ++$tot_correct;
    }
  }

  my $q2 = 100 * $tot_correct / $length;

  #printf "tot: $tot_correct  %%: %.2f\n", $q2;

  return ($q2);
}

sub score_jnet {
  use Jpred::Utils;

  my ( $jnetPath, $dataFile, $predItem, $trueData ) = @_;

  ## make sure we've got the most up-to-date build of JNet
  system("make -C $jnetPath --silent clean") == 0 or die "ERROR - unable to make clean";
  system("make -C $jnetPath --silent 2>/dev/null");
  if ( -e "$jnetPath/jnet" ) {
    system("$jnetPath/jnet --concise --sequence $dataFile.align --hmmer $dataFile.hmmprof --psiprof $dataFile.pssm --psifreq $dataFile.freq > tmp.jnet 2>/dev/null") == 0
      or die "ERROR - unable to run JNet";
    die "Error - can't find JNet output 'tmp.jnet'\n" unless ( -e "tmp.jnet" );

    open( my $JNET, "tmp.jnet" ) or die "ERROR - can't open tmp.jnet: $!";
    my $pred = get_item( $JNET, $predItem );
    warn "\nWarning - prediction and real lengths don't match\n" if ( length($pred) != length($trueData) );
    my $q3 = q3_simple( $pred, $trueData );
    close($JNET);
    unlink('tmp.jnet');
  } else {
    die "ERROR - can't find jnet binary. Skipping JNet scoring.\n";
  }
}

sub score_simple ($$) {

  ## expects two strings of data of equal length
  my ( $pred, $dssp ) = @_;

  my @predArr = split //, $pred;
  my @dsspArr = split //, $dssp;

  die "ERROR - prediction data has zero length.\nDied" if ( !scalar @predArr );
  die "ERROR - true data has zero length.\nDied"       if ( !scalar @dsspArr );
  if ( scalar @predArr != scalar @dsspArr ) {
    my $predLen = scalar @predArr;
    my $dsspLen = scalar @dsspArr;
    die "ERROR - true ($dsspLen) and predicted ($predLen) data are not the same length.\nDied";
  }

  my $correct = 0;
  for my $i ( 0 .. $#predArr ) {
    warn "Warning - no data in true data array at pos $i. Are pred and true the same length?\n" if ( !defined( $dsspArr[$i] ) );
    ++$correct if ( $predArr[$i] eq $dsspArr[$i] );
  }

  my $score = 100 * $correct / scalar @predArr;
  return ($score);
}

sub score_per_res {
  my ( $pred, $true, $perRes ) = @_;

  my @predArr = split //, $pred;
  my @trueArr = split //, $true;

  die "ERROR - prediction data has zero length.\nDied" if ( !scalar @predArr );
  die "ERROR - true data has zero length.\nDied"       if ( !scalar @trueArr );
  if ( scalar @predArr != scalar @trueArr ) {
    my $predLen = scalar @predArr;
    my $trueLen = scalar @trueArr;
    die "ERROR - true ($trueLen) and predicted ($predLen) data are not the same length.\nDied";
  }

  my %correct;
  my %total;
  for my $i ( 0 .. $#predArr ) {
    warn "Warning - no data in true data array at pos $i. Are pred and true the same length?\n" if ( !defined( $trueArr[$i] ) );
    $total{ $trueArr[$i] }++;
    ++$correct{ $predArr[$i] } if ( $predArr[$i] eq $trueArr[$i] );
    ## spot N1 positions in 'true' data
    if ( $i > 0 && $trueArr[$i] eq 'H' && $trueArr[ $i - 1 ] eq '-' ) {
      ++$correct{N} if ( $predArr[$i] eq $trueArr[$i] && $predArr[ $i - 1 ] eq '-' );    ## find concurring N1 positions in prediction
      $total{N}++;
    }

  }

  ## per residue scoring
  foreach my $type ( keys %total ) {

    #if (defined($correct{$type})) {
    $perRes->{$type}{total}   += $total{$type};                                          # cum. total of secondary structure elements
    $perRes->{$type}{correct} += $correct{$type} if ( defined( $correct{$type} ) );      # cum. total of correctly predicted secondary structure elements
                                                                                         #}
  }

  ## per structure scoring
  my %score;
  foreach my $type ( keys %correct ) {

    #print "$type: $correct{$type}  $total{$type}\n";
    $score{$type} = 100 * $correct{$type} / $total{$type};
  }

  return (%score);

}

1;

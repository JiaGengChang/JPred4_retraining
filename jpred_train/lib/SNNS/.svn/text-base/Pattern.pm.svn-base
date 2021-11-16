package SNNS::Pattern;

our $VERSION = '0.1';

=head1 NAME 

SNNS::Pattern -- Module to create SNNS pattern files

=head1 SYNOPSIS


=head1 DESCRIPTION

All you need to create SNNS patterns ready for training for JNet.

=head1 AUTHOR

Chris Cole <christian@cole.name>

=head1 COPYRIGHT

Copyright 2006, Chris Cole.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

## TODO
## - deal with ambiguous positions in get_pred() and others
##   It will be solved automatically when looking at raw probabilities instead of predictions

use strict;
use warnings;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(write_new write_patterns write_patterns_acc create_pattern get_data get_psi_data pattern_data float2pred map_struct map_raw get_alignment);

#
# Take input data for a sequence and window the data over the flanking regions.
# The windowed data is put into array reference which can be reused to add more
# data from other sequences, hence why $idx is to and from the function.
#
sub pattern_data ($$$$) {

  my ( $inData, $inPattern, $idx, $flank ) = @_ or return;

  my $patSize = scalar @{ $inData->[0] };

  foreach my $row ( 0 .. $#$inData ) {    # for each sequence element (i.e. centroid of window)
    my $winStart = $row - $flank;         # define window start...
    my $winEnd   = $row + $flank;         # ...and end
    my $patCount = 0;                     # counter for number of input patterns per window

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

#
# print header part of pattern file and return filehandle for further writing to the file
#
sub write_new ($$$;$) {
  my ( $fname, $numPatterns, $numInputUnits, $numOutputUnits ) = @_ or return;

  $numOutputUnits = 3 unless ($numOutputUnits);

  open( my $FH, ">$fname" ) or die "ERROR - unable to open '$fname' for write: $!";
  print $FH "SNNS pattern definition file V3.2\n";
  printf $FH "generated at %s\n\n", scalar localtime();

  printf $FH "No. of patterns : %s\n",       $numPatterns;
  printf $FH "No. of input units : %d\n",    $numInputUnits;
  printf $FH "No. of output units : %d\n\n", $numOutputUnits;
  return ($FH);

}

#
# write out patterns to the pattern file
#
sub write_patterns ($$$;$) {
  my ( $fh, $pattern, $dssp, $root ) = @_ or return;

  $root = 'pat' unless ($root);

  foreach my $pat ( 0 .. $#$pattern ) {
    print $fh "# Input ${root}_$pat:\n";
    foreach my $data ( @{ $pattern->[$pat] } ) {
      print $fh "$data ";
    }
    print $fh "\n# Output ${root}_$pat:\n";
    if ( $dssp->[$pat] eq 'H' ) {
      print $fh "0 1 0";
    } elsif ( $dssp->[$pat] eq 'E' ) {
      print $fh "1 0 0";
    } elsif ( $dssp->[$pat] eq '-' ) {
      print $fh "0 0 1";
    } else {
      ++$pat;
      die "ERROR - disallowed dssp character: \'$dssp->[$pat]\' at position $pat\n";
    }
    print $fh "\n";
  }
  return (1);
}

sub write_patterns_acc ($$$$;$) {
  my ( $fh, $pattern, $acc, $cut, $root ) = @_ or return;

  $root = 'acc' unless ($root);

  foreach my $pat ( 0 .. $#$pattern ) {
    print $fh "# Input ${root}_$pat:\n";
    foreach my $data ( @{ $pattern->[$pat] } ) {
      print $fh "$data ";
    }
    print $fh "\n# ACC_Output ${root}_$pat:\n";
    if ( $acc->[$pat] > $cut ) {

      #print "-\n";
      print $fh "1 0\n";
    } else {
      print $fh "0 1\n";

      #print "B\n";
    }
  }
}

#
## function to take raw probabilities for an individual position and return
## its 3-state prediction. Deals with ambiguous probabilities.
#
sub float2pred {

  my ($floats) = @_;

  die "ERROR - nothing passed to function" unless ($floats);
  die "ERROR - wrong number of outputs in predicition" if ( scalar @$floats != 3 );

  if ( ( $floats->[0] > $floats->[1] ) && ( $floats->[0] > $floats->[2] ) ) {
    return ('E');
  } elsif ( ( $floats->[1] > $floats->[0] ) && ( $floats->[1] > $floats->[2] ) ) {
    return ('H');
  } elsif ( ( $floats->[2] > $floats->[1] ) && ( $floats->[2] > $floats->[0] ) ) {
    return ('-');
  } else {

    # sometimes ambiguous positions occur (esp. on averaged nets)
    # Here empirically derived (from CB1031) outputs are defined for these positions
    if ( $floats->[0] == $floats->[1] && $floats->[0] != $floats->[2] ) {
      return ('E');
    } else {
      return ('-');
    }

    #      return('?');  # use this to output ambiguous positions
  }
}

#
# function create pattern data from a string of 3-state secondary structure data
# be it prediction or from another source.
# Plus, if a conservation score array is passed to it add that to the ouptut data.
#
sub map_struct ($;$) {
  my ( $string, $cons ) = @_ or return;

  my @data;
  my @string = split //, $string;
  my $c = 0;

  foreach my $elem (@string) {
    if ( $elem eq 'H' ) {
      $data[$c][0] = 0;
      $data[$c][1] = 1;
      $data[$c][2] = 0;
    } elsif ( $elem eq 'E' ) {
      $data[$c][0] = 1;
      $data[$c][1] = 0;
      $data[$c][2] = 0;
    } elsif ( $elem eq '-' ) {
      $data[$c][0] = 0;
      $data[$c][1] = 0;
      $data[$c][2] = 1;
    } elsif ( $elem eq '?' ) {    ## fudge to avoid dealing with ambiguous positions
      $data[$c][0] = $data[ $c - 1 ][0];
      $data[$c][1] = $data[ $c - 1 ][0];
      $data[$c][2] = $data[ $c - 1 ][0];
    } else {
      ++$c;
      die "ERROR - disallowed secondary structure character: \'$elem\' at position $c\n";
    }
    ## add Conservation Score if given
    if ( ($cons) && ( scalar @$cons ) ) {
      $data[$c][3] = $cons->[$c];
    }
    ++$c;
  }
  return ( \@data );
}

#
## function to prepare data from raw predictions
#
sub map_raw ($;$) {
  my ( $string, $cons ) = @_ or return;

  my @data;
  my @string = split /\,/, $string;
  my $c = 0;

  foreach my $elem (@string) {
    my @raw = split /\s+/, $elem;
    die "ERROR - too many elements in prediction for position $c" if ( scalar @raw > 3 );
    foreach my $i ( 0 .. 2 ) {
      $data[$c][$i] = $raw[$i];
    }
    ## add Conservation Score if given
    if ( ($cons) && ( scalar @$cons ) ) {
      $data[$c][3] = $cons->[$c];
    }
    ++$c;
  }
  return ( \@data );
}

#
## function to create pattern files for individual input files.
#
sub create_pattern ($$$;$) {
  use Jpred::Utils;
  #use SNNS::paths;

  ## $file is the name (and path) for input data. Function works out from the filename how to deal with the data
  ## $subType is either 0 or 1
  ## $layer is either 1 or 2
  ## $dssp is a ref to an array of DSSP outputs for a structure
  my ( $file, $type, $dssp, $layer ) = @_ or return;

  $layer = 1 unless ($layer);
  my $flank = 8;

  my $root;
  if ( $file =~ /(\w+)\.\w+$/ ) {
    $root = $1;
  } else {
    die "ERROR - unable to match filename: '$file'";
  }

  my $data;
  my @consScore;
  if ( $type =~ /align/ ) {
    ## parse the PSI-BLAST alignment and create a 2D array with the
    ## sequence number as the 1st dimension and the residues as the
    ## 2nd dimension.
    my $align = get_alignment($file);

    ## calculate the Conservation Score from the alignment as per Zvelebil et al, JMB (1987) 195, 957-961
    @consScore = calc_cons($align);

    ## generate the data from the alignment and Conservation Score
    ## THe final argument defines whether it's a Frequency profile or BLOSUM (1=Freq, 0 = BLOSUM)
    $data = get_psi_data( $align, \@consScore, 0 ) if ( $type =~ /blosum/ );
    $data = get_psi_data( $align, \@consScore, 1 ) if ( $type =~ /freq/ );
  } elsif ( $type =~ /psisol/ ) {
    ## special case for pssm-based solvent accessibility networks
    $data = get_data( $file, 'pssm' );
  } else {
    ## retrieve the profile data from the input fileand return as
    ## reference to an AoA
    $data = get_data( $file, $type );
  }

  ## prepare pattern data...
  my @inPat;
  pattern_data( $data, \@inPat, 0, $flank );

  ## ...and write out to file.
  my $fh = write_new( "$root.pat", scalar @inPat, scalar @{ $inPat[0] } );
  write_patterns( $fh, \@inPat, $dssp );
  close($fh);

  return if ( $layer == 1 );

  #################
  #### LAYER 2 ####
  #################

  ## make 1st layer prediction
  my $pred = `./${type}1net -i $root.pat` or die "ERROR - unable to run prediction for $type";
  chomp($pred);

  ## convert prediction from 3-state letters to 3-state NN inputs ('H' -> 0 1 0, 'E' -> 1 0 0, '-' -> 0 0 1)
  my $predData;
  if ( $type =~ /align/ ) {

    #if (length($pred) != scalar @consScore) {
    #   die "ERROR - length of the alignment is not the same as the prediction";
    #}
    #$predData = map_raw($pred, \@consScore);
    $predData = map_struct( $pred, \@consScore );
  } else {

    #$predData = map_raw($pred);   # attempt to use the raw outputs
    $predData = map_struct($pred);
  }

  if ( scalar @$predData != scalar @$dssp ) {
    die "ERROR - length of DSSP is not the same as the prediction";
  }
  ## collate input and output data and return patterns for each ready to write to file
  @inPat = ();
  $flank = 9;
  pattern_data( $predData, \@inPat, 0, $flank );

  ## write out the pattern file
  $fh = write_new( "${root}_2.pat", scalar @inPat, ( scalar @{ $inPat[0] } ) );
  write_patterns( $fh, \@inPat, $dssp );
  close($fh);

}

sub get_alignment ($) {
  my ($file) = @_;

  open( my $fh, $file ) or die "ERROR - '$file': $!";

  my $seq       = '';
  my $protCount = 0;
  my @prots     = ();
  my $i         = 0;

  while (<$fh>) {
    if (/^>/) {
      if ($protCount) {
        $prots[$i] = [ split //, $seq ];
        $seq = '';
        ++$i;
      }
      ++$protCount;
      next;
    } else {
      chomp;
      $seq .= $_;
    }
  }
  close($fh) or die "ERROR - can't close file '$file': $!";
  if ($seq) {
    $prots[$i] = [ split //, $seq ];
  }
  return ( \@prots );

}

#
# for the PSI-BLAST alignment data generate the frequency or BLOSUM data as required.
#
sub get_psi_data ($$$) {
  my ( $data, $cons, $type ) = @_ or return;

  if ( $type == 1 ) {
    return ( get_psi_freq( $data, $cons ) );
  } else {
    return ( get_psi_blosum( $data, $cons ) );
  }
}

#
# choose the correct function to deal with the input data and return an array ref to the data
#
sub get_data ($$) {
  my ( $file, $type ) = @_ or return;

  if ( $type =~ /pssm/ ) {
    return ( get_pssm($file) );
  } elsif ( $type =~ /freq/ ) {
    return ( get_freq($file) );
  } elsif ( $type =~ /hmm/ ) {
    return ( get_hmm($file) );
  } else {
    die "ERROR - unrecognised file type '$type'";
  }
}

sub get_pssm ($) {

  my ($pssmf) = @_;

  open( my $FH, $pssmf ) or die "ERROR - can't open '$pssmf': $!";

  my @pssmData;    # array of pssm data
  my $pssmLength = 0;    # number of pssm data points - same as length of protein

  while (<$FH>) {
    my @F = split;
    die "ERROR - wrong number of fields in PSSM file" if ( @F != 20 );    # there must be 20 values in each line of the matrix
    foreach my $i ( 0 .. $#F ) {
      $pssmData[$pssmLength][$i] = $F[$i];
    }
    ++$pssmLength;
  }
  close($FH) or warn "Warning - unable to close '$pssmf': $!";
  if (@pssmData) {
    return ( \@pssmData );
  } else {
    die "ERROR - no data extracted from '$pssmf'";
  }
}

sub get_freq ($) {

  my ($freqf) = @_;

  open( my $fh, $freqf ) or die "can't open $freqf: $!";

  my @freqData;
  my $freqLength = 0;
  my $freqTot    = 0;

  while (<$fh>) {
    my @F = split;
    die "ERROR - wrong number of fields in FREQ file" if ( @F != 20 );    # there must be 20 values in each line of the matrix

    $freqTot += $_ foreach @F;                                            # total of amino acid frequencies

    # extract freq data and normalise over total amino acids present
    foreach my $i ( 0 .. $#F ) {
      if ( $F[$i] eq '0' ) {
        $freqData[$freqLength][$i] = 0;
      } else {
        $freqData[$freqLength][$i] = sprintf "%.4f", $F[$i] / $freqTot;
      }
    }
    ++$freqLength;
  }
  close($fh);
  return ( \@freqData );
}

sub get_hmm ($) {

  my ($hmmf) = @_;

  open( my $FH, $hmmf ) or die "can't open $hmmf: $!";

  my @hmmData;    # array of hmm data
  my $hmmLength = 0;    # number of hmm data points - same as length of protein

  while (<$FH>) {
    my @F = split;
    die "ERROR - wrong number of fields in HMM file" if ( @F != 24 );    # there must be 20 values in each line of the matrix
    foreach my $i ( 0 .. $#F ) {
      $hmmData[$hmmLength][$i] = $F[$i];
    }
    ++$hmmLength;
  }
  close($FH);
  if (@hmmData) {
    return ( \@hmmData );
  } else {
    die "ERROR - no data extracted from \'$hmmf\'";
  }

}

my %res2int = (
  A   => 0,
  R   => 1,
  N   => 2,
  D   => 3,
  C   => 4,
  Q   => 5,
  E   => 6,
  G   => 7,
  H   => 8,
  I   => 9,
  L   => 10,
  K   => 11,
  M   => 12,
  F   => 13,
  P   => 14,
  S   => 15,
  T   => 16,
  W   => 17,
  Y   => 18,
  V   => 19,
  B   => 20,    # Asx
  Z   => 21,    # Glx
  X   => 22,    # Unk
  '-' => 23,
  '.' => 23,
);

sub get_psi_freq ($$) {

  my ( $align, $cons ) = @_ or return;

  my @psiFreqData;
  my $seqLength = scalar @{ $align->[0] };
  my $numSeqs   = scalar @{$align};

  ## go down each column in the alignment...
  foreach my $col ( 0 .. $seqLength - 1 ) {
    my %resCount;
    ## ..count how many of each residue there are...
    foreach my $seqNum ( 0 .. $numSeqs - 1 ) {
      die "ERROR - unrecognised residue \'$align->[$seqNum][$col]\' at position $col" if ( !defined( $res2int{ $align->[$seqNum][$col] } ) );
      my $resID = $res2int{ $align->[$seqNum][$col] };
      $resCount{$resID}++;

      #print "$align->[$seqNum][$col]";
    }

    #print "\n";
    ## ...and then assign the percent frequency of each possible residue into a 2D array
    foreach my $resID ( 0 .. 23 ) {
      if ( $resCount{$resID} ) {
        my $pcFreq = int( ( ( $resCount{$resID} / $numSeqs ) * 100 ) + 0.5 );    # round up and cast to int
                                                                                 #print "$resID: $resCount{$resID} $pcFreq\n";
        $psiFreqData[$col][$resID] = $pcFreq;
      } else {
        $psiFreqData[$col][$resID] = 0;
      }

      #print "$psiFreqData[$col][$resID] ";
    }
    ## add Conservation Score to end of array.
    $psiFreqData[$col][24] = $cons->[$col];

    #print "\n";
  }

  #print "\n";
  if (@psiFreqData) {
    return ( \@psiFreqData );
  } else {
    die "ERROR - no data for PSI-BLAST alignment frequencies";
  }
}

sub get_psi_blosum ($$) {

  my @blosum = (

    #     A  R  N  D  C  Q  E  G  H  I  L  K  M  F  P  S  T  W  Y  V  B  Z  X  *
    [qw( 4 -1 -2 -2  0 -1 -1  0 -2 -1 -1 -1 -1 -2 -1  1  0 -3 -2  0 -2 -1 -1 -4)],    # A
    [qw(-1  5  0 -2 -3  1  0 -2  0 -3 -2  2 -1 -3 -2 -1 -1 -3 -2 -3 -1  0 -1 -4)],    # R
    [qw(-2  0  6  1 -3  0  0  0  1 -3 -3  0 -2 -3 -2  1  0 -4 -2 -3  3  0 -1 -4)],    # N
    [qw(-2 -2  1  6 -3  0  2 -1 -1 -3 -4 -1 -3 -3 -1  0 -1 -4 -3 -3  4  1 -1 -4)],    # D
    [qw( 0 -3 -3 -3  9 -3 -4 -3 -3 -1 -1 -3 -1 -2 -3 -1 -1 -2 -2 -1 -3 -3 -1 -4)],    # C
    [qw(-1  1  0  0 -3  5  2 -2  0 -3 -2  1  0 -3 -1  0 -1 -2 -1 -2  0  3 -1 -4)],    # Q
    [qw(-1  0  0  2 -4  2  5 -2  0 -3 -3  1 -2 -3 -1  0 -1 -3 -2 -2  1  4 -1 -4)],    # E
    [qw( 0 -2  0 -1 -3 -2 -2  6 -2 -4 -4 -2 -3 -3 -2  0 -2 -2 -3 -3 -1 -2 -1 -4)],    # G
    [qw(-2  0  1 -1 -3  0  0 -2  8 -3 -3 -1 -2 -1 -2 -1 -2 -2  2 -3  0  0 -1 -4)],    # H
    [qw(-1 -3 -3 -3 -1 -3 -3 -4 -3  4  2 -3  1  0 -3 -2 -1 -3 -1  3 -3 -3 -1 -4)],    # I
    [qw(-1 -2 -3 -4 -1 -2 -3 -4 -3  2  4 -2  2  0 -3 -2 -1 -2 -1  1 -4 -3 -1 -4)],    # L
    [qw(-1  2  0 -1 -3  1  1 -2 -1 -3 -2  5 -1 -3 -1  0 -1 -3 -2 -2  0  1 -1 -4)],    # K
    [qw(-1 -1 -2 -3 -1  0 -2 -3 -2  1  2 -1  5  0 -2 -1 -1 -1 -1  1 -3 -1 -1 -4)],    # M
    [qw(-2 -3 -3 -3 -2 -3 -3 -3 -1  0  0 -3  0  6 -4 -2 -2  1  3 -1 -3 -3 -1 -4)],    # F
    [qw(-1 -2 -2 -1 -3 -1 -1 -2 -2 -3 -3 -1 -2 -4  7 -1 -1 -4 -3 -2 -2 -1 -1 -4)],    # P
    [qw( 1 -1  1  0 -1  0  0  0 -1 -2 -2  0 -1 -2 -1  4  1 -3 -2 -2  0  0 -1 -4)],    # S
    [qw( 0 -1  0 -1 -1 -1 -1 -2 -2 -1 -1 -1 -1 -2 -1  1  5 -2 -2  0 -1 -1 -1 -4)],    # T
    [qw(-3 -3 -4 -4 -2 -2 -3 -2 -2 -3 -2 -3 -1  1 -4 -3 -2 11  2 -3 -4 -3 -1 -4)],    # W
    [qw(-2 -2 -2 -3 -2 -1 -2 -3  2 -1 -1 -2 -1  3 -3 -2 -2  2  7 -1 -3 -2 -1 -4)],    # Y
    [qw( 0 -3 -3 -3 -1 -2 -2 -3 -3  3  1 -2  1 -1 -2 -2  0 -3 -1  4 -3 -2 -1 -4)],    # V
    [qw(-2 -1  3  4 -3  0  1 -1  0 -3 -4  0 -3 -3 -2  0 -1 -4 -3 -3  4  1 -1 -4)],    # B
    [qw(-1  0  0  1 -3  3  4 -2  0 -3 -3  1 -1 -3 -1  0 -1 -3 -2 -2  1  4 -1 -4)],    # Z
    [qw(-1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -4)],    # X
    [qw(-4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4  1)],    # *
  );

  my ( $align, $cons ) = @_ or return;

  my @psiBlosumData;
  my $seqLength = scalar @{ $align->[0] };
  my $numSeqs   = scalar @{$align};

  ## go down each column in the alignment...
  foreach my $col ( 0 .. $seqLength - 1 ) {
    foreach my $resID ( 0 .. 23 ) {
      foreach my $seq ( 0 .. $numSeqs - 1 ) {
        $psiBlosumData[$col][$resID] += $blosum[ $res2int{ $align->[$seq][$col] } ][$resID];
      }
      $psiBlosumData[$col][$resID] = sprintf "%.4f", $psiBlosumData[$col][$resID] / $numSeqs;

      #printf "%4.1f ", $psiBlosumData[$col][$resID];
    }
    ## add Conservation Score to end of array.
    $psiBlosumData[$col][24] = $cons->[$col];

    #print ">$cons->[$col]<\n";
  }

  #print "\n";
  #exit;
  if (@psiBlosumData) {
    return ( \@psiBlosumData );
  } else {
    die "ERROR - no data for PSI-BLAST alignment BLOSUM scores";
  }

}

1;

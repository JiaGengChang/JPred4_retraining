package Jpred::Utils;

our $VERSION = '0.4';

=head1 NAME 

Jpred::Utils - Useful and commonly used functions for Jpred.

=head1 SYNOPSIS

use Jpred::Utils;

$string = reduce_dssp($string);

$data = get_item($fh, $item);

=head1 DESCRIPTION

The 'Jpred::Utils' contains (or at least will contain) a collection of useful and frequently used functions for working with Jpred and Jpred data.

Current functions are:

=over 6

=item reduce_dssp()

Pass reduce_dssp() a string consisting of a full DSSP assignment for a protein and the function will reduce it down to the 3-state model used in JNet.

=item get_item()

The get_item() function is used to extract data from a JNet output file. Each prediction is the Jnet output is labelled and you can use the label to extract the data from the file. e.g.:

 open ($fh, 'file.jnet') or die "$!";
 $label = 'jnetpred';   # secondary structure prediction
 $pred = get_item($fh, $label);

=item calc_cons()

Calculate the conservation score for each position in a multiple sequence alignment.

The function takes a reference to a 2D array of multiple sequences and returns a same-sized array with a conservation score for each position in the alignment.
 
 @multiSeqs = get_multiple_sequence_alignment();
 my @scores = calc_cons(\@multiSeqs);

=back

=head1 AUTHOR

Chris Cole <christian@cole.name>

=head1 COPYRIGHT

Copyright 2006, Chris Cole.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(reduce_dssp get_item calc_cons acc2rel);

##################################################################################################################################
# function takes a DSSP string and reduce to 3-state output
# optionally, set the hard flag to use the harder helix criteria
# Returns: the parsed string or 0 on failure.
#
sub reduce_dssp ($;$) {
  my ( $sec_string, $hard ) = @_ or return (0);

  $hard = 0 unless defined($hard);
  if ($hard) {
    $sec_string =~ tr/ST_bC? /-/;    # convert all known non-sheet or helix structures to coil
    $sec_string =~ tr/GI/H/;         # assign 3/10 helix (G) and pi helix (I) as helix  (harder to predict rather than only using 'H')
    $sec_string =~ tr/B/E/;          # convert 'B' forms to 'E'
    $sec_string =~ tr/EH/-/c;        # convert everything not 'H' or 'E' to coil (back-up for first step)
  } else {
    $sec_string =~ tr/ST_bGIC? /-/;    # convert all known non-sheet or helix structures to coil
    $sec_string =~ tr/B/E/;            # convert 'B' forms to 'E'
    $sec_string =~ tr/EH/-/c;          # convert everything not 'H' or 'E' to coil (back-up for first step)
  }
  return $sec_string;
}

##################################################################################################################################
# generic function to extract required data from a Jnet output file
#
sub get_item ($$) {
  my ( $fh, $item ) = @_;

  seek( $fh, 0, 0 );                   # rewind to start of file at each call.

  while (<$fh>) {
    chomp;
    my ( $id, $data ) = split /:/, $_;
    next unless $id;
    if ( $id =~ /$item/i ) {
      $data =~ s/\,//g;
      return ($data);
    }
  }
}

##################################################################################################################################
# function which takes a multiple sequence alignment and calculates
# the conservation score for each residue position
#
sub calc_cons {
  my ($seqAlign) = @_ or return;    # pass a ref. to a 2D array of sequences

  my $totSeqs = scalar @{$seqAlign};
  my $aa      = 0;
  my $seqNum  = 0;
  my @score;
  while ( $seqAlign->[$seqNum][$aa] ) {
    my %pos;

    while ( $seqNum < $totSeqs ) {
      $pos{ $seqAlign->[$seqNum][$aa] }++;    # compress column of aligned seqs to unique aas
                                              #print "$seqAlign->[$seqNum][$aa]";
      ++$seqNum;
    }
    if ( keys %pos == 1 ) {                   # if residue is fully conserved score = 1
      $score[$aa] = 1;
    } else {                                  # if residue not fully conserved calculate score
      $score[$aa] = cons(%pos);
    }

    #print " $score[$aa]\n";
    ++$aa;
    $seqNum = 0;
  }
  return (@score);
}

##################################################################################################################################
# function to calculate the conservation number for each column of residues
# in a multiple sequence alignment. The value is calculated as per
# Zvelebil et al., JMB (!987) 195, 957-961
#
#    C(i) = 0.9 - 0.1 x P
#
#  where: C(i) is the conservation number
#         P    is the change in chemical property value
#
#  a C(i) score of 1 is for fully conserved positions and a score of
#  0 - 0.9 is for varying degrees of non-conservation
#
sub cons {
  my (%residues) = @_ or return;

  ### amino acid properties matrix ###
  my %aaProps = (

    # hydrophobic, +ve, -ve, polar, charged, small, tiny, aliphatic, aromatic, proline
    I   => [ 1, 0, 0, 0, 0, 0, 0, 1, 0, 0 ],
    L   => [ 1, 0, 0, 0, 0, 0, 0, 1, 0, 0 ],
    V   => [ 1, 0, 0, 0, 0, 1, 0, 1, 0, 0 ],
    C   => [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0 ],
    A   => [ 1, 0, 0, 0, 0, 1, 1, 0, 0, 0 ],
    G   => [ 1, 0, 0, 0, 0, 1, 1, 0, 0, 0 ],
    M   => [ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
    F   => [ 1, 0, 0, 0, 0, 0, 0, 0, 1, 0 ],
    Y   => [ 1, 0, 0, 1, 0, 0, 0, 0, 1, 0 ],
    W   => [ 1, 0, 0, 1, 0, 0, 0, 0, 1, 0 ],
    H   => [ 1, 1, 0, 1, 1, 0, 0, 0, 1, 0 ],
    K   => [ 1, 1, 0, 1, 1, 0, 0, 0, 0, 0 ],
    R   => [ 0, 1, 0, 1, 1, 0, 0, 0, 0, 0 ],
    E   => [ 0, 0, 1, 1, 1, 0, 0, 0, 0, 0 ],
    Q   => [ 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 ],
    D   => [ 0, 0, 1, 1, 1, 1, 0, 0, 0, 0 ],
    N   => [ 0, 0, 0, 1, 0, 1, 0, 0, 0, 0 ],
    S   => [ 0, 0, 0, 1, 0, 1, 1, 0, 0, 0 ],
    T   => [ 1, 0, 0, 1, 0, 1, 0, 0, 0, 0 ],
    P   => [ 0, 0, 0, 0, 0, 1, 0, 0, 0, 1 ],
    B   => [ 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 ],    # Asx
    Z   => [ 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 ],    # Glx
    '-' => [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ],
    '.' => [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ],
    X   => [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ],
  );

  my $cons = 0;
  my $P    = 0;
  for my $prop ( 0 .. 9 ) {
    my $val;
    foreach my $aa ( keys %residues ) {
      if ( !defined( $aaProps{$aa} ) ) {
        warn "Warning - $aa residue is not recognised. Setting to \'X\'\n";
        $aa = 'X';
      }
      if ( defined($val) && $val != $aaProps{$aa}[$prop] ) {
        ++$P;
        last;
      }
      $val = $aaProps{$aa}[$prop];
    }
  }

  #print "($P) ";   # print the number of different props (max. is 10)
  return ($cons) if ( $P == 10 );
  $cons = 0.9 - ( 0.1 * $P );
  if ( $cons < 0 ) {
    print "ERROR - conservation number is $cons";
  }
  return ($cons);
}

##################################################################################################################################
#
# Function to convert absolute solvent accessibilities to % relative
#
sub acc2rel ($$) {
  my ( $rawCSV, $seqString ) = @_;

  ## reference solvent accessibilities for all residues
  ## Taken from Rose, GD and Dworkin, JE `Hydrophobicity Profile', In:
  ## *Prediction of Protein Structure and the Principles of Protein
  ## Conformation*, Fasman, GD editor, Plenum press (1989). Page 629
  my %ref_aa = (
    'A' => 118,
    'C' => 146,
    'D' => 158,
    'E' => 186,
    'F' => 222,
    'G' => 88,
    'H' => 203,
    'I' => 181,
    'K' => 226,
    'L' => 193,
    'M' => 203,
    'N' => 166,
    'P' => 147,
    'Q' => 193,
    'R' => 256,
    'S' => 130,
    'T' => 153,
    'V' => 165,
    'W' => 266,
    'Y' => 237,
    'X' => 150,    # guesswork - based upon that it must be something approaching the mean for a residue
  );

  my @pcAcc;
  my @rawAcc = split /\,/, $rawCSV;
  my @seq    = split //,   $seqString;
  my $length = scalar @rawAcc;

  for ( my $i = 0 ; $i < $length ; ++$i ) {
    die "ERROR - unknown residue '$seq[$i]'\n" if ( !$ref_aa{ $seq[$i] } );
    $pcAcc[$i] = sprintf( "%.2f", 100 * ( $rawAcc[$i] / $ref_aa{ $seq[$i] } ) );
    my $tmp = $i + 1;
  }
  return ( \@pcAcc );
}

1;

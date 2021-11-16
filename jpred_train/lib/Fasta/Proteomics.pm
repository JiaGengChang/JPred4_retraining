package Fasta::Proteomics;

our $VERSION = '0.1';

=head1 NAME 

Fasta::Proteomics - A collection of proteomics tools based on protein sequences

=head1 SYNOPSIS

use Fasta::Proteomics;

=head1 DESCRIPTION

This modules a variety of functions that can be used as when required: cleave()...

cleave(sequence, array_ref) - 
Cleave a protein sequence (based on Trypsin cleavage patterns) and populate the 
supplied array_ref with the mass and sequence for each peptide generated.
Returns the number of peptides.

=head1 USAGE


=head1 AUTHOR

Chris Cole <christian@cole.name>.

Copyright 2005, Chris Cole.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(cleave);

my %s2m = (
  A => 71.0371,
  C => 103.0092,
  D => 115.0269,
  E => 129.0426,
  F => 147.0684,
  G => 57.0215,
  H => 137.0589,
  I => 113.0841,
  K => 128.0950,
  L => 113.0841,
  M => 131.0405,
  N => 114.0429,
  P => 97.0528,
  Q => 128.0586,
  R => 156.1011,
  S => 87.0320,
  T => 101.0477,
  V => 99.0684,
  W => 186.0793,
  Y => 163.0633,
  X => 0.0
);

sub cleave {

  my ( $seq, $aref ) = @_ or return;

  $seq =~ tr/[a-z]/[A-Z]/;
  $seq .= '*' unless $seq =~ /\*/;
  my @codes = split( //, $seq );

  my $size = @codes;
  my $pep;
  my $pepmass = 0;
  my $n_peps  = 0;

  for ( my $i = 0 ; $i < $size ; ++$i ) {
    if ( $codes[$i] eq "*" ) {
      $aref->[$n_peps][0] = $pepmass;
      $aref->[$n_peps][1] = $pep;
      ++$n_peps;

      #print "   $pepmass\n";
    } elsif ( ( $codes[$i] =~ /K|R/ ) && ( $codes[ $i + 1 ] !~ /P/ ) ) {
      $pepmass += $s2m{ $codes[$i] };
      $pepmass += 18.0106;
      $pep .= $codes[$i];

      $aref->[$n_peps][0] = $pepmass;
      $aref->[$n_peps][1] = $pep;

      #print "$codes[$i]   $pepmass\n";
      $pepmass = 0;
      undef $pep;
      ++$n_peps;
    } else {
      $pep .= $codes[$i];

      #print "$codes[$i]";
      $pepmass += $s2m{ $codes[$i] };
    }
  }
  return ($n_peps);
}

1;

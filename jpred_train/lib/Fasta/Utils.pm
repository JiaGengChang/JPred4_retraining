package Fasta::Utils;

our $VERSION = '0.3';

=head1 NAME 

Fasta::Utils - A collection of functions to manipulate Fasta files.

=head1 SYNOPSIS

   use Fasta::Utils;

   my $seqs = parse($fasta);
   %$seqs = (
      $seqID => {
         'desc' => "some description of the sequence",
         'seq' => "ACDEFGHIKL",
      }
   );

   my $seq = chopSeq($seqs->{$seqID}{seq}, 30);
   
   my $num_files = splitSeqs($seqs, 25, 'batch');

=head1 DESCRIPTION

This module has a variety of functions that can be used to manipulate fasta files: parse(), chopseq(), splitSeqs() plus more hopefully...

=over

=item parse(filename, toggle non-std)

Takes my renumbered fasta files and returns a reference to an ordered hash (using Tie::IxHash) containing the seqID, description (if any) and sequence.

Optionally also allows the parsing of fasta files not renumbered by me. Use 1 for True and 0 for False [default].

=item chopSeq(sequence, width)

Rejustify sequence data to a set width [default = 60]. Returns the justified sequence.

=item splitSeqs(sequences, num sequences per file, filename)

Breaks up fasta files into smaller files. The sequences need to be pre-formatted using 
parse(). The default number of sequences per file is 1. A filename for
the smaller files is optionall and will be appended with which number block of 
sequences it is (e.g. cerevisiae001.fasta, cerevisiae002.fasta,..).
Returns the number of sequence blocks or -1 if the number of sequences per file is <1.

=back

=head1 AUTHOR

Chris Cole <christian@cole.name>

=head1 COPYRIGHT

Copyright 2005, Chris Cole.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(parse chopSeq splitSeqs);

sub max {
  my ( $x, $y ) = @_;

  return $x if $x > $y;
  return $y;
}

sub parse {
  my ( $fasta, $nonStd ) = @_ or return;

  open( FASTA, $fasta ) or die "ERROR - can't open file $fasta: $!";

  my $seqID     = '';
  my $desc      = '';
  my $seq       = '';
  my $protCount = 0;
  my %prots     = ();

  #  tie( %prots, 'Tie::IxHash' );

  while (<FASTA>) {
    if (/^>/) {
      if ($protCount) {
        warn "Warning - $seqID already exists. Check that the sequences are unique.\n" if ( defined( $prots{$seqID} ) );
        $prots{$seqID}{desc} = $desc;
        $prots{$seqID}{seq}  = $seq;
        $seq                 = '';
      }
      if ($nonStd) {
        my @rest;
        ( $seqID, @rest ) = split;
        $seqID =~ s/>//;
        $desc = join( " ", @rest );

      } else {
        if (/^>(\D{4}\d{5})\s(.*)$/) {
          $seqID = $1;
          $desc  = $2;
        } else {
          die "ERROR - No valid seqID found at line $.: $_\nDied";
        }
      }
      ++$protCount;
      next;
    } else {
      if ( !$seqID ) {
        print "ERROR - first line of file not \'>\': check that this is a valid fasta formatted file.\n";
        return (0);
      }
      chomp;
      $seq .= $_;
    }
  }
  close(FASTA) or die "ERROR - can't close file $fasta: $!";
  if ($seq) {
    warn "Warning - $seqID already exists. Check that the sequences are unique.\n" if ( defined( $prots{$seqID} ) );
    $prots{$seqID}{desc} = $desc;
    $prots{$seqID}{seq}  = $seq;
  }
  return ( \%prots );
}

sub chopSeq {
  my ( $seq, $sizeOfBits ) = @_ or return;

  return ($seq) if ( defined($sizeOfBits) && ( $sizeOfBits == 0 ) );
  $sizeOfBits = 60 unless $sizeOfBits;
  my $length = length($seq);
  my $cut    = $sizeOfBits;

  while ( $cut < $length ) {
    substr( $seq, $cut, 0, "\n" );
    ++$cut;
    $cut += $sizeOfBits;
  }
  return ($seq);
}

sub splitSeqs {
  my ( $seqData, $seqsPerFile, $rootFilename ) = @_ or return;

  $seqsPerFile = 1 if !defined($seqsPerFile);
  return (-1) if ( $seqsPerFile < 1 );

  my $seqCount  = 0;
  my $fileCount = 1;

  # avoid getting warnings for unitialised variable
  $rootFilename = '' if !defined($rootFilename);

  my $output = sprintf "%s%03d.fasta", $rootFilename, $fileCount;
  open( OUT, '>', $output ) or die "ERROR - can't open file \'$output\': $!";

  foreach my $seqID ( sort keys %$seqData ) {
    if ( $seqCount == $seqsPerFile ) {
      $seqCount = 0;
      close(OUT);
      ++$fileCount;
      $output = sprintf "%s%03d.fasta", $rootFilename, $fileCount;
      open( OUT, '>', $output ) or die "ERROR - can't open file \'$output\': $!";
    }
    if ( $seqData->{$seqID}{desc} ) {
      print OUT ">$seqID $seqData->{$seqID}{desc}\n$seqData->{$seqID}{seq}\n";
    } else {
      print OUT ">$seqID\n$seqData->{$seqID}{seq}\n";
    }
    ++$seqCount;
  }
  close(OUT);

  return ($fileCount);
}
1;

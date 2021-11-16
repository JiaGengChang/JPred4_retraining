package Scanps::BLC;

our $VERSION = '0.1';

use strict;
use warnings;

our @ISA    = qw(Exporter);
our @EXPORT = qw(get_iter blc2fasta);

sub get_iter {
  ## function to extract alignment for speicifc iteration
  my ( $fh, $it ) = @_;

  $it = -1 if ( !defined($it) );

  my $pos;
  my $found;
  while (<$fh>) {
    if (/^# Alignment from iscanps iteration:(\d+)/) {
      $found = $1;
      $pos   = tell $fh;
      last if ( $it >= 0 && $it == $found );
    }
  }
  warn "Warning - iteration $it not found. Using the last one: $found\n" if ( $it > $found );
  die "No alignments found! Make sure the file contains valid Scanps BLC file data." if ( !$pos );

  seek( $fh, $pos, 0 );

  my @blc;
  while (<$fh>) {
    next if (/^#/);
    push @blc, $_;
    last if (/\s*\*$/);
  }
  die "ERROR - no data found in BLC file" if ( !@blc );
  return ( \@blc );

}

sub blc2fasta {
  ## function convert BLC format to Fasta
  ## code taken and adapted from 'aconvert'

  my ( $blc, $out ) = @_;
  my $data = get_block($blc);
  write_fasta( $data, $out );
}

sub get_block {
  ## taken from aconvert
  ##
  ## modified a bit to make strict happy, plus now takes
  ## a reference to an array as input rather than the whole array.

  my ($data) = @_;
  my ( $align, $i, $j, $k, $n );

  $align = {};

  $align->{seq}  = ();
  $align->{ids}  = ();
  $align->{list} = ();
  $align->{nseq} = 0;

  my $in_names    = 1;
  my $in_align    = 0;
  my $name_count  = 0;
  my $start_field = 0;
  foreach (@$data) {
    chomp;
    if ( ( $in_names == 1 ) && (/>/) ) {
      my ( $prebumpf, $label ) = split(/>/);
      my $postbumpf = $label;
      $label     =~ s/ .*//;
      $postbumpf =~ s/$label//;
      if ( defined( $align->{ids}{$label} ) ) {
        $label = $label . "-" . $name_count;
      }
      $align->{list}[$name_count]      = $label;
      $align->{ids}{$label}{seq}       = "";
      $align->{ids}{$label}{prebumpf}  = $prebumpf;
      $align->{ids}{$label}{postbumpf} = $postbumpf;
      $name_count++;
    } elsif ( ( $in_align == 1 ) && (/[^ ]/) ) {
      last if (/\*/);
      $_ =~ s/ /-/g;
      my $seqdat = substr( $_, $start_field );
      $seqdat =~ s/ //g;
      for ( $i = 0 ; $i < $name_count ; ++$i ) {
        my $label = $align->{list}[$i];
        $align->{ids}{$label}{seq} .= substr( $seqdat, $i, 1 );
      }
    } elsif (/\*/) {
      $in_names    = 0;
      $in_align    = 1;
      $start_field = 0;
      while ( substr( $_, $start_field, 1 ) ne "*" ) { $start_field++; }
    }
  }
  $align->{nseq} = $name_count;
  $align->{alen} = length( $align->{ids}{ $align->{list}[0] }{seq} );

  #   print "Details from get_block: nseq = ",$align->{nseq}," alen = ",$align->{alen},"\n";
  #   die;
  $align->{id_prs} = get_print_string($align);
  return $align;
}

sub get_print_string {
  ## taken from aconvert

  my ($align) = @_;

  my $max_len = 0;
  for ( my $i = 0 ; $i < $align->{nseq} ; ++$i ) {
    my $this_len = length( $align->{list}[$i] );
    if ( $this_len > $max_len ) { $max_len = $this_len; }
  }
  return $max_len;
}

sub write_fasta {
  ## taken from aconvert
  ##
  ## only modifed to not print out all the 'bumpf' - just the seqID

  my ( $align, $outfile ) = @_;
  my ( $i, $j, $k, $id );

  open( OUT, ">$outfile" ) || die "Error opening output file '$outfile': $!\n";

  foreach $id ( keys %{ $align->{ids} } ) {
    if ( defined( $align->{ids}{$id}{start} ) ) {
      $align->{ids}{$id}{newid} = $id . "/" . ( $align->{ids}{$id}{start} + 1 ) . "-" . ( $align->{ids}{$id}{end} + 1 );
      if ( defined( $align->{ids}{$id}{ranges} ) ) {
        $align->{ids}{$id}{newid} .= $align->{ids}{$id}{ranges};
      }
    } else {
      $align->{ids}{$id}{newid} = $id;
    }
  }

  for ( $i = 0 ; $i < $align->{nseq} ; ++$i ) {
    $id = $align->{list}[$i];
    print OUT ">", $id, " ";

    #if(defined($align->{ids}{$id}{prebumpf})) { print OUT $align->{ids}{$id}{prebumpf}," "; }
    #if(defined($align->{ids}{$id}{postbumpf})) { print OUT $align->{ids}{$id}{postbumpf}," "; }
    print OUT "\n";
    for ( $j = 0 ; $j < length( $align->{ids}{$id}{seq} ) ; ++$j ) {
      print OUT substr( $align->{ids}{$id}{seq}, $j, 1 );
      if ( ( ( $j + 1 ) % 60 ) == 0 ) { print OUT "\n"; }
    }
    print OUT "\n";
  }
  close(OUT);
}

1;

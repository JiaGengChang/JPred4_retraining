package Data::Histo;

our $VERSION = '0.1';

=head1 NAME 

Data::Histo - Module for creating histograms

=head1 SYNOPSIS

use Data::Histo qw(varHist plotHist newplotHist)

Add more detail...

=head1 DESCRIPTION

=over

=item varHist()

Populates a hash with a variable number of bins based
upon a given bin width (default = 1)

=item plot()

Output the histogram to screen and (optionally) to a given filename.

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
our @EXPORT = qw(varHist plotHist newplotHist);

sub max {
  my ( $a, $b ) = @_ or return;

  return $a if $a > $b;
  return $b;
}

sub varHist {

  my ( $value, $max_bin, $href, $div ) = @_;

  $div = 1 unless $div;

  my $bin;
  if ( $value <= $div ) {
    $bin = $div;
  } else {
    $bin = ( ( int $value / $div ) + 1 ) * $div;
  }

  #print "$value is in $bin\n";
  $href->{$bin}++;
  $max_bin = max( $bin, $max_bin );

  return ($max_bin);
}

sub fixHist {

  # generate a histogram with fixed number of bins
  # maybe useful in future?

}

sub plotHist {

  my ( $href, $max_bin, $file, $div ) = @_;

  $div = 1 unless $div;

  open( OUT, ">$file" ) or die "can't open file $file: $!" if $file;
  for ( my $bin = $div ; $bin <= $max_bin ; $bin += $div ) {

    #print "$bin $x_data{$bin}\n";
    printf "%3d: ", $bin;
    print OUT "$bin," if $file;
    if ( $href->{$bin} ) {
      print "#" for ( 1 .. $href->{$bin} );
      print OUT "$href->{$bin}\n" if $file;
    } else {
      print OUT "0\n" if $file;
    }
    print "\n";
  }
  close(OUT);
}

sub newplotHist {

  my ( $aref, $max_bin, $file, $div ) = @_;

  $div = 1 unless $div;

  open( OUT, ">$file" ) or die "can't open file $file: $!" if $file;
  for ( my $bin = $div ; $bin <= $max_bin ; $bin += $div ) {

    #print "$bin $x_data{$bin}\n";
    print OUT "$bin" if $file;
    foreach my $col ( @{$aref} ) {
      if ( $col->{$bin} ) {
        print OUT ",$col->{$bin}" if $file;
      } else {
        print OUT ",0" if $file;
      }
    }
    print OUT "\n";
  }
  close(OUT);

}

1;

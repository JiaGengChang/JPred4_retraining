package Jpred::concise;

our $VERSION = '0.1';

=head1 SYNOPSIS

Jpred::concise - perl module to parse concise files

=cut

use strict;
use warnings;
use Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(read_new get_item get_item_array);

sub read_new {
  my ($file) = @_;

  my %struct;

  open( my $fh, $file ) or die "ERROR - unable to open file \'$file\': $!";
  while (<$fh>) {
    chomp;
    my ( $id, $data ) = split /:/, $_;
    next unless $id;
    $id =~ tr/A-Z/a-z/;
    $struct{$id} = $data;
  }
  close($fh);
  return ( \%struct );
}

#
## generic function to extract required data from a Jnet output file
## The data is returned as a string.
#
sub get_item ($$) {
  my ( $fh, $item ) = @_;

  seek( $fh, 0, 0 );    # rewind to start of file at each call.

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

#
## get_item_array() - function to extract Jnet data and retiurn as an array.
#
sub get_item_array ($$) {
  my ( $fh, $item ) = @_;

  seek( $fh, 0, 0 );    # rewind to start of file at each call.

  while (<$fh>) {
    chomp;
    my ( $id, $data ) = split /:/, $_;
    next unless $id;
    if ( $id =~ /$item/i ) {
      my @array = split /\,/, $data;
      return (@array);
    }
  }
}

1;

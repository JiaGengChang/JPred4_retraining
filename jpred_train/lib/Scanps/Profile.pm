package Scanps::Profile;

use strict;
use warnings;

our $VERSION = '0.1';

our @ISA    = qw(Exporter);
our @EXPORT = qw(profile);

my ($file) = @ARGV;

sub profile ($;$) {
  my ( $fh, $it ) = @_;

  $it = -1 if ( !defined($it) );
  print "No filehandle provided!" unless ($fh);

  my $pos;
  my $found;
  while (<$fh>) {
    ## find starts of profile tables.
    ## stop looking when found user defined one else
    ## keep going until last one.
    ## NB: iterations start at zero
    if (/^# Lookup table \(profile\) derived from iteration:\s+(\d+)/) {
      $found = $1;
      $pos   = tell $fh;
      last if ( $it >= 0 && $found == $it );
    }
  }
  warn "Warning - iteration $it not found. Using the last one: $found" if ( $it > $found );
  print "No profile table found! Make sure the file contains valid Scanps profile data." if ( !$pos );

  seek( $fh, $pos, 0 );
  my $sum = 0;
  my @data;
  my $r = 0;
  while (<$fh>) {
    last if (/^#/);
    next if (/^Pos/);
    my (@pssm) = split;
    my $c = 0;
    foreach my $col ( 3 .. 22 ) {
      $data[$r][$c] = $pssm[$col];

      #print "$r $c: $data[$r][$c]\n";
      $sum += $pssm[$col];
      ++$c;
    }
    ++$r;
  }
  warn "No data found in profile!" if ( !$sum );
  return ( \@data );

}

1;

__END__

=head1 NAME

Scanps::Profile - module to extract Profile information from Scanps output

=head1 SYNOPSIS

 how to us your program

=head1 DESCRIPTION

 long description of your program

=head1 SEE ALSO

 need to know things before somebody uses your program

=head1 AUTHOR

 Chris Cole (GJB)

=cut

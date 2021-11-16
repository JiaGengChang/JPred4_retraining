package PDB::Utils;

our $version = '0.1';

=head1 NAME 

PDB::Utils - This should simplify reading of pdb files

=head1 SYNOPSIS



=head1 DESCRIPTION

Takes ATOM/HETATM records and splits them at the standard column 
widths into the separate fields. Will prevent problem of 'split'ing a 
line which has blank columns thereby messing up the 'split' field 
assignments.

=cut

use strict;
use warnings;
use Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(parse);

sub read_pdb {
  my $file = shift;

  open( my $fh, '<', $file ) or die "ERROR - can't open \'$file\' for read: $!";
  return ($fh);

}

sub parse {
  my ( $file, $format ) = @_;

  my $fh = read_pdb($file);

  my %data;

  my @residues;
  my $chain;

  while (<$fh>) {
    my $record = (split)[0];

    #print "$record\n";

    if ( $record eq 'HEADER' ) {
      my ($dat) = $_ =~ /HEADER\s+(\w.*)$/;
      $data{$record} = $dat;
    }
    if ( $record eq 'SEQRES' ) {

      if ( substr( $_, 11, 1 ) ne ' ' ) {

        # do stuff here to deal with multi-chain seqres records...
      }

      my @fields = $_ =~ /\b([A-Z]{3})\b/g;    # find all 3-letter AA codes on line
      push @residues, @fields;
      undef @fields;
    }
    if ( $record eq 'ATOM' ) {

    }

  }

  if (@residues) {
    $data{SEQRES} = \@residues;
  }

  return ( \%data );

}

sub atom_rec {

}

=head

sub Gen_Fields {
	$line = $_[0];
	
	$pdb{record} = substr ($line, 0, 6);
	$pdb{serial} = substr ($line, 6, 5);
	$pdb{name} = substr ($line, 12, 4);
	$pdb{altLoc} = substr ($line, 16, 1);
	$pdb{resName} = substr ($line, 17, 3);
	$pdb{chainID} = substr ($line, 21, 1);
	$pdb{resSeq} = substr ($line, 22, 4);
	$pdb{iCode} = substr ($line, 26, 1);
	$pdb{x} = substr ($line, 30, 8);
	$pdb{y} = substr ($line, 38, 8);
	$pdb{z} = substr ($line, 46, 8);
	$pdb{occupancy} = substr ($line, 54, 6);
	$pdb{tFactor} = substr ($line, 60, 6);
	$pdb{segID} = substr ($line, 72, 4);
	$pdb{element} = substr ($line, 76, 2);
	$pdb{charge} = substr ($line, 78, 2);
	
	return %pdb;
}

=cut

1;

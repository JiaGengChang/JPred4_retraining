package Jpred::SOV;

our $VERSION = '0.5';

=head1 NAME

Jpred::SOV - class to calculate SOV scores from Jnet predictions

=head1 SYNOPSIS

   use Jpred::SOV;

   my $sov = Jpred::SOV->new();    # create new SOV object
   $sov->write(                    # write SOV input file with required data
      dssp => $dssp,
      pred => $pred,
      seq  => $seq
   );
   $sov->run();                    # run SOV using default parameters
   my $score = $sov->score();      # retrieve the SOV score

   To modify any of the default parameters:

   $sov->input('new_input_file');
   $sov->output('new_output_file');
   $sov->path('/new/sov/path');

=head1 DESCRIPTION

This class provides methods to prepare and run an SOV calculation as defined in "Zemla et al. - PROTEINS: Structure,
Function, and Genetics, 34, 1999, pp. 220-223".

=head1 AUTHOR

Chris Cole <christian@cole.name>

=head1 COPYRIGHT

Copyright 2008, Chris Cole. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use Exporter;
use Cwd;

our @ISA       = qw(Exporter);
our @EXPORT    = qw(new);
our @EXPORT_OK = qw();

### New object method
## Default values for path, input and output are defined, but can be overridden.
## Any arguments passed to it as hash key-value pairs will be parsed as methods
## with the key being the method name and the value being the method parameter.
sub new {
  my ( $class, %args ) = @_;
  my $self = {
    path   => '/cluster/gjb_lab/2472402/bin/', # warning: hard-coded path
    output => 'sov.out',
    input  => 'sov.in'
  };
  bless( $self, $class );

  for ( keys %args ) {
    die "ERROR - No such method '$_'" unless $self->can($_);
    $self->$_( $args{$_} );
  }

  return $self;
}

### Methods to return and optionally set the SOV executable, input and output paths.
## If these methods are passed an argument it will be used to set its path.
## No checking of the arguments is done at this stage.
sub path {
  my $self = shift;
  my $path = shift;

  $self->{path} = $path if ($path);
  return ( $self->{path} );
}

sub output {
  my $self = shift;
  my $out  = shift;

  $self->{output} = $out if ($out);
  return ( $self->{output} );
}

sub input {
  my $self = shift;
  my $in   = shift;

  $self->{input} = $in if ($in);
  return ( $self->{input} );

}

### Method to run the SOV calulation ## The executable and input path values are tested at this before running SOV.
## Checks that the output is created.
sub run {
  my $self = shift;

  die "ERROR - SOV input '$self->{input}' not found"        unless ( -e $self->{input} );
  die "ERROR - sov executable not found at '$self->{path}'" unless ( -e "$self->{path}/calSOV" );
  die "ERROR - sov not executable at '$self->{path}'"       unless ( -x "$self->{path}/calSOV" );

  my $cmd = "$self->{path}/calSOV $self->{input} > $self->{output}";
  system($cmd) == 0 or die "ERROR - system call failed\n";
  die "ERROR - SOV output '$self->{output}' was not generated. Died" unless ( -e $self->{output} );
}

### Method to extract the SOV score from the output file
## Currently only the SOVall score is returned.
sub score {
  my $self = shift;

  open( my $fh, "<", $self->{output} ) or die "ERROR - unable to open '$self->{output}': ${!}\nDied";
  while (<$fh>) {
    if (/.sov/) {
      my @F = split;
      die "ERROR - not enough fields in SOV output '$self->{output}'" if ( scalar @F < 6 );
      $self->{SOV}  = $F[1];
      # $self->{SOVH} = $F[2];
      # $self->{SOVE} = $F[3];
      # $self->{SOVC} = $F[4];
    }
  }
  die "ERROR - SOV score not found in '$self->{output}'" unless ( defined $self->{SOV} );
  close($fh);

  return ( $self->{SOV} );
}

### Method to write the SOV input file ready for running
## Requires the sequence, DSSP and prediction as strings in a key-value pair as arguments e.g.:
##
##    $sov->write(
##       dssp => $dssp,
##       pred => $pred,
##       seq => $seq
##    );
##
## Checks that the inputs are all of equal length.
sub write {
  my $self = shift;
  my %args = @_;

  # look for required inputs
  foreach my $arg (qw(dssp pred seq)) {
    die "ERROR - required argument '$arg' not supplied\n" unless ( exists( $args{$arg} ) );
    $self->{$arg} = $args{$arg};
  }

  # convert coil definitions to be SOV compatible
  $self->{dssp} =~ s/-/C/g;
  $self->{pred} =~ s/-/C/g;

  # check the lengths of the inputs are equal
  warn "Warning - input data not of equal length\n" if ( length( $self->{seq} ) != length( $self->{dssp} ) || length( $self->{dssp} ) != length( $self->{pred} ) );

  # create a 2D array of the data
  my @inputData;
  $inputData[0] = [ split //, $self->{seq} ];
  $inputData[1] = [ split //, $self->{dssp} ];
  $inputData[2] = [ split //, $self->{pred} ];

  # ...and output to file in the correct format
  open( my $fh, ">", $self->{input} ) or die "ERROR - unable to open '$self->{input}' for write: ${!}\nDied";
  print $fh "AA  OSEC PSEC\n";
  foreach my $i ( 0 .. $#{ $inputData[0] } ) {
    print $fh "$inputData[0][$i]   $inputData[1][$i]    $inputData[2][$i]\n";
  }
  close($fh);
}

1;

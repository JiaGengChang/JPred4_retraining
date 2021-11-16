package DSSP;

our $VERSION = '0.1';

=head1 NAME

DSSP.pm - module to parse DSSP files

=cut

use strict;
use warnings;
use base 'Exporter';

our @EXPORT = qw(new read get_segment check_for_gaps unknowns get_acc);

sub new ($) {

  # function to open a DSSP file and return
  # a filehandle to it
  my ($file) = shift;

  if ( -e $file ) {
    open( my $fh, $file ) or die "'$file': $!";
    return ($fh);
  } else {
    die "'$file' doesn't exist";
    return (0);
  }
}

sub read {

  # function to extract sequence info from DSSP file

  my ( $fh, $showAll ) = @_;

  my %conv = qw(H H E E B E);

  my %sec;
  my $length;
  while (<$fh>) {

    if (/^\s+#\s+RESIDUE/) {    # start of structure information

      my $chn;
      my $tmp_chn = 'no chain ID';
      my $i       = 0;
      while ( my $line = <$fh> ) {
        next if ( $line =~ /RESIDUE/ );
        my $aa    = substr( $line, 13, 1 );
        my $resID = substr( $line, 6,  4 );
        $resID =~ s/\s//g;
        my $acc = substr( $line, 35, 3 );
        $acc =~ s/\s//g;
        next if ( $aa eq '!' );    # ignore if not a residue
                                   #next if ($aa eq 'X');	# ignore if not a recognised residue

        # dssp gives diS cysteine pairs a different lower letter
        # convert this back to a C residue
        $aa =~ tr/[a-z]/C/;
        last if ( $line =~ /^\s+$/ );

        $chn = substr( $line, 11, 1 );
        $chn = '_' if ( $chn eq ' ' );

        #$i = 0 if ($chn ne $tmp_chn); # reset array index for each new chain
        ## reset array index for each new chain.
        ## except where the chain has already been defined. Then set the array index to continue from where the chain left off.
        if ( $chn ne $tmp_chn ) {
          if ( defined( $sec{$chn} ) ) {
            $i = scalar @{ $sec{$chn}{res} };
          } else {
            $i = 0;
          }
        }

        my $state;
        if ($showAll) {
          $state = substr( $line, 16, 1 );
          $state =~ s/\s/-/;
        } else {
          $state = $conv{ substr( $line, 16, 1 ) };
        }
        if ($state) {
          $sec{$chn}{res}[$i] = $aa;
          $sec{$chn}{sec}[$i] = $state;
          $sec{$chn}{num}[$i] = $resID;
          $sec{$chn}{acc}[$i] = $acc;
        } else {
          $sec{$chn}{res}[$i] = $aa;
          $sec{$chn}{sec}[$i] = '-';
          $sec{$chn}{num}[$i] = $resID;
          $sec{$chn}{acc}[$i] = $acc;
        }
        $tmp_chn = $chn;
        ++$i;
      }
      last;
    }
  }
  return ( \%sec );

}

# function to only get part of the sequence
sub get_segment ($$;$$) {
  my ( $data, $chain, $start, $end ) = @_;

  die "ERROR! chain '$chain' not found.\n" unless $data->{$chain};

  my $length = scalar @{ $data->{$chain}{num} };

  my $seq;
  my $dssp;
  if ( $start && $end ) {
    if ( $start < $data->{$chain}{num}[0] ) {
      warn "ERROR! Defined start position '$start' in range is before the first residue in the structure '$data->{$chain}{num}[0]'";
      return;
    }
    if ( $end > $data->{$chain}{num}[ $length - 1 ] ) {
      warn "ERROR - Defined end position '$end' in range is beyond the end of the structure '$data->{$chain}{num}[$length-1]'";
      return;

    }

    for ( my $i = 0 ; $i < $length ; ++$i ) {
      if ( ( $data->{$chain}{num}[$i] >= $start ) && ( $data->{$chain}{num}[$i] <= $end ) ) {
        $seq  .= $data->{$chain}{res}[$i];
        $dssp .= $data->{$chain}{sec}[$i];
      }
    }
    die "ERROR! sequence and DSSP aren't the same length" if ( length($seq) != length($dssp) );
  } else {
    $seq  = join( "", @{ $data->{$chain}{res} } );
    $dssp = join( "", @{ $data->{$chain}{sec} } );
  }
  return ( $seq, $dssp );

}

#
##  function to check for gaps longer than $maxGap.
##
##  Returns position of the first failing gap or 0 for no failing gaps.
#
sub check_for_gaps ($$$;$$) {
  my ( $data, $maxGap, $chain, $start, $end ) = @_;

  my $length = scalar @{ $data->{$chain}{num} };

  if ( $start && $end ) {
    if ( $start < $data->{$chain}{num}[0] ) {
      warn "ERROR - Defined start position '$start' in range is before the first residue in the structure '$data->{$chain}{num}[0]'";
      return (-1);
    }
    if ( $end > $data->{$chain}{num}[ $length - 1 ] ) {
      warn "ERROR - Defined end position '$end' in range is beyond the end of the structure '$data->{$chain}{num}[$length-1]'";
      return (-1);
    }

    #print "start: $start  end: $end\n";
    for ( my $i = 0 ; $i < $length ; ++$i ) {
      if ( ( $data->{$chain}{num}[$i] >= $start ) && ( $data->{$chain}{num}[$i] <= $end ) ) {
        ## check that there are no large gaps within the required range
        if ( ( $data->{$chain}{num}[$i] - $data->{$chain}{num}[ $i - 1 ] > ( $maxGap + 1 ) ) && ( $data->{$chain}{num}[ $i - 1 ] >= $start ) ) {
          return ( $data->{$chain}{num}[ $i - 1 ] );    # return the start of the large gap.
        }
      }
    }
  } else {
    for ( my $i = 0 ; $i < $length ; ++$i ) {
      ## check that there are no large gaps within the required range
      if ( ( $data->{$chain}{num}[ $i - 1 ] >= 0 ) && ( $data->{$chain}{num}[$i] - $data->{$chain}{num}[ $i - 1 ] > ( $maxGap + 1 ) ) ) {
        return ( $data->{$chain}{num}[ $i - 1 ] );      # return the start of the large gap.
      }
    }
  }

  return (0);
}

# function to find unknown ('X') residues in the sequence
sub unknowns ($$;$$) {
  my ( $data, $chain, $start, $end ) = @_;

  my $length = scalar @{ $data->{$chain}{num} };
  my %unk;

  if ( $start && $end ) {
    if ( $start < $data->{$chain}{num}[0] ) {
      warn "ERROR - Defined start position '$start' in range is before the first residue in the structure '$data->{$chain}{num}[0]'";
      return;
    }
    if ( $end > $data->{$chain}{num}[ $length - 1 ] ) {
      warn "ERROR - Defined end position '$end' in range is beyond the end of the structure '$data->{$chain}{num}[$length-1]'";
      return;
    }

    #print "start: $start  end: $end\n";
    for ( my $i = 0 ; $i < $length ; ++$i ) {
      if ( ( $data->{$chain}{num}[$i] >= $start ) && ( $data->{$chain}{num}[$i] <= $end ) ) {
        $unk{ $data->{$chain}{num}[$i] }++ if ( $data->{$chain}{res}[$i] eq 'X' );
      }
    }
  } else {
    for ( my $i = 0 ; $i < $length ; ++$i ) {
      $unk{ $data->{$chain}{num}[$i] }++ if ( $data->{$chain}{res}[$i] eq 'X' );
    }
  }
  return (%unk);
}

sub get_acc ($$;$$) {
  my ( $data, $chain, $start, $end ) = @_;

  die "ERROR! chain '$chain' not found.\n" unless $data->{$chain};

  my @acc;
  my $length = scalar @{ $data->{$chain}{acc} };

  my $seq;
  my $dssp;
  if ( $start && $end ) {
    if ( $start < $data->{$chain}{num}[0] ) {
      warn "ERROR - Defined start position '$start' in range is before the first residue in the structure '$data->{$chain}{num}[0]'";
      return;
    }
    if ( $end > $data->{$chain}{num}[ $length - 1 ] ) {
      warn "ERROR - Defined end position '$end' in range is beyond the end of the structure '$data->{$chain}{num}[$length-1]'";
      return;

    }

    #print "start: $start  end: $end\n";
    my $j = 0;
    for ( my $i = 0 ; $i < $length ; ++$i ) {
      if ( ( $data->{$chain}{num}[$i] >= $start ) && ( $data->{$chain}{num}[$i] <= $end ) ) {
        $acc[$j] = $data->{$chain}{acc}[$i];
        ++$j;
      }
    }
  } else {
    for ( my $i = 0 ; $i < $length ; ++$i ) {
      $acc[$i] = $data->{$chain}{acc}[$i];
    }
  }

  return ( \@acc );
}

1;

package Sequence::Fasta;

our $VERSION = '0.3';

=head1 NAME

Sequence::Fasta - class to handle Fasta objects

=head1 SYNOPSIS

 use Sequence::Fasta;
 my $fas = Sequence::Fasta->new(file => $file);  # create object and assign filename
 $fas->read()                                    # read in Fasta file
 printf "Read %d sequences\n", $fas->NumSequences(); # count Fasta entries in file
 my $seq = $fas->getEntryByID('4bcl_A', 'seq');  # retrieve sequence only for ID '4bcl_A'
 $fas->selectByDesc('human');                    # select subset of entries annotated as 'human'

=head1 DESCRIPTION

This perl class was borne by frustrations with BioPerl et al., in not allowing me to do what I wanted with Fasta files. This gets closer to my ideal. It has limitations, is not useful for all situations and is not perfect, but it works dammit!

More details on the individual methods is below.

=cut

use strict;
use warnings;
use Tie::IxHash;

my $self = {};

=head1 Methods

=over 5

=item B<new()>

Class constructor. Any sensible method name plus parameters can be passed as a hash key/value pair.

returns: object

=cut

sub new {
  my ( $class, %args ) = @_;
  bless( $self, $class );

  # Automatically run any arguments passed to the constructor
  foreach my $k ( keys %args ) {
    warn "ERROR - No such method '$k' of object $class\nDied" unless $self->can($k);
    $self->$k( $args{$k} );
  }

  return ($self);
}

=item B<file()>

Getter/setter for fasta filename.

=cut

sub file {
  my $self = shift;
  my $file = shift;

  if ($file) {
    $self->error("ERROR - '$file' not found") unless ( -e $file );
    $self->{file} = $file;
  } elsif ( $self->{file} ) {
    return $self->{file};
  } else {
    return (0);
  }
}

=item B<read()>

Method to force reading in of file. Silently called by some methods, if not called explicitly.

=cut

sub read {
  my $self = shift;

  unless ( defined( $self->{file} ) ) {
    error("ERROR - no file has been set.");
    return (0);
  }

  open( my $FASTA, $self->{file} ) or warn "ERROR - can't open file '$self->{file}': $!";

  my $seqID = '';
  my $desc  = '';
  my $seq   = '';
  my $num   = 0;
  tie( %{ $self->{entries} }, 'Tie::IxHash' );

  while (<$FASTA>) {
    chomp;
    if (/^>/) {
      if ($num) {
        warn "Warning - $seqID already exists. Check that the sequences are unique.\n" if ( defined( $self->{entries}{$seqID} ) );
        $self->{entries}{$seqID}{desc} = $desc;
        $self->{entries}{$seqID}{seq}  = $seq;
        $seq                           = '';
      }
      my @rest;
      ( $seqID, @rest ) = split;
      $seqID =~ s/>//;
      $desc = join( " ", @rest );
      ++$num;
      next;
    } else {
      if ( !$seqID ) {
        warn "ERROR - first line of '$self->{file}' not \'>\': check that this is a valid Fasta formatted file.\nDied";
        return (0);
      }
      $seq .= $_;
    }
  }
  close($FASTA) or warn "ERROR - can't close file '$self->{file}': $!";

  if ($seq) {
    warn "Warning - $seqID already exists. Check that the sequences are unique.\n" if ( defined( $self->{entries}{$seqID} ) );
    $self->{entries}{$seqID}{desc} = $desc;
    $self->{entries}{$seqID}{seq}  = $seq;
  }
  return ($self);

}

=item B<numSequences()>

Accessor method for the number of sequences in file

=cut

sub numSequences {
  my $self = shift;

  $self->read() unless ( defined( $self->{entries} ) );
  return ( scalar keys %{ $self->{entries} } );
}

=item B<write()>

Method to writeout entries into a new file or set of files.

paramss: output filename
         number
         type [seq|set]
         
'type' controls how the fasta entries are broken up. If set to 'seq' will create separate files with at most 'number' sequences in it. If set to 'set' will create at most 'number' output files with all the sequence entries.

Filenames are numbered 'filename.number'

If 'number' is undefined or '0' only one file is created.

=cut

sub write {
  my $self    = shift;
  my $outFile = shift;
  my $num     = shift;
  my $type    = shift;    # seq|set

  $num = 0 unless ($num);
  warn "ERROR - invalid number used for splitting sequences: $num\n" unless ( $num =~ /^\d+$/ );
  warn "ERROR - invalid number used for splitting sequences: $num\n" if ( $num < 0 );

  $type = 'seq' unless ($type);

  if ( $type eq 'set' ) {
    $num = int( $self->numSequences() / $num ) + 1;
  }

  my $n = 1;
  my $OUT;
  if ($num) {
    warn "ERROR - no filename specified for writing\n" unless ($outFile);
    open( $OUT, ">", "$outFile.$n" ) or warn "ERROR - unable to open '$outFile.$n' for write: ${!}\nDied";
  } else {
    if ($outFile) {
      open( $OUT, ">", $outFile ) or warn "ERROR - unable to open '$outFile' for write: ${!}\nDied";
      select($OUT);
    }
  }

  ## foreach entry...
  my $i = 0;
  foreach my $id ( keys %{ $self->{entries} } ) {

    # if 'chunking' open new files as required
    if ( $num && ( $i > 0 ) && ( $i % $num == 0 ) ) {
      close($OUT);
      ++$n;
      open( $OUT, ">", "$outFile.$n" ) or warn "ERROR - unable to open '$outFile.$n' for write: ${!}\nDied";
    }

    print ">$id $self->{entries}{$id}{desc}\n$self->{entries}{$id}{seq}\n";
    ++$i;
  }
  close($OUT) if ($OUT);

  return ($n);
}

=item B<getEntryByID()>

Select single entries from Fasta file.

params: id
        dataType [all|seq|desc]
        
If 'id' is found will return either the whole fasta entry (dataType = 'all') or only the sequence (dataTpe = 'seq') or description line (dataType = 'desc')

=cut

sub getEntryByID {
  my $self     = shift;
  my $id       = shift;
  my $dataType = shift;    # one of 'all','seq' or 'desc'

  $dataType = 'all' unless defined($dataType);
  $dataType =~ tr/A-Z/a-z/;

  warn "ERROR - unknown dataType: '$dataType'. Only [all|seq|desc] allowed." unless ( $dataType =~ /^(all|seq|desc)$/ );

  # read the file if it hasn't been done
  $self->read() unless ( scalar keys %{ $self->{entries} } );

  if ( exists( $self->{entries}{$id} ) ) {
    if ( $dataType eq 'all' ) {
      return (">$id $self->{entries}{$id}{desc}\n$self->{entries}{$id}{seq}\n");
    } elsif ( $dataType eq 'desc' ) {
      return ( $self->{entries}{$id}{desc} );
    } else {
      return ( $self->{entries}{$id}{seq} );
    }
  }
}

## private method by use by the below selectBy* methods
## assumes a string to match with and an optional 'reverse'
## parameter to specify whether to reverse the sense of the match
## (i.e. if reverse is true, returns all sequences *not* matching to the string)
sub selectEntries {
  my $string      = shift;
  my $matchToThis = shift;
  my $reverse     = shift;

  # read the file if it hasn't been done
  $self->read() unless ( scalar keys %{ $self->{entries} } );

  my @delete;
  if ( $matchToThis eq 'id' ) {
    foreach my $id ( keys %{ $self->{entries} } ) {
      if ($reverse) {

        # add ids to list that do match to string
        push @delete, $id if ( $id =~ /$string/i );
      } else {

        # add ids to list that don't match to string
        unless ( $id =~ /$string/i ) {
          push @delete, $id;
          print "Going to remove $id ...\n";
        }
      }
    }
  } else {
    foreach my $id ( keys %{ $self->{entries} } ) {
      if ($reverse) {

        # add ids to list that do match to string
        push @delete, $id if ( $self->{entries}{$id}{$matchToThis} =~ /$string/i );

      } else {

        # add ids to list that don't match to string
        push @delete, $id unless ( $self->{entries}{$id}{$matchToThis} =~ /$string/i );
      }
    }
  }

  # remove sequences that are in the list
  delete( $self->{entries}{$_} ) foreach @delete;
  return ( scalar keys %{ $self->{entries} } );
}

=item B<selectByID()>

=item B<selectBySeq()>

=item B<selectByDesc()>

The 'selectBy' methods destructively (!) retain a subset of the fasta data based on specific criteria from sequence, description or ID.

When I say destructively, I mean that once a subset has been selected it is not possible to return to whole dataset. No data is removed from the original file. These methods were developed to quickly retrieve subsets from the whole, but controlling where the matches were made in the Fasta data.

The methods have the same requirements.

params: string criteria
        boolean reverse

return: integer (number of selected entries)
        
If 'reverse' is TRUE then the search criteria are the opposite: i.e. selectByDesc('human', 1) will find all entries that don't match 'human'.

NB: 'criteria' is case insensitive and will match to everything, so make sure your criteria is not a substring of something that mustn't match. e.g. 'human' will also match to 'non-human'.

=cut

sub selectByDesc {
  my $self    = shift;
  my $string  = shift;
  my $reverse = shift;

  my $num = selectEntries( $string, 'desc', $reverse );
  return ($num);
}

## specify which sequences to retain by string matching
## to only the seqID (case insensitive)
sub selectByID {
  my $self    = shift;
  my $string  = shift;
  my $reverse = shift;

  my $num = selectEntries( $string, 'id', $reverse );
  return ($num);
}

## retain sequences by sequence matching
sub selectBySeq {
  my $self    = shift;
  my $string  = shift;
  my $reverse = shift;

  my $num = selectEntries( $string, 'seq', $reverse );
  return ($num);
}

=item B<getEntries()>

Retrieve all entries as a hash.

 %hash = (
    $id => {
       desc => <defline>,
       seq  => <sequence>
    },
 )

=cut

sub getEntries {
  my $self = shift;

  return ( $self->{entries} );
}

=item B<getEntryIDs()>

Retrieve all Fasta IDs as an arrayref, in the same order as they appear in the file

=cut

sub getEntryIDs() {
  my $self = shift;

  my @array;
  push @array, $_ foreach ( keys %{ $self->{entries} } );
  return ( \@array );
}

=item B<getSeq()>

For a given ID return the sequence

Returns sequence or 0 if ID not found.

=cut

sub getSeq() {
  my $self = shift;
  my $id   = shift;

  warn "ERROR - getSeq() requires a sequence ID\n" unless ($id);
  if ( defined( $self->{entries}{$id} ) ) {
    return ( $self->{entries}{$id}{seq} );
  }
  return (0);
}

=item B<getDesc()> 

For a given ID return the description

Returns the description string or 0 if ID not found.

=cut

sub getDesc() {
  my $self = shift;
  my $id   = shift;

  warn "ERROR - getDesc() requires a sequence ID\n" unless ($id);
  if ( defined( $self->{entries}{$id} ) ) {
    return ( $self->{entries}{$id}{desc} );
  }
  return (0);

}

=item B<reformat()>

Reformat seqeunces to a given width for pretty output.

params: width

returns: void

=cut

sub reformat {
  my $self  = shift;
  my $width = shift;

  $self->{format} = $width if ($width);

  #return($self->{format});

  foreach my $id ( keys %{ $self->{entries} } ) {
    $self->{entries}{$id}{seq} =~ s/(.{$self->{format}})/$1\n/g;
  }

}

=item B<error()>

Getter/setter for error messages.

params: string error

returns: string error or '0'

=cut

sub error {
  my $self = shift;
  my $msg  = shift;

  if ($msg) {
    warn "Warning - over-writing previous error message: $self->{error}" if ( defined( $self->{error} ) );
    $self->{error} = $msg;
  }

  if ( defined( $self->{error} ) ) {
    return ( $self->{error} );
  } else {
    return (0);
  }
}

=item B<printError()>

Method to printout any error messages.

=cut

sub printError {
  my $self = shift;

  print $self->{error}, "\n" if ( defined( $self->{error} ) );
  return (1);
}

=item B<clearError()>

Method to clear any error messages.

=cut

sub clearError {
  my $self = shift;

  undef( $self->{error} );
  return (1);
}

=head1 AUTHOR

Chris Cole <christian@cole.name>

=head1 COPYRIGHT

Copyright 2008-2010, Chris Cole. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;

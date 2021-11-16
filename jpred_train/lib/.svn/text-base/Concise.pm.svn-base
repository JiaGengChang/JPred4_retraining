package Concise;

our $VERSION = '0.1';

=head1 NAME

Concise - class for manipulating concise format files as used by Jnet/Jpred

=head1 SYNOPSIS

To read in data from a concise file:

   my $concise = Concise->new(file => 'file.concise');
   $concise->read();
   my $pred = $concise->get_item('jnetpred');       # return data as a string
   my @pred = $concise->get_item_array('jnetpred'); # retrun data as an array (useful for numerical data)
   
To write out data to a new file in concise format:

   my $concise = Concise->new(file => 'new.concise');
   my @dssp = qw( - - - - H H H H H H - - - - - );
   my @pred = qw( - - - H H H H H H - - - - - - );
   $concise->add_data('DSSP', \@dssp);       # add each data element individually
   $concise->add_data('jnetpred', \@pred);
   $concise->write();                        # write out data in the same order as it is entered

=head1 DESCRIPTION

This class is for simplifying life when dealing with Jnet/Jpred prediction data. However, it's not limited to this type of data and will read/write any kind of data in 'concise' format:

   jnetpred:-,-,-,H,H,H,H,H,H,-,-,-,-,-,-

or

   weight_of_people:45,63,76,101,78,67

This is a 'light-weight' format and this class makes it a doddle to work with.

=cut

use strict;
use warnings;
use Exporter;

our @ISA       = qw(Exporter);
our @EXPORT    = qw();
our @EXPORT_OK = qw();

=head1 METHODS

=over 8

=item B<new()>

Class contructor. Creates a new Concise object.

Requies a 'file' argument:

my $concise = Concise->new(file => 'myfile');

Options: file => 'name'

Returns: Concise object

=cut

sub new {
  my ( $class, %args ) = @_;
  my $self = {};
  bless( $self, $class );

  die "ERROR - no 'file =>' option given. Please provide a filename.\nDied" unless ( $args{file} );
  $self->file( $args{file} );

  return $self;
}

=item B<file()>

Set or return the filename the Consice object is referring to.

This is automatically called when creating a new Concise object, but can be called explicitly as well.

Requires: no requirements

Options: none

Returns: filename

=cut

sub file {
  my $self = shift;
  my $file = shift;

  $self->{file} = $file if ($file);
  return ( $self->{file} );
}

=item B<read()>

Read in Concise data and load into the object. Use the get_item() or get_item_array() methods to access the data.

The read() checks that the input file is a valid concise file and that there is the same amount of data per entry. It fails if the file is not valid or warns if the data has differs in length.

This is automatically called when creating a new Concise object, but can be called explicitly as well.

Requires: a file instance to have been created

Options: none

Returns: nothing

=cut

sub read {
  my $self = shift;

  die "ERROR - no file has been set.\nDied" unless ( $self->{file} );
  open( my $fh, "<", $self->{file} ) or die "ERROR - unable to open '$self->{file}': ${!}\nDied";

  my $length = 0;
  while (<$fh>) {
    next if (/^$/);    # skip blank lines
    next if (/^#/);    # skip comments

    ## check format is valid
    ## format must be a word-lke label separated by ':' from the data which must be
    ## single characters (\w, space, '*' or '-') or signed integers/floats separated
    ##  by commas either with or without a trailing comma
    die "ERROR - '$self->{file}' is not in concise format: $_\n.Died" unless ( $_ =~ /^\w+:(([\w\*\s-]|-?\d+.?\d*)\,)+\S*$/ );
    chomp;
    my ( $id, $data ) = split /:/, $_;
    next unless $id;
    $id =~ tr/A-Z/a-z/;
    my @dataArr = split /,/, $data;

    ## check all the data elements are the same length
    if ($length) {
      warn "Warning - '$id' data is not the same length as the rest in '$self->{file}'\nDied" if ( $length != scalar @dataArr );
    }
    $self->{data}{$id} = [@dataArr];
    $length = scalar @dataArr;
  }
  close($fh);
}

=item B<get_item()>

Retrieve data associated with a specific label as a string. Use the item_list() method to find allowed labels.

Requires: Concise data to have been read in

Options: label name

Returns: data string or '0' if not found

=cut

sub get_item {
  my $self = shift;
  my $item = shift;

  die "ERROR - no data in object. Don't forget to read() the file.\nDied" unless ( defined( $self->{data} ) );

  $item =~ tr/A-Z/a-z/;

  if ( $self->{data}{$item} ) {
    return ( join "", @{ $self->{data}{$item} } );
  } else {
    return (0);
  }
}

=item B<get_item_array()>

Retrieve data associated with a specific label as an array string. This is useful for numerical data. Use the item_list() method to find allowed labels.

Requires: Concise data to have been read in

Options: label name

Returns: data array or '0' if not found

=cut

sub get_item_array {
  my $self = shift;
  my $item = shift;

  $item =~ tr/A-Z/a-z/;

  if ( $self->{data}{$item} ) {
    return ( @{ $self->{data}{$item} } );
  } else {
    return (0);
  }
}

=item B<labels()>

Retrieve list of labels found in file.

Requires: Concise data to have been read in

Options: none

Returns: array of labels

   my @list = $concise->labels();

=cut

sub labels {
  my $self = shift;

  my @list;
  push @list, keys %{ $self->{data} };
  return (@list);
}

=item B<write()>

Write out data in concise format

Requires: Concise object to have been loaded with data and a file name

Options: none

Returns: nothing

=cut

sub write {
  my $self = shift;

  die "ERROR - no file has been set.\nDied"     unless ( $self->{file} );
  die "ERROR - no data to write to file.\nDied" unless ( $self->{new} );
  open( my $fh, ">", $self->{file} ) or die "ERROR - unable to open '$self->{file}' for write: ${!}\nDied";
  print $fh "$_\n" foreach @{ $self->{new} };
  close($fh);
}

=item B<add_data()>

Load Concise object with data. The data can then be written to file with the write() method.

Requires: none

Options: a label name and a array ref to the data

Returns: nothing

   $concise->add_data('jnetpred', \@pred);

=cut

sub add_data {
  my $self  = shift;
  my $label = shift;
  my $data  = shift;

  die "ERROR - label is empty.\nDied" unless ($label);
  die "ERROR - no data for label '$label'.\nDied" unless ( scalar @$data );

  my $string = sprintf "%s:%s", $label, join( ",", @$data );

  push @{ $self->{new} }, $string;
}

1;

=head1 NOTES

Label names are case insensitive. The use of the same label, but with in different cases, is untested and B<will> cause problems.

=head1 AUTHOR

Chris Cole <christian@cole.name>

=head1 COPYRIGHT

Copyright 2008, Chris Cole. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut


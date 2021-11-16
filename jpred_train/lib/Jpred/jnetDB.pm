package Jpred::jnetDB;

our $VERSION = '0.2';

=head1 NAME 

Jpred::jnetDB -- Common functions to access the Jnet database

=head1 SYNOPSIS


=head1 DESCRIPTION

This module is to simplify access commonly used data and access in the JnetDB. It is currently very much a work in progress...

Implemented functions so far:

=over 8

=item connect_DB()

Does what it says on the tin - connects to the db. The only parameter is a username

Returns the db handle object.

=item get_DSSP()

Again self-explanatory. Give the function a known dataset name and it will return a HoH with the DSSP and domainID data for that dataset.

=back

=head1 AUTHOR

Chris Cole <christian@cole.name>

=head1 COPYRIGHT

Copyright 2006, Chris Cole.  All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use DBI;
use File::Basename; # added by Jia Geng
require Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(connect_DB get_DSSP get_DSSP_no_DB check_DB get_seqID get_dataset db_path get_seq get_accDB);

##################################################################################################################################
# connect to the DB
#
sub connect_DB {
  my ($user) = @_;
  my $dbh;

  my $server = "gjb-mysql-1.cluster.lifesci.dundee.ac.uk";
  $dbh = DBI->connect( "dbi:mysql:jnet:$server", $user, 'T1SVDMwOfzlLZks', { AutoCommit => 1 } ) or die "ERROR! can't connect to db: ", $DBI::errstr;
  unless ($dbh) {
    return (0);
  }
  return ($dbh);
}

##################################################################################################################################
#
## get DSSP data from DB. Returns a reference to a HoH with the seqID as a primary key
## and the domainID and DSSP as secondary hash elements:
#  %data = (
#     $seqID => { dom => "domain ID", dssp => "DSSP output",},
#   );
#
sub get_DSSP {
  my $dbh    = shift;
  my $set    = shift;
  my $subset = shift;

  my %data;
  my $sth;
  if ($set) {    # select only a subset of the query data
    if ($subset) {
      my $train = 1;
      $train = 0 if ( $subset eq 'blind' );
      $sth = $dbh->prepare("SELECT seq_id,domain,dssp FROM query WHERE dataset = \'$set\' AND train = $train") or die "ERROR! unable to SELECT: ", $dbh->errstr;

    } else {
      $sth = $dbh->prepare("SELECT seq_id,domain,dssp FROM query WHERE dataset = \'$set\'") or die "ERROR! unable to SELECT: ", $dbh->errstr;
    }
  } else {       # select all the data
    $sth = $dbh->prepare("SELECT seq_id,domain,dssp FROM query") or die "ERROR! unable to SELECT: ", $dbh->errstr;
  }
  $sth->execute() or die "ERROR! unable to execute SELECT: ", $dbh->errstr;

  while ( my $row = $sth->fetchrow_arrayref ) {
    ## $row->[0] == seqID
    ## $row->[1] == domainID
    ## $row->[2] == dssp

    $data{ $row->[0] }{dom}  = $row->[1];
    $data{ $row->[0] }{dssp} = $row->[2];    # NB the DSSP data is in full format. Don't forget to reduce to 3-state if required.
  }
  $sth->finish;
  return ( \%data );
}

##################################################################################################################################
# Jia Geng
# get DSSP data from a directory containing one or more .dssp files.
# There is no seqID. Instead domain name is used as the key.
# %data = (
#   $domain => {dssp => "DSSP output"},
# );
#
sub get_DSSP_no_DB{

    my $path=shift;
    
    $path='/homes/adrozdetskiy/Projects/jpredJnet231ReTrainingSummaryTable/scores/training/' unless $path;

    my @files=glob "$path*.dssp";

    my %data; # key: domain name, value: a dssp string

    die $! unless (@files);

    foreach my $file (@files){
        my $base = basename ($file);
        open(FH, '<', $file) or die "unable to open $file. Died $! \n";
        my $domain;
        my $dssp;
        while (<FH>){
            chomp;
            if ($_=~/\>/){
                $domain=$';
                # chomp $domain;
            }
            else {
                $dssp=$_;
            }
        }
        die unless $domain and $dssp;
        die "Aborting. Inserting duplicate dssp for domain $domain\n" if exists $data{$domain};
        $data{$domain}{'dssp'} = $dssp;
    }

    return \%data;

}

##################################################################################################################################
#
# finds any predictions run under the same conditions as current run.
# Need to do this to avoid having duplicate results in the db.
#
sub check_DB {
  my ( $dbh, $db, $dSet, $pSet ) = @_;

  my $aref = $dbh->selectall_arrayref(
    "SELECT prediction.seq_id,pred_id
                                       FROM prediction,query
                                       WHERE prediction.seq_id = query.seq_id
                                       AND dataset = \'$dSet\'
                                       AND search_db = \'$db\'
                                       AND parameter_set = \'$pSet\'"
  ) or die "ERROR! unable to SELECT from prediction: ", $dbh->errstr;
  if ( scalar @$aref > 0 ) {
    printf "\nThere are already %d predictions using these parameters in the db. Do you want to: \n", scalar @$aref,;
    print "\n 1. Overwrite the results already in the db?\n";
    print " 2. Update new entries only?\n";
    print " 3. Add this run to the db anyway?\n";
    print " Q. Quit?\n\n";
    print "Please enter a choice [Q]: ";

    chomp( my $choice = <STDIN> );
    exit if !$choice;
    exit if $choice =~ /q/i;

    my %dbData;
    if ( $choice == 1 ) {    # remove prediction from db ready for insertion of new data

      my $sth = $dbh->prepare("DELETE FROM prediction WHERE pred_id = ?") or die "ERROR! unable to prepare DELETE: ", $dbh->errstr;
      my $rows = 0;
      foreach my $item (@$aref) {
        $rows += $sth->execute( $item->[1] ) or warn "Warning - unable to delete prediction no $item->[1]: ", $sth->errstr;
      }
      print "$rows rows deleted from db. Continue? [Y/n]: ";
      chomp( my $cont = <STDIN> );
      if ( $cont =~ /^n/i ) {
        exit;
      } else {
        return (0);
      }

    } elsif ( $choice == 2 ) {    # keep current predictions and add ones not already in db
      $dbData{ $_->[0] }++ foreach @$aref;
      return ( \%dbData );        # return the list of seqIDs already in db.

    } elsif ( $choice == 3 ) {    # ignore known data and add duplicate data.
      return (0);

    } else {
      print "Unrecognised option.\n";
      exit;
    }
  } else {
    return (0);
  }
}

##################################################################################################################################
# function to find the path for known sequence databases to search against
# takes a database handle and the db id as input
# returns the path to the database
#
sub db_path ($$) {
  my ( $dbh, $db ) = @_;

  my $sth = $dbh->prepare("SELECT path FROM db WHERE db_id = \'$db\'") or die "ERROR! unable to SELECT from db: ", $dbh->errstr;
  $sth->execute() or die "ERROR! can't execute SELECT on db: ", $sth->errstr;

  my @row_data = $sth->fetchrow_array or die "ERROR! in fetchrow: ", $sth->errstr;
  $sth->finish;
  return ( $row_data[0] );
}

##################################################################################################################################
#
# retrieve the sequences for a specific dataset from the jnet database.
#
# takes a database handle and a dataset name as input
#
# returns a ref to a 2D array where:
#    $ref->[0][0]  is the numeric seqID
#    $ref->[0][1]  is the protein sequence
#    $ref->[0][2]  is the domain
#    $ref->[0][3]  is the domain is for training (1) or not (0)
#
sub get_dataset ($$) {
  my ( $dbh, $dataset ) = @_;

  my $sth = $dbh->prepare("SELECT seq_id,seq,domain,train FROM query WHERE dataset = \'$dataset\'") or die "ERROR! unable to SELECT from db: ", $dbh->errstr;
  $sth->execute() or die "ERROR! can't execute SELECT on query: ", $sth->errstr;

  my $seqs = $sth->fetchall_arrayref or die "ERROR! in fetchall: ", $sth->errstr;
  $sth->finish;

  return ($seqs);
}

##################################################################################################################################
# retrieve the sequence ID from the domain ID
#
sub get_seqID {
  my $dbh   = shift;
  my $domID = shift;

  my $sth = $dbh->prepare("SELECT seq_id FROM query WHERE domain = \'$domID\'") or die "ERROR! unable to SELECT: ", $dbh->errstr;
  $sth->execute();
  my $row = $sth->fetchrow_arrayref;
  if ($row) {
    return ( $row->[0] );
  } else {
    return (0);
  }
}

##################################################################################################################################
# function to retrieve sequences by their internal IDs
#
sub get_seq {
  my $dbh   = shift;
  my $seqID = shift;

  my $sth = $dbh->prepare("SELECT seq FROM query WHERE seq_id = $seqID") or die "ERROR! unable to SELECT for $seqID: ", $dbh->errstr;
  $sth->execute();
  my $row = $sth->fetchrow_arrayref;
  if ($row) {
    return ( $row->[0] );
  } else {
    return (0);
  }
}

##################################################################################################################################
## get absolute accessibility data from DB
## Returns a reference to a hash with the seqID and
## accessibility data as key, value pairs:
#  %data = ($seqID => "abs accessibility", );
#
sub get_accDB {
  my $dbh = shift;
  my $set = shift;

  my %data;
  my $sth;
  if ($set) {    # select only a subset of the query data
    $sth = $dbh->prepare("SELECT seq_id,seq,acc,domain FROM query WHERE dataset = \'$set\'") or die "ERROR! unable to SELECT: ", $dbh->errstr;
  } else {       # select all the data
    $sth = $dbh->prepare("SELECT seq_id,seq,acc,domain FROM query WHERE acc IS NOT NULL") or die "ERROR! unable to SELECT: ", $dbh->errstr;
  }
  $sth->execute() or die "ERROR! unable to execute SELECT: ", $dbh->errstr;

  while ( my $row = $sth->fetchrow_arrayref ) {
    ## $row->[0] == seqID
    ## $row->[1] == sequence
    ## $row->[2] == accessibility
    ## $row->[3] == domain

    $data{ $row->[0] }{seq} = $row->[1];
    $data{ $row->[0] }{acc} = $row->[2];
    $data{ $row->[0] }{dom} = $row->[3];
  }
  $sth->finish;
  return ( \%data );
}

1;

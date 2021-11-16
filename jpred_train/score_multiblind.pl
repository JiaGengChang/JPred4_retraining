#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

=head1 NAME

score_multiblind -- script to combine the scores for n-fold corss-validated networks

=cut

use warnings;
use strict;
use Getopt::Long;

use lib '/homes/www-jpred/jnet_train/lib';

use Jpred::jnetDB;
use Jpred::Scores qw(score_simple);
use Jpred::Utils;

my $rootPath;
my $dataSet;

GetOptions(
  'path=s'    => \$rootPath,
  'dataset=s' => \$dataSet,
) or die;

die "Error - please give a file name to open\nDied" if ( !$rootPath );

## get blind set from DB
my $dbh = connect_DB('chris');
die "ERROR - database connection failed: ", $dbh->errstr if ( !$dbh );

my $sth = $dbh->prepare(
  "SELECT seq_id,dssp
                         FROM query
                         WHERE dataset = \'$dataSet\'
                         AND train = '0'"
)               or die "ERROR - unable to SELECT from db: ",      $dbh->errstr;
$sth->execute() or die "ERROR - can't execute SELECT on query: ", $sth->errstr;

my $rawDssp = $sth->fetchall_hashref(1) or die "ERROR - in fetchall: ", $sth->errstr;
$sth->finish;

die "ERROR - no data return from jnetDB\nDied" unless ( scalar keys %$rawDssp );

open( my $OUT, ">score_multiblind.csv" );

foreach my $seqID ( keys %$rawDssp ) {

  #print "$seqID\n";
  my $dssp = reduce_dssp( $rawDssp->{$seqID}{dssp} );

  #print "$dssp\n";

  ## go through each dataset and collate predictions for all the networks...?
  my @data;
  for my $i ( 1 .. 7 ) {
    my $file = "$rootPath/dataset$i/$seqID.jnet";
    if ( !-e $file ) {
      warn "Warning - '$file' not found. Skipping...\n";
      next;
    }
    open( my $fh, $file ) or die "ERROR - unable to open '$file': $!\nDied";
    my $pred = get_item( $fh, 'jnetpred' );
    $data[ $i - 1 ] = [ split //, $pred ];
    close($fh);

    #print "$pred ";
    #my $score = score_simple($pred, $dssp);
    #printf "%.2f\n", $score;
  }
  next if ( !@data );
  my $final = decide_majority(@data);

  #print "$final ";
  my $score = score_simple( $final, $dssp );
  printf $OUT "$seqID,%.2f\n", $score;

  #last;
}

sub decide_majority {
  my (@data) = @_;

  my $majority;
  my $length = scalar @{ $data[0] };

  #print "len: $length\n";
  #return;
  foreach my $i ( 0 .. $length - 1 ) {
    my %count;
    foreach my $j ( 0 .. $#data ) {
      die "ERROR - no data in array element '[$j][$i]'. Check that the predictions are the same length.\nDied" if ( !$data[$j][$i] );

      #print "$data[$j][$i]";
      $count{ $data[$j][$i] }++;
    }

    ## zero any types which don't exist. Avoids undefined variable errors in the if block below
    foreach my $type qw(H E -) {
      $count{$type} = 0 if ( !defined( $count{$type} ) );

      #   print " $count{$type}$type";
    }

    ## ascertain which type is most popular. Set to coil if a tie...
    if ( $count{H} > $count{E} && $count{H} > $count{'-'} ) {

      #print " -> H";
      $majority .= 'H';
    } elsif ( $count{E} > $count{H} && $count{E} > $count{'-'} ) {

      #print " -> E";
      $majority .= 'E';
    } elsif ( $count{'-'} > $count{H} && $count{'-'} > $count{E} ) {

      #print " -> -";
      $majority .= '-';
    } else {    # when no overall majority
      print "H: $count{H}  E: $count{E}  -: $count{'-'}\n";

      #print " -> -";
      $majority .= '-';
    }

    #print "\n";
  }

  die "ERROR - aggregate prediction not same length as inputs.\nDied" if ( length($majority) != $length );
  return ($majority);
}


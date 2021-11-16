#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

=head1 NAME

score_training.pl - script to calculate the prediction accuracy of a SNNS trained network

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Tie::IxHash;

use lib '/cluster/gjb_lab/2472402/jpred_train/lib';

use Jpred::jnetDB;
use Jpred::Scores;
use Jpred::Utils;
use SNNS::Pattern;

my $dbh     = connect_DB('jnet-user');
my $dsspAll = get_DSSP($dbh);
my $accData = get_accDB($dbh);
$dbh->disconnect;
die "ERROR - no DSSP found."              unless ( keys %$dsspAll );
die "ERROR - no accessibility data found" unless ( keys %$accData );

my $layer = 2;
my $options;
my $subType = 0;
my $dPath;
my $outFile = 'score_layer';
my $man;
my $help;

GetOptions(
  'layer=i' => \$layer,
  'type=s'  => \$options,
  'sub=i'   => \$subType,
  'data=s'  => \$dPath,
  'out=s'   => \$outFile,

  'help|?' => \$help,
  'man'    => \$man
) or pod2usage(0);

pod2usage( -verbose => 1 )                                         if ($help);
pod2usage( -verbose => 2 )                                         if ($man);
pod2usage( -msg     => 'Please specify the profile type to test' ) if ( !$options );
pod2usage( -msg     => 'Please specify the data path' )            if ( !$dPath );

##################################################################################################################################
my %prefix;
tie( %prefix, 'Tie::IxHash' );
my @extns = split /\,/, $options;
foreach my $type (@extns) {
  if ( $type eq 'all' ) {
    %prefix = qw(pssma pssm pssmb pssm hmm hmm);
    $extns[0] = 'hmm';
    last;
  }
  if ( $type =~ /hmm/i ) {
    $prefix{'hmm'} = 'hmm';
  }
  if ( $type =~ /freq/i ) {
    $prefix{'freq'} = 'freq';
  }
  if ( $type =~ /pssm/i ) {
    if ( ( $subType > 2 ) or ( $subType < 0 ) ) {
      pod2usage( -msg => "Invalid alignment sub-type ($subType). Please give a value of 0 (9 hidden nodes) or 1 (20 hidden nodes)", -verbose => 0 );
    }
    if ( $subType == 0 ) {
      $prefix{'pssma'} = 'pssm';
    } elsif ( $subType == 1 ) {
      $prefix{'pssmb'} = 'pssm';
    } else {
      $prefix{'pssma'} = 'pssm';
      $prefix{'pssmb'} = 'pssm';
    }
  }
  if ( $type =~ /align/i ) {
    if ( ( $subType > 2 ) or ( $subType < 0 ) ) {
      pod2usage( -msg => "Invalid alignment sub-type ($subType). Please give a value of 0 (BLOSUM) or 1 (Frequency)", -verbose => 0 );
    }
    if ( $subType == 0 ) {
      $prefix{'alignblosum'} = 'align';
    } elsif ( $subType == 1 ) {
      $prefix{'alignfreq'} = 'align';
    } else {
      $prefix{'alignblosum'} = 'align';
      $prefix{'alignfreq'}   = 'align';
    }
  }
  if ( $type =~ /hmmsol/i ) {
    $layer = 1;
    $prefix{$_} = 'hmm' foreach qw(hmmsol0 hmmsol5 hmmsol25);
    $extns[0] = 'hmm';
  }
  if ( $type =~ /psisol/i ) {
    $layer = 1;
    $prefix{$_} = 'pssm' foreach qw(psisol0 psisol5 psisol25);
    $extns[0] = 'pssm';
  }
}

##################################################################################################################################
# prepare output file
open( my $FL1, ">", "$outFile$layer.csv" ) or die "ERROR! unable to open file score_layer$layer.csv";
print $FL1 "SeqID,Domain";
print $FL1 ",$_" foreach ( keys %prefix );
print $FL1 "\n";

# if doing layer 2, do layer 1 at the same time
my $FL2;
if ( $layer == 2 ) {
  open( $FL2, ">${outFile}1.csv" ) or die "ERROR - unable to open file score_layer1.csv";
  print $FL2 "SeqID,Domain";
  print $FL2 ",$_" foreach ( keys %prefix );
  print $FL2 "\n";
}

my @files = glob "$dPath/*.$extns[0]";
die "No files of type $extns[0] found!" if ( !@files );
my %scoreData;
for my $file (@files) {

  my $root;
  if ( $file =~ /(\w+)\.$extns[0]/ ) {
    $root = $1;
  }

  # get DSSP data for sequence of interest and reduce to 3-state
  my $dssp = reduce_dssp( $dsspAll->{$root}{dssp} );
  die "ERROR - no DSSP data found for $root" if ( !$dssp );
  my @dsspData = split //, $dssp;

  # get accessibility data for sequence of interest
  my $acc = acc2rel( $accData->{$root}{acc}, $accData->{$root}{seq} );
  die "ERROR - no accessibility data found for $root. Check that it exists in the database." if ( !$acc );
  die "ERROR - lengths of DSSP and accessibility don't agree for $file" if ( scalar @$acc != length($dssp) );

  print $FL1 "$root,$dsspAll->{$root}{dom}";
  print $FL2 "$root,$dsspAll->{$root}{dom}" if ( $layer == 2 );

  foreach my $pre ( keys %prefix ) {
    my $inFile = "$dPath/$root.$prefix{$pre}";
    create_pattern( $inFile, $pre, \@dsspData, $layer );
    my $pred;
    my $pred1;
    if ( $pre =~ /sol/i ) {
      $pred = `./${pre}net -i $root.pat` or die "ERROR - unable to run './${pre}net -i $root.pat': $!";
      unlink("${root}.pat");
    } else {
      if ( $layer == 2 ) {
        $pred  = `./${pre}2net -i ${root}_2.pat` or die "ERROR - unable to run ${pre}2net for ${root}_2.pat";
        $pred1 = `./${pre}1net -i ${root}.pat`   or die "ERROR - unable to run ${pre}1net for ${root}.pat";
        unlink("${root}_2.pat");
        unlink("${root}.pat");
      } elsif ( $layer == 1 ) {
        $pred = `./${pre}1net -i ${root}.pat` or die "ERROR - unable to run ${pre}1net for ${root}.pat";
        unlink("${root}.pat");
      }
    }

    chomp($pred);

    my $score;
    my $mismatch;
    if ( $pre =~ /sol(\d+)/i ) {
      $score = calc_acc( $pred, $acc, $1 );
    } else {
      ( $score, $mismatch ) = calc_q3( $dssp, $pred, \%scoreData );

      printf "$root: lengths don't match %d vs %d\n", length($dssp), length($pred) if ($mismatch);
    }
    printf $FL1 ",%.2f", $score;

    # output layer 2 info also
    if ( $layer == 2 ) {
      chomp($pred1);
      ( $score, $mismatch ) = calc_q3( $dssp, $pred1, \%scoreData );

      printf "$root: lengths don't match %d vs %d\n", length($dssp), length($pred1) if ($mismatch);

      printf $FL2 ",%.2f", $score;
    }
  }
  print $FL1 "\n";
  print $FL2 "\n" if ( $layer == 2 );
}
close($FL1);
close($FL2) if ( $layer == 2 );

exit;

##################################################################################################################################

=head1 SYNOPSIS

score_training.pl -type <profile> [-sub <sub_profile>] -layer <layer no.> -data <path> [-out <file prefix>]

=head1 DESCRIPTION

This short script wraps-up nicely the process of calculating the prediction accuracy of an SNNS trained network.

It works out which binary and input files to use for the scoring and pregenerates pattern files required for each individual query.

It does this for both structure-based networks and solvent accessibility networks. 

The structure-based networks are I<pssm>, I<freq>, I<hmm> and I<align> and the solvent accessibility ones are I<hmmsol> and I<psisol>.

As the solvent accessibility networks are not multi-layered the -layer option is defunct.

=head1 OPTIONS

=over 8

=item B<-type> <profile>

Specify which profile type is going to be tested. Allowed options are: I<pssm>, I<freq>, I<hmm>, I<align>, I<all> , I<hmmsol> and I<psisol>. 

The I<all> options is to test all the networks on both layers, except the solvent accessibility ones.

There is no default.

=item B<-sub> <sub_profile>

Profile types 'align' and 'pssm' require a subtype to identify which particular network you want to test as two different networks are trained on these profile types. See below for details:

   sub-type   profile      network
   --------   -------      -------
   
      0        pssm        pssma (9 units in hidden layer)
      1        pssm        pssmb (20 units in hidden layer)
      0        align       alignblosum (BLOSUM62 matrix used to generate alignment profile)
      1        align       alignfreq (A simple frequency profile generated for alignments)
      2        pssm/align  do both sub-types for the relevant profile
      
Default: 0

=item B<-layer> <layer no.>

Specify which SNNS network layer to test. Layer 1 is the sequence to structure layer and Layer 2 is the structure to structure layer. 

For the I<hmmsol> and I<psisol> networks this option is meaningless and therefore defunct.

Default is: 2

=item B<-data> <path>

Give path to data for testing.

Default: /homes/chris/projects/Jnet/snns_training/data

=item B<--out> <file prefix>

Give a filename prefix for the output file(s). The output file will be named '<prefix><layer>.csv'. If the prefix 'file' is for layer 1 scoring then the output will be called 'file1.csv'.

This is optional.

Default is: score_layer

=item B<-help>

Show basic help.

=item B<-man>

Show full man page.

=back

=head1 NOTES

I have not tested the mixing of solvent accessibility scoring with structure network scoring so use with caution as unexpected results may occur. 

For best preformance score the structure networks separately from the solvent accessibility one. 
The added benefit of this is that the scoring job can be run as multiple jobs on the cluster.

=head1 AUTHOR

Chris Cole <christian@cole.name>

=cut

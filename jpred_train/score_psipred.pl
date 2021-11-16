#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

=head1 NAME

score_psipred.pl - script to score PSIPRED predictions on known datasets

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use File::Basename;

use lib '/homes/www-jpred/jnet_train/lib';

use Jpred::Scores qw(score_simple score_per_res);
use Jpred::jnetDB;
use Jpred::Utils 0.4;    # requires this version in order to use the 'hard' DSSP 8->3 state conversion

my $out = 'score_psipred.csv';
my $dataPath;
my $VERBOSE = 0;
my $DEBUG   = 0;
my $help;
my $man;

GetOptions(
  'data=s'   => \$dataPath,
  'out=s'    => \$out,
  'verbose!' => \$VERBOSE,
  'debug!'   => \$DEBUG,
  'man'      => \$man,
  'help|?'   => \$help,
) or pod2usage();

pod2usage( -verbose => 2 )                                         if ($man);
pod2usage( -verbose => 1 )                                         if ($help);
pod2usage( -msg     => 'Please supply a valid path to the data.' ) if ( !$dataPath or !-e $dataPath );

## get DSSP data from jnetDB;
my $dbh      = connect_DB('chris');
my $dsspData = get_DSSP($dbh);
$dbh->disconnect;

## get PSIPRED predictions files and score them
my @files = glob "$dataPath/*.ss2";
my $totScore;
open( my $OUT, ">", $out ) or die "ERROR - unable to open '$out' for write: ${!}\nDied";
foreach my $file (@files) {

  my $base = basename( $file, '.ss2' );
  my $pred = read_psipred($file);
  my $dssp = reduce_dssp( $dsspData->{$base}{dssp} );

  #print "$dssp\n";
  #print "$pred\n";
  die "ERROR - prediction and DSSP lengths differ\n" if ( length($pred) != length($dssp) );
  my $score = score_simple( $pred, $dssp );
  $totScore += $score;
  printf $OUT "$base,%.2f\n", $score;
}
close($OUT);
printf "Mean Q3: %.2f\n", $totScore / scalar @files;
exit;

sub read_psipred {
  my $file = shift;

  my $pred;
  open( my $PSI, "<", $file ) or die "ERROR - unable to open '$file': ${!}\nDied";
  while (<$PSI>) {
    if ( $. == 1 ) {
      die "ERROR - file '$file' not in a recognisable PSIPRED format\n " unless ( $_ =~ /^# PSIPRED VFORMAT/ );
    }
    next if (/^#/);
    next if (/^$/);

    my ( $resNum, @rest ) = split( /\s+/, $_ );
    my $letter = substr( $_, 7, 1 );
    die "ERROR - '$letter' not a valid secondary structure type at residue '$resNum'\n" if ( $letter !~ /C|E|H/ );
    $pred .= $letter;
  }
  $pred =~ s/C/-/g;
  return ($pred);
}

=head1 SYNOPSIS

score_psipred.pl --data <path> [--out <file>] [--verbose] [--debug] [--man] [--help]

=head1 DESCRIPTION

Only use this for PSIPRED predictions made on datasets already found in jnetDB.

The script looks for *.ss2 files found in the given I<--data> path. The basename of the .ss2 files must correspond to the correct 'seq_id' in the 'query' table of jnetDB.

Generates a CSV file with all the individual Q3 scores, plus outputs an overall Q3.

=head1 OPTIONS

=over 5

=item B<--data>

Path to *.ss2 PSIPRED files.

=item B<--out>

Output filename. [default: score_psipred.csv]

=item B<--verbose|--no-verbose>

Toggle verbosity. [default:none]

=item B<--debug|--no-debug>

Toggle debugging output. [default:none]

=item B<--help>

Brief help.

=item B<--man>

Full manpage of program.

=back

=head1 AUTHOR

Chris Cole <christian@cole.name>

=cut

#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

=head1 NAME

get_dssp_from_db.pl - retrieve DSSP definitions from Jnet database

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use File::Basename;

use lib '/homes/www-jpred/jnet_train/lib';

use Jpred::jnetDB 0.2;
use Jpred::Utils 0.4;    # requires this version in order to use the 'hard' DSSP 8->3 state conversion

my $dataset;
my $subset;
my $out      = 'out.dssp';
my $fullDssp = 0;
my $VERBOSE  = 0;
my $DEBUG    = 0;
my $help;
my $man;

GetOptions(
  'subset=s'  => \$subset,
  'dataset=s' => \$dataset,
  'full-dssp' => \$fullDssp,
  'verbose!'  => \$VERBOSE,
  'debug!'    => \$DEBUG,
  'out=s'     => \$out,
  'man'       => \$man,
  'help|?'    => \$help,
) or pod2usage();

pod2usage( -verbose => 2 )                                                                               if ($man);
pod2usage( -verbose => 1 )                                                                               if ($help);
pod2usage( -msg     => "ERROR - --subset defined, but not --dataset. Please specify a dataset as well" ) if ( $subset and !$dataset );
pod2usage( -msg     => "ERROR - subset '$subset' unknown please specify one of 'blind' or 'training'" )  if ( defined($subset) and $subset !~ /blind|training/ );

my $dbh = connect_DB('chris');
die "ERROR - unable to connect to Jnet BD\n" unless ($dbh);
my $dssp = get_DSSP( $dbh, $dataset, $subset );
die "ERROR - no DSSP definitions found for dataset '$dataset'\n" unless ( scalar keys %$dssp );

#printf "Found %d DSSP definitions\n", scalar keys %$dssp;

open( my $OUT, ">", $out ) or die "ERROR - unable to open '$out' for write: ${!}\nDied";
foreach my $id ( sort { $a <=> $b } keys %$dssp ) {
  if ($fullDssp) {
    print $OUT ">$id $dssp->{$id}{dom}\n$dssp->{$id}{dssp}\n";
  } else {
    printf $OUT ">$id $dssp->{$id}{dom}\n%s\n", reduce_dssp( $dssp->{$id}{dssp} );
  }
}

=head1 SYNOPSIS

get_dssp_from_db.pl [--dataset <name> [--subset <blind|training>]] [--full-dssp] [--out <file>] [--verbose] [--debug] [--man] [--help]

=head1 DESCRIPTION

All the data used to train Jnet is stored in the 'jnet' MySQL database at the usual host. Once a dataset has been created it is stored in the database and all training, testing and scoring is done via the database.

This script downloads DSSP data from the database and writes to file any or all training sets available.

The output format is pseudo-Fasta, where the internal sequence ID is used as the main identifier and the SCOP/Astral domain ID used as the description followed by the DSSP 'sequence' below:

  >8692 d1ijva_
  -HHHHHHTT-EEESS---TT--EEEEETTTTEEEE-

=head1 OPTIONS

=over 5

=item B<--dataset>

Specific dataset to retrieve. [default: all]

item B<--subset>

Specify whether the 'blind' and 'training' subset to retrieve. Must be used in conjuction with --dataset.

=item B<--full-dssp>

Return the full 8-state DSSP definitions. Normally only 3-state is returned.

=item B<--out>

Specify an output file.[default:'out.dssp']

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

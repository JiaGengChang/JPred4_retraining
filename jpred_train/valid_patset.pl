#!/cluster/gjb_lab/2472402/miniconda/envs/jnet_train/bin/perl


=head1 NAME

valid_patset.pl -- Script to create SNNS validation set for use during training

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

use lib qw(/cluster/gjb_lab/2472402/jpred_train/lib);

use Jpred::jnetDB;
use Jpred::Utils;
use SNNS::Pattern;
use SNNS::Network;

my $workDir = '.';    # working directory

my $dataDir;                                                           # location of data files
my $numElements = 20;                                                  # number of data elements per residue
my $flank;                                                             # size of flanking regions in sliding window
my $profileType;                                                       # type of profile to create (user input)
my $subType = 0;                                                       # subtype of profile (user input)
my $prefix;                                                            # output name for network-related files
my $layer = 2;                                                         # layer to train
my $help;
my $man;

GetOptions(
  'flank=i' => \$flank,
  'type=s'  => \$prefix,
  'sub=i'   => \$subType,
  'dir=s'   => \$workDir,
  'data=s'  => \$dataDir,
  'layer=i' => \$layer,
  'help|?'  => \$help,
  'man'     => \$man
) or pod2usage(0);

pod2usage( -verbose => 2 ) if $man;
pod2usage( -verbose => 1 ) if $help;
pod2usage( -msg => 'Please give the location of the data',                   -verbose => 0 ) if !$dataDir;
pod2usage( -msg => 'Please give a profile type to train on',                 -verbose => 0 ) if !$prefix;
pod2usage( -msg => 'Invalid layer. Try again with a valid number (1 or 2).', -verbose => 0 ) if ( ( $layer < 1 ) || ( $layer > 2 ) );

######################################################################################################################################################
# Go to working directory
chdir($workDir) or die "ERROR - unable to cd to \'$workDir\': $!";

# Depending on the output network name set which input profile to use and number of data elements to expect.
my %profs = qw(hmm hmmprof freq freq pssma pssm pssmb pssm alignblosum align alignfreq align);
$profileType = $profs{$prefix};
die "ERROR - $prefix unrecognised" unless ($profileType);
if ( $profileType eq 'hmmprof' ) {
  $numElements = 24;
} elsif ( $profileType eq 'align' ) {
  $numElements = 25;
}

## Set subtype if required
$subType = 1 if ( ( $prefix eq 'alignfreq' ) or ( $prefix eq 'pssmb' ) );

## get files to train against
my @files = glob "$dataDir/*.$profileType"; # original. use this for pssm
## my @files = glob "$dataDir/*.$prefix"; # use this if running for hmm
die "ERROR - no files found" if ( !@files );

## Retrieve DSSP data from Jnet DB
my $dbh      = connect_DB('jnet-user');
my $dsspData = get_DSSP($dbh);
die "ERROR - no DSSP data found" unless ( keys %$dsspData );
$dbh->disconnect;

## set layer-specific variables
if ( $layer == 1 ) {
  $flank = 8;
} elsif ( $layer == 2 ) {
  $flank = 9;
  if ( $profileType =~ /align/i ) {
    $numElements = 4;
  } else {
    $numElements = 3;
  }
}

## Write the patterns to file and add the dssp output pattern as well.
## Doing this here, as storing all the data in RAM for later dumping is too memory inefficient.
## Need to edit the file at the end to substitute NNN with the real number of input patterns.
print "Writing out SNNS pattern file...\n";
my $patFile = "$prefix${layer}_valid.pat";
my $fh = write_new( $patFile, 'NNN', ( $numElements * ( 2 * $flank + 1 ) ) );

######################################################################################################################################################
## get pattern data
printf "Reading in %d files and extracting data...\n", scalar @files;
my $totPats = 0;
foreach my $dataf (@files) {

  my @pattern;
  my @dsspOut;

  my $root;
  my $extn;
  if ( $dataf =~ /(\w+)\.(\w+)/ ) {
    $root = $1;
    $extn = $2;
  } else {
    die "ERROR - can't parse filename for \'$dataf\'";
  }

######################################################################################################################################################
  ## retrieve raw data
  my $data;
  if ( $profileType eq 'align' ) {
    ## parse the PSI-BLAST alignment and create a 2D array with the
    ## sequence number as the 1st dimension and the residue as the
    ## 2nd dimension.
    my $align = get_alignment($dataf);

    ## calculate the Conservation Score from the alignment as per Zvelebil et al, JMB (1987) 195, 957-961
    my @consScore = calc_cons($align);

    if ( $layer == 1 ) {
      ## generate the data from the alignment and Conservation Score
      ## $subType: 0 = BLOSUM profile and 1 = Frequency profile
      $data = get_psi_data( $align, \@consScore, $subType );
    } elsif ( $layer == 2 ) {
      ## get prediction from layer 1 network and convert into input data.
      $data = get_pred( $dataf, $root, @consScore );
    }

  } else {
    if ( $layer == 1 ) {
      ## retrieve the profile data from the input fileand return as
      ## reference to an AoA
      $data = get_data( $dataf, $extn );
    } elsif ( $layer == 2 ) {
      ## get prediction from layer 1 network and convert into input data.
      $data = get_pred( $dataf, $root );
    }
  }
  die "ERROR - no data found for $dataf" unless ( scalar @{$data} );

  ## get DSSP data for the profile in question and reduce down to 3-state definitions.
  ## Return false if nothing done.
  my $dssp = reduce_dssp( $dsspData->{$root}{'dssp'} );
  die "ERROR - no DSSP data found for $root. Check that it exists in the database." if ( !$dssp );
  die "ERROR - lengths of input and DSSP don't agree for $dataf" if ( length($dssp) != scalar @$data );

  ## concatenate DSSP data with all the others
  push @dsspOut, split //, $dssp;

  ## collate pattern data for current structure and add to others
  $totPats += pattern_data( $data, \@pattern, 0, $flank );

  foreach my $pat ( 0 .. $#pattern ) {
    print $fh "# Input ${root}_$pat:\n";
    foreach my $data ( @{ $pattern[$pat] } ) {
      print $fh "$data ";
    }
    print $fh "\n# Output ${root}_$pat:\n";
    if ( $dsspOut[$pat] eq 'H' ) {
      print $fh "0 1 0";
    } elsif ( $dsspOut[$pat] eq 'E' ) {
      print $fh "1 0 0";
    } elsif ( $dsspOut[$pat] eq '-' ) {
      print $fh "0 0 1";
    } else {
      die "ERROR - disallowed dssp character: \'$dsspOut[$pat]\' at position $pat\n";
    }
    print $fh "\n";
  }
}
close($fh);

######################################################################################################################################################
## Horrible fudge to add the number of input patterns to the SNNS pattern file.
## Need to do it this way as we can't know beforehand how many there are.
system("perl -i -pe 's/NNN/$totPats/' $patFile") == 0 or die "ERROR - unable to edit $patFile";

print "Finished!\n";
exit;

######################################################################################################################################################
sub get_pred {
  my ( $file, $root, @score ) = @_ or return;

  my $dssp = reduce_dssp( $dsspData->{$root}{'dssp'} );
  my @dsspData = split //, $dssp;
  create_pattern( $file, $prefix, \@dsspData );
  my $pred = `./${prefix}1net -i $root.pat` or die "ERROR - prediction failed for $root.pat";
  unlink("$root.pat");
  chomp($pred);

  my $data = map_struct( $pred, \@score );
  return ($data);
}

=head1 SYNOPSIS

gen_snns_input.pl --flank <size> --type <pattern type> --sub <pattern subtype> --dir <working dir> --layer <no.>

=head1 DESCRIPTION

The script does the non-trivial act of taking pre-generated data and turns it into patterns for Neural Network training with the SNNS program. The training is also done within the script and output files are generated ready to be plugged into the JNet program.

By giving the script a pattern type it searches for all files of that type and generates the appropriate pattern and network files ready for SNNS training. The file type is defined by its extension:

   .hmmprof   HMMer profile
   .freq      frequency profile
   .pssm      PSSM profile derived from PSI-BLAST. This requires a subtype as two networks which differ by the number of hidden nodes.
   .align     multiple sequence alignment in FASTA format generated from the PSI-BLAST output. This requires a subtype to be defined as Jnet uses the alignment to generate Frequency and BLOSUM profiles, with different networks trained for each.

The script creates nine files per trained layer:

   type_blank.net    a template network of the right size for input to SNNS
   type.net    the trained network
   type.c/h    the C code and header files generated by snns2c from the trained network file (above)
   type.bat    an SNNS batch file with the training parameters (where 'type' is the same as the --type argument)
   type.pat    the SNNS pattern which holds all the pattern data for training
   {type}net.c basic C code to take a pattern file for a sequence and apply the network against it to create a prediction
   {type}net   compile code of the above.

Where 'type' is the name of the profile suffixed by the layer number e.g. hmm2. Generally only type.c/h and {type}net files will be of interest.

=head1 OPTIONS

=over 8

=item B<--flank> <size>

Define the size of the flanking regions to give an overall size for the sliding window = (2x flank) + 1 .

Default is 8 (giving a window size of 17)

=item B<--type> <pattern type>

Define which pattern type to train against. There are four options: hmmprof, freq, pssm, alignment

There's no default.

=item B<--sub> <pattern subtype>

For the 'align' patterns defined above there is an additional option to define which subtype of alignment profile do you require. For BLOSUM62 use 0 and for Frequency use 1.

Default is 0 (BLOSUM62)

For the 'pssm' patterns the subtype defines the number of hidden nodes to use during training. For 9 hidden nodes use 0 and for 20 hidden nodes use 1.

Default is 0 (9 nodes)

=item B<--dir> <working dir>

Set the working directory for the training file. 

Default: /homes/chris/projects/Jnet/snns_training/test_work

=item B<--layer> <no.>

Set which network layer to train. Use 1 for the sequence to structure networks and 2 for the structure to structure networks.

Default: 2

=item B<--help>

Show brief help.

=item B<--man>

Show more detailed information and backgound.

=back

=head1 AUTHOR

Chris Cole <christian@cole.name>

=cut

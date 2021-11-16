#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

=head1 NAME

create_pattern.pl -- Script to generate an SNNS pattern file for testing

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

use lib '/homes/2472402/jpred/lib';

use Jpred::jnetDB;
use Jpred::Utils;
use SNNS::Pattern;
use Fasta::Utils;

#use SNNS::paths;

my $l1Path = '.';
my $layer  = 1;
my $file;
my $flank   = 8;
my $subType = 0;
my $help;
my $man;

GetOptions(
  'layer=i' => \$layer,
  'path=s'  => \$l1Path,
  'in=s'    => \$file,
  'flank=i' => \$flank,
  'sub=i'   => \$subType,
  'help|?'  => \$help,
  'man'     => \$man
) or pod2usage(0);

pod2usage( -verbose => 2 ) if $man;
pod2usage( -verbose => 1 ) if $help;
pod2usage( -msg => 'Please give on input file with which to generate a pattern file', -verbose => 0 ) if !$file;
pod2usage( -msg => "Invalid alignment sub-type ($subType). Please give a value of 0 (BLOSUM) or 1 (Frequency)", -verbose => 0 ) if ( ( $subType > 1 ) or ( $subType < 0 ) );

## extract root and extension of filename where $root is the
## same as the seqID for the sequence in Jnet DB
my $root;
my $extn;
if ( $file =~ /(\w+)\.(\w+)/ ) {
  $root = $1;
  $extn = $2;
}

## define the name of the network binary as this varies by input profile type.
my $netBinary;
if ( $extn =~ /pssm/i ) {
  if ( $subType == 0 ) {
    $netBinary = 'pssma1net';
  } else {
    $netBinary = 'pssmb1net';
  }
} elsif ( $extn =~ /freq/i ) {
  $netBinary = 'freq1net';
} elsif ( $extn =~ /hmmprof/i ) {
  $netBinary = 'hmm1net';
} elsif ( $extn =~ /align/i ) {
  if ( $subType == 0 ) {
    $netBinary = 'alignblosum1net';
  } else {
    $netBinary = 'alignfreq1net';
  }
} else {
  die "ERROR - unrecognised extension \'$extn\'";
}

my $data;
if ( $extn eq 'align' ) {
  ## parse the PSI-BLAST alignment and create a 2D array with the
  ## sequence number as the 1st dimension and the residue as the
  ## 2nd dimension.
  my $seqs = parse( $file, 1 );
  die "ERROR - no sequences found in file: $file" unless ( keys %{$seqs} );
  my @align;
  my $numSeqs = 0;
  foreach my $seqID ( keys %{$seqs} ) {
    $align[$numSeqs] = [ split //, $seqs->{$seqID}{seq} ];
    ++$numSeqs;
  }
  ## calculate the Conservation Score from the alignment as per Zvelebil et al, JMB (1987) 195, 957-961
  my @consScore = calc_cons( \@align );

  ## generate the data from the alignment and Conservation Score
  ## THe final argument defines whether it's a Frequency profile or BLOSUM (1=Freq, 0 = BLOSUM)
  $data = get_psi_data( \@align, \@consScore, $subType );
} else {
  ## retrieve the profile data from the input fileand return as
  ## reference to an AoA
  $data = get_data( $file, $extn );
}

## retreive DSSP data for the
my $dbh     = connect_DB('jnet-user');
my $dsspAll = get_DSSP($dbh);
my $dssp    = $dsspAll->{$root}{dssp};
$dbh->disconnect();

my @dssp = split //, reduce_dssp($dssp);

## prepare pattern data...
my @inPat;
pattern_data( $data, \@inPat, 0, $flank );

## ...and write out to file.
my $fh = write_new( "$root.pat", scalar @inPat, scalar @{ $inPat[0] } );

select($fh);

foreach my $pat ( 0 .. $#inPat ) {
  print "# Input $pat:\n";
  foreach my $value ( @{ $inPat[$pat] } ) {
    print "$value ";
  }
  print "\n# Output $pat:\n";
  if ( $dssp[$pat] eq 'H' ) {
    print "0 1 0";
  } elsif ( $dssp[$pat] eq 'E' ) {
    print "1 0 0";
  } elsif ( $dssp[$pat] eq '-' ) {
    print "0 0 1";
  } else {
    die "ERROR - disallowed dssp character: \'$dssp[$pat]\' at position $pat\n";
  }
  print "\n";
}
close($fh);

## stop here if only doing a layer 1 pattern
exit if ( $layer == 1 );

#########################
#                       #
#   LAYER 2 PATTERNS    #
#                       #
#########################

## otherwise continue to generate a layer 2 pattern
select(STDOUT);
my $pred = `$l1Path/$netBinary -i $root.pat` or die "ERROR - prediction failed";
chomp($pred);

#print "pred: $pred\n";
my @pred = split //, $pred;

my $predData;
if ( $extn eq 'align' ) {
  ## get fasta alignment and store in a 2D array.
  die "ERROR - $file: No such file or directory" if ( !-e $file );
  my $seqs = parse( $file, 1 );
  my @align;
  my $c = 0;
  foreach my $seqID ( keys %{$seqs} ) {
    $align[$c] = [ split //, $seqs->{$seqID}{seq} ];
    ++$c;
  }

  ## calculate the Conservation Score as per Zvelebil et al, JMB (1987) 195, 957-961
  my @consScore = calc_cons( \@align );

  if ( scalar @pred != scalar @consScore ) {
    die "ERROR - length of the alignment is not the same as the prediction";
  }
  ## function to map secondary structure to an array of outputs for SNNS
  $predData = map_struct( $pred, \@consScore );
} else {
  ## function to map secondary structure to an array of outputs for SNNS
  #$predData = map_raw_pred($pred);
  $predData = map_struct($pred);
}

## collate input and output data and return patterns for each ready to write to file
@inPat = ();
$flank = 9;
pattern_data( $predData, \@inPat, 0, $flank );

## write out the pattern file
$fh = write_new( "${root}_2.pat", scalar @inPat, ( scalar @{ $inPat[0] } ) );

select($fh);

foreach my $pat ( 0 .. $#inPat ) {
  print "# Input $pat:\n";
  foreach my $value ( @{ $inPat[$pat] } ) {
    print "$value ";
  }
  print "\n# Output $pat:\n";
  if ( $dssp[$pat] eq 'H' ) {
    print "0 1 0";
  } elsif ( $dssp[$pat] eq 'E' ) {
    print "1 0 0";
  } elsif ( $dssp[$pat] eq '-' ) {
    print "0 0 1";
  } else {
    die "ERROR - disallowed secondary structure character: \'$dssp[$pat]\' at position $pat ($netBinary)\n";
  }
  print "\n";
}
close($fh);
exit;

=head1 SYNOPSIS

create_pattern.pl --in <file> --flank <size of flank> --layer <layer no.> --path <dir for layer 1 bins>

=head1 DESCRIPTION

This script was written for the generation of pattern files for particular profile inputs.

This is all part of the JNet training scheme where a trained neural networks needs to have intput pattern files to test against to check that the training working.

Briefly, the script is given a file containing profile data from HMMer or PSI-BLAST outputs or others as required. Then the script creates an SNNS pattern file to test against a suitably trained neural net.

=head1 OPTIONS

=over 8

=item B<--in> <file>

Name of file contain profile data. The extension must be one of the ones recognised by the script:

 hmmprof  HMMer profile generated from a PSI-BLAST alignment
 freq     Frequency profile also generated from a PSI-BLAST alignment
 pssm     PSSM profile as extracted from the PSI-BLAST output
 
=item B<--flank> <size>

You can alter the size of the flanking regions in the sliding window in the pattern generation. The window size ends up being twice the size of the flanking regions plus one e.g. --flank 4 results in a window size of 9.

Default is: 8 for layer 1 and 9 for layer 2.

NB: this hasn't been tested yet and argument will probably only work for layer 1 patterns for the moment.

=item B<--layer> <layer no.>

Specify which SNNS network layer pattern to create. Layer 1 is the sequence to structure layer and Layer 2 is the structure to structure layer. 

Default is: 1.

=item B<--path> <dir fro layer 1 bins>

Give location of layer 1 network binaries.

Default is: current dir

=item B<--help>

Show basic help.

=item B<--man>

Show full man page.

=back

=head1 AUTHOR

Chris Cole <christian@cole.name>

=cut

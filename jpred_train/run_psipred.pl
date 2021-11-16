#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

=head1 NAME

run_psipred.pl - script to run PSIPRED predictions on known data.

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use File::Basename;

use lib '/homes/www-jpred/jnet_train/lib';
use Cluster::ArrayJob;
use Fasta::Utils;

my $out = 'sge_list.dat';
my $infile;
my $dataset;
my $VERBOSE = 1;
my $DEBUG   = 0;
my $help;
my $man;

GetOptions(
  'in|file=s' => \$infile,
  'dataset=s' => \$dataset,

  'verbose!' => \$VERBOSE,
  'debug!'   => \$DEBUG,
  'man'      => \$man,
  'help|?'   => \$help,
) or pod2usage();

pod2usage( -verbose => 2 ) if ($man);
pod2usage( -verbose => 1 ) if ($help);
pod2usage( -msg => 'Please supply a valid fasta file.', -verbose => 0 ) if ( $infile   && !-e $infile );
pod2usage( -msg => 'Please supply a dataset name.',     -verbose => 0 ) if ( !$dataset && !$infile );

die "ERROR! not on an SGE aware machine.\n"              unless ( $ENV{SGE_ROOT} );
die "ERROR! BLASTMAT environment variable not defined\n" unless ( $ENV{BLASTMAT} );
die "ERROR! BLASTDB environment variable not defined\n"  unless ( $ENV{BLASTDB} );

##################################################################################################################################
my $count;
if ($infile) {    # get data from file
  my $seqs = parse( $infile, 1 );
  die "ERROR! no sequences found in '$infile'\n" unless ( scalar keys %$seqs );
  printf "Found %d sequences in '$infile'\n", scalar keys %$seqs;

  ## create fasta files for sequences and SGE taskID mapping file
  open( my $SGE, ">", $out ) or die "ERROR! unable to open '$out' for write: ${!}\nDied";
  $count = 0;
  foreach my $prot ( keys %$seqs ) {
    ++$count;
    printf $SGE "$count %s\n", $prot;

    my $file = $prot . ".fasta";
    open( my $FAS, ">", $file ) or die "ERROR! unable to open '$file' for write: ${!}\nDied";
    printf $FAS ">$prot\n%s\n", $seqs->{$prot}{seq};
    close($FAS) or die "ERROR! unable to close '$file': $!\n";
  }
  close($SGE);
} else {    # get data from mysql
  ## connect to DB and get blind data for specified dataset
  my $dbh = connect_DB('chris');
  die "ERROR! failed to connect!" unless ($dbh);

  my $list = $dbh->selectall_arrayref(
    "SELECT seq_id,domain,seq FROM query 
                              WHERE dataset = '$dataset' 
                              AND train = 0 
                              ORDER BY seq_id"
  ) or die "ERROR! SQL select failed: ", $dbh->errstr;

  my $num = scalar @$list;
  die "ERROR! no 'blind' sequences found for dataset '$dataset'. Did you specify the correct name?\n" unless ($num);
  print "Found $num in blind set\n" if $DEBUG;

  ## create fasta files for sequences and SGE taskID mapping file
  open( my $SGE, ">", $out ) or die "ERROR! unable to open '$out' for write: ${!}\nDied";
  $count = 0;
  foreach my $prot (@$list) {
    ++$count;
    printf $SGE "$count %s\n", $prot->[0];

    my $file = $prot->[0] . ".fasta";
    open( my $FAS, ">", $file ) or die "ERROR! unable to open '$file' for write: ${!}\nDied";
    printf $FAS ">%s\n%s\n", $prot->[1], $prot->[2];
    close($FAS) or die "ERROR! unable to close '$file': $!\n";
  }
  close($SGE);
}

##################################################################################################################################
# write perl script ready for submission
my $scriptName = 'psipred.pl';
write_script($scriptName);

## set up Array Job and submit perl script
## Just use all the defaults.
print "Submitting $count PSIPRED tasks to the cluster as an array job...\n" if $VERBOSE;
my $sgeArray = Cluster::ArrayJob->new();
$sgeArray->taskRange("1-$count");
$sgeArray->setCWD();
$sgeArray->setEnv( 'BLASTMAT' => $ENV{BLASTMAT}, 'BLASTDB' => $ENV{BLASTDB} );
$sgeArray->submit($scriptName) or die "ERROR! job not submitted because of: ", $sgeArray->error(), "\n";

print "Checking status of array job...\n" if $VERBOSE;
while (1) {
  my $status = $sgeArray->getStatus() or die "ERROR! unable to get SGE job status: ", $sgeArray->error();
  if ( $status eq '-1' ) {
    print "Job has finished\n" if $VERBOSE;
    last;
  } elsif ( $status eq '1' ) {
    die "ERROR! unable to get SGE job status: ", $sgeArray->error();
  } else {
    my $out = '';
    foreach my $k ( sort keys %$status ) {
      $out .= " $k:" . $status->{$k};
    }
    print "Job status: $out\n" if $VERBOSE;
  }
  sleep(30);
}

## Finally, check that all jobs completed successfully.
my $jobID = $sgeArray->jobid();
my @files = glob "$scriptName.e$jobID.*";

my $errors = 0;
## check that the correct number of files exist - should be the same as the number of tasks
my $nFiles = scalar @files;
if ( $nFiles != $count ) {
  warn "WARNING! found $nFiles SGE output files where $count expected\n";
  ++$errors;
}

##################################################################################################################################
# check for any non-empty sge error files
foreach my $file (@files) {
  if ( !-z $file ) {
    if ( $file =~ /$scriptName\.e$jobID\.(\d+)/ ) {
      warn "WARNING! task $1 had errors\n";
      ++$errors;
    } else {
      warn "WARNING! '$file' SGE error file is non-empty (couldn't extract the task ID!)\n";
      ++$errors;
    }
    next;
  }
  unlink($file);
}
print "No errors found\n" unless ($errors);
exit;

##################################################################################################################################
# write out perl script for running psipred.
# need this extra script as the fasta file names are not sequential,
# so must do a mapping between the SGE taskID and the fasta name
sub write_script {
  my $file = shift;

  open( my $OUT, ">$file" ) or die "ERROR! unable to open file '$file': $!\n";
  while (<DATA>) {
    print $OUT $_;
  }
  close($OUT);
}

##################################################################################################################################

=head1 SYNOPSIS

run_psipred.pl -file|-in <fasta> -dataset <name> [-verbose] [-debug] [-man] [-help]

=head1 DESCRIPTION

This script should be used to generate PSIPRED predictions on a known dataset for comparison with Jpred/Jnet. 
Ideally, it retrieves sequence data from the JnetDB database. However, it can also take a fasta file containing 
multiple sequences as input. Thus, the script should be used with either -file or -dataset switches, not both. 
If you do provide both, only the --fasta option is used. 

With a valid dataset name, the script retrieves the 'blind' portion of the DB, creates a Fasta file for each 
sequence and submits PSIPRED jobs to the cluster.

With a Fasta input, the script splits the sequences into individual fasta files and treats them as above.

The script ends once the jobs have finished running and will report if any completed with errors.

=head1 OPTIONS

=over 5

=item B<-fasta FILE>

Specify a fasta file with protein domains

=item B<-dataset NAME>

Specify which dataset to retrieve sequence data from the Jnet DB

=back

=head1 TECHNICAL OPTIONS

=over 15

=item B<-verbose|-no-verbose>

Toggle verbosity. [default:on]

=item B<-debug|-no-debug>

Toggle debugging output. [default:none]

=item B<-help>

Brief help.

=item B<-man>

Full manpage of program.

=back

=head1 AUTHOR

Chris Cole <christian@cole.name>

=cut

__DATA__
#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

use strict;
use warnings;

my $file = 'sge_list.dat';
my $pwd = $ENV{PWD};              # get current directory
my $dir = $ENV{TMPDIR};           # get SGE tmpdir
my $task = $ENV{'SGE_TASK_ID'};   # get SGE array task ID
die "ERROR! not in SGE array job context. Please submit as an array job.\n" if (!$task or $task eq 'undefined');

## open file with SGE job task ID to sequence ID mappings
open(my $LST, "<", $file) or die "ERROR! unable to open $file: ${!}\nDied";
my $doThisOne = 0;
while(<$LST>) {
   chomp;
   my ($id, $job) = split;
   if ($id == $task) {
      $doThisOne = $job;
      last;
   }
}
close($LST);

die "ERROR! task id '$task' not found in '$file'. Check you're using the correct task range\n" unless ($doThisOne);

my $cmd = "cd $dir && /homes/ccole/NOBACK/exbin/psipred/runpsipred $pwd/$doThisOne.fasta";
print "Running CMD: $cmd\n";
system($cmd) == 0 or die "ERROR! system() died\n";
print "Copying files back...";
system("cp $dir/$doThisOne.* $pwd/") ==0 or die "ERROR! system() died\n";
print "Done\n";

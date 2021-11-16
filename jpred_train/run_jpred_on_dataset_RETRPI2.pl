#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

=head1 NAME

run_jpred_on_dataset.pl - script to run Jpred on jnetDB datasets

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use File::Basename;

use lib '/homes/www-jpred/jnet_train/lib';
use Jpred::jnetDB;
use Cluster::ArrayJob;

my $out = 'sge_list.dat';
my $dataset;
my $subset;
my $VERBOSE = 1;
my $DEBUG   = 0;
my $help;
my $man;

GetOptions(
  'dataset=s' => \$dataset,
  'subset=s'  => \$subset,

  'verbose!' => \$VERBOSE,
  'debug!'   => \$DEBUG,
  'man'      => \$man,
  'help|?'   => \$help,
) or pod2usage();

pod2usage( -verbose => 2 ) if ($man);
pod2usage( -verbose => 1 ) if ($help);
pod2usage( -msg => 'Please supply a dataset name.', -verbose => 0 ) if ( !$dataset );
pod2usage( -msg => 'Please supply a valid subset [blind|training].', -verbose => 0 ) if ( $subset and ( $subset ne 'blind' and $subset ne 'training' ) );

##################################################################################################################################
# connect to DB and get blind data for specified dataset
my $dbh = connect_DB('chris');
die "ERROR! failed to connect!" unless ($dbh);

my $list;
if ($subset) {
  my $train = 1;
  $train = 0 if ( $subset eq 'blind' );

  $list = $dbh->selectall_arrayref(
    "SELECT seq_id,domain,seq FROM query 
                              WHERE dataset = '$dataset' 
                              AND train = '$train' 
                              ORDER BY seq_id"
  ) or die "ERROR! select failed: ", $dbh->errstr;
} else {
  $list = $dbh->selectall_arrayref(
    "SELECT seq_id,domain,seq FROM query 
                              WHERE dataset = '$dataset' 
                              ORDER BY seq_id"
  ) or die "ERROR! select failed: ", $dbh->errstr;
}

my $num = scalar @$list;
die "ERROR! no 'blind' sequences found for dataset '$dataset'. Did you specify the correct name?\n" unless ($num);
print "Found $num in blind set\n" if $DEBUG;

##################################################################################################################################
# create fasta files for sequences and SGE taskID mapping file
open( my $SGE, ">", $out ) or die "ERROR! unable to open '$out' for write: ${!}\nDied";
my $count = 0;
foreach my $prot (@$list) {
  ++$count;
  printf $SGE "$count %s\n", $prot->[0];

  my $file = $prot->[0] . ".fasta";
  open( my $FAS, ">", $file ) or die "ERROR! unable to open '$file' for write: ${!}\nDied";
  printf $FAS ">%s\n%s\n", $prot->[1], $prot->[2];
  close($FAS) or die "ERROR! unable to close '$file': $!\n";
}
close($SGE);

##################################################################################################################################
# write perl script ready for submission
my $scriptName = 'run_jpred.pl';
write_script($scriptName);

##################################################################################################################################
# set up Array Job and submit perl script
# Just use all the defaults.
print "Submitting $count Jpred jobs to the cluster as an array job...\n" if $VERBOSE;
my $sgeArray = Cluster::ArrayJob->new();
$sgeArray->taskRange("1-$count");
$sgeArray->setCWD();
$sgeArray->setResourceRequest( 'ram' => '4G' );
$sgeArray->setParallel(4);
# # $sgeArray->setPriority(-10);
$sgeArray->setEnv( 'PERL5LIB' => '/homes/www-jpred/live4/lib' );
$sgeArray->submit($scriptName);

##################################################################################################################################
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

##################################################################################################################################
# Finally, check that all jobs completed successfully.
my $jobID = $sgeArray->jobid();
my @files = glob "$scriptName.e$jobID.*";

# check that the correct number of files exist - should be the same as the number of tasks
my $errors = 0;
my $nFiles = scalar @files;
if ( $nFiles != $count ) {
  warn "WARNING! found $nFiles SGE output files where $count expected\n";
  ++$errors;
}

my @jnets  = glob "*.jnet";
my $nJnets = scalar @jnets;
if ( $count != $nJnets ) {
  warn "WARNING! found $nJnets Jnet predictions when $count expected\n";
}

#########################
## FIXME - this bit doesn't work ATM as Jpred prints lots of routine stuff to STDERR
## check for any non-empty sge error files
#foreach my $file (@files) {
#   if (! -z $file) {
#      if ($file =~ /$scriptName\.e$jobID\.(\d+)/) {
#         warn "WARNING! task $1 had errors\n";
#         ++$errors;
#      } else {
#         warn "WARNING! '$file' SGE error file is non-empty (couldn't extract the task ID!)\n";
#         ++$errors;
#      }
#      next;
#   }
#   unlink($file)
#}
#print "No errors found\n" unless ($errors);
##########################
exit;

##################################################################################################################################
## write out perl script for running jpred.
## need this extra script as the fasta file names are not sequential,
## so must do a mapping between the SGE taskID and the fasta name
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

run_jpred_on_dataset.pl -dataset <NAME> [-subset <blind|training>] [-verbose] [-debug] [-man] [-help]

=head1 DESCRIPTION

This script should only be used to generate Jpred predictions on a known dataset for comparison. 
Hence, it retrieves sequence data from the JnetDB database only.

Once given a valid dataset (and optionally a subset thereof), the script retrieves the data and 
creates a Fasta file for each sequence and submits Jpred jobs to the cluster.

The script ends once the jobs have finished running and will report if any completed with errors.

=head1 OPTIONS

=over 5

=item B<--dataset>

Specify which dataset to retrieve sequence data from DB.

=item B<--subset>

Specify which subset of the dataset to run. [default: none]

=item B<--verbose|--no-verbose>

Toggle verbosity. [default:on]

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

__DATA__
#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

use strict;
use warnings;

my $file = 'sge_list.dat';

my $pwd = $ENV{PWD};  # get current directory
my $dir = $ENV{TMPDIR};  # get SGE tmpdir
my $task = $ENV{'SGE_TASK_ID'};  # get SGE array task ID
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

my $cmd = "cd $dir && /homes/www-jpred/live4/jpred/jpred --sequence $pwd/$doThisOne.fasta --output $doThisOne";
##my $cmd = "cd $dir && /homes/www-jpred/devel/jpred/jpred --sequence $pwd/$doThisOne.fasta --output $doThisOne --verbose --debug";
##my $cmd = "cd $dir && /homes/www-jpred/devel/jpred/jpred_with_hmmer2_with_timing --sequence $pwd/$doThisOne.fasta --output $doThisOne";
print "Running CMD: $cmd\n";
system($cmd) == 0 or die "ERROR! system() died\n";
print "Copying files back...";
##system("rm -f $dir/$doThisOne.{?.fasta*,backup.fasta.gz,jackhmmer.*,db,blast}");
system("cp -p $dir/$doThisOne.* $pwd/") ==0 or die "ERROR! system() died\n";
print "Done\n";

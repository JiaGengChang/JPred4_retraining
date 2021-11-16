#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

=head1 NAME

  rm_blind.pl - script to keep and or remove only the 'blind' set from Jpred training dataset

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

use lib '/homes/www-jpred/jnet_train/lib';

use Jpred::jnetDB;

my $dataset;    # specify which dataset to use
my $keep    = 0;    # toggle whether you want to keep the blind set or remove it
my $VERBOSE = 0;
my $help;
my $man;

GetOptions(
  'dataset=s' => \$dataset,
  'keep!'     => \$keep,

  'verbose!' => \$VERBOSE,
  'help|?'   => \$help,
  'man'      => \$man
) or pod2uage();

pod2usage( -verbose => 2 ) if ($man);
pod2usage( -verbose => 1 ) if ($help);
pod2usage( -msg => "Please specify which dataset to use.\n" ) unless ($dataset);

##################################################################################################################################
my $dbh = connect_DB('chris');
die "ERROR - failed to connect!" unless ($dbh);
my $com = "SELECT seq_id,domain FROM query WHERE dataset = '$dataset' and train = 0";
print "SQL command: $com\n" if ($VERBOSE);
my $list = $dbh->selectall_arrayref($com) or die "ERROR - select failed: ", $dbh->errstr;

my %list;
my $num = scalar @$list;
die "ERROR - no 'blind' sequences found for dataset 'HQSS.4'. Did you specify the correct name?\n" unless ($num);
print "Found $num in blind set\n";
foreach my $i ( 0 .. $num - 1 ) {
  $list{ $list->[$i][0] } = $list->[$i][1];
}

if ($keep) {
  my @files = glob "*.hmm";
  foreach my $file (@files) {
    my $root;
    if ( $file =~ /\/*(\w+)\.hmm/ ) {
      $root = $1;
    } else {
      die "Error - failed match for $file";
    }
    if ( !$list{$root} ) {
      system("rm -f $root*") == 0 or die "ERROR - unable to remove '$root*'";
    }
  }
} else {
  foreach my $blind ( sort keys %list ) {
    print "deleting 'blind' sequence: $list{$blind}...\n" if $VERBOSE;
    unlink(<glob "$blind.*">) or die "ERROR - unable to delete '$blind' files: $!\n";
  }
}

exit;

##################################################################################################################################

=head1 SYNOPSIS

  rm_blind.pl -dataset <name> [-keep|-no-keep] [-man] [-help]
  
=head1 DESCRIPTION

To be used during the retraining of the Jnet algorithm.

In order to validate the training process, a subset of the dataset has been defined as the 'blind' set and has been flagged as such in the I<jnet> compbio MySQL database.

The script assumes that in the current directory there are all the files needed for Jnet training named by their sequence ID in the I<jnet> database, but it includes the 
'blind' data as well. This script queries the database to determine which sequences are the 'blind' ones and deletes (or retains as defined with the B<-keep> option) 
only these files in the current directory.

=head1 OPTIONS

=over 5

=item B<-dataset>

Dataset name.

=item B<-keep|-no-keep>

Toggle whether to keep or remove the blind data. [default: remove]

=item B<-help>

Brief help.

=item B<-man>

Full manpage of program.

=back

=head1 AUTHOR

Chris Cole <christian@cole.name>

=cut

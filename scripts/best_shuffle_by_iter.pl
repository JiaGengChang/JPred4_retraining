#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

#$ -jc short
#$ -pe smp 8
#$ -mods l_hard mfree 8G
#$ -wd /cluster/gjb_lab/2472402/data/retr231_shuffles/shuffle01

use Cwd;
use List::Util qw( min max );

##################################################################################################################################


main();



##################################################################################################################################


sub main {
    my $DATA = '/cluster/homes/adrozdetskiy/Projects/jpredJnet231ReTrainingSummaryTable/scores/training/';
    my $nfolds = 7;
    @files = glob "$DATA/*.pssm";
    die "ERROR! no data files found" unless (@files);
    my $nfiles = $#files;
    print "$nfiles domains are being used for shuffling\n";
    my @nIters = (1000,2000,3000,4000,5000,10000);
    my $nIter = 0;
    
    my @best_shuffle;
    my $lowest_cutoff = 100;
    my $best_Iter;
    
    print "Finding the best shuffle after (@nIters) iterations\n";
    while (@nIters) {
        ++$nIter;
        shuffle( \@files );
        my $kth = int( ( scalar @files / $nfolds ) + 1 );
        
        my ( $sheet_content, $helix_content, $coils_content ) = calc_content( \@files, $kth );
        my $sheet_range = calc_range( $sheet_content );
        my $helix_range = calc_range( $helix_content );
        my $coils_range = calc_range( $coils_content );
        
        print( "Iteration   : $nIter\n" );
        print( "E propn     : @$sheet_content\n" );
        print( "H propn     : @$helix_content\n" );
        print( "C propn     : @$coils_content\n" );
        print( "E range     : $sheet_range\n" );
        print( "H range     : $helix_range\n" );
        print( "C range     : $coils_range\n" );
        print( "Best so far : Iter $best_Iter, score $lowest_cutoff\n" );
        
        
        # metric - highest of the three ranges
        my $current_score = max( $sheet_range, max( $helix_range, $coils_range ) );
        if ( $current_score < $lowest_cutoff ) {
            @best_shuffle = @files;
            $lowest_cutoff = $current_score;
            $best_Iter = $nIter;
        }
        
        if ( $nIter == $nIters[0] ){
            print "$nIter iterations reached. Best shuffle so far is $best_Iter with maximum % of difference $lowest_cutoff \n";
            store_shuffle( \@best_shuffle, $kth, $nIter );
            shift @nIters;
        }

    }
    
}

##################################################################################################################################

sub calc_content {
    my ( $list, $setSize ) = @_;
    
    my @helix_content;
    my @sheet_content;
    my @coils_content;
    my $size = $setSize;
    my $set = 0;
    for my $f (@$list){
    
        if ( $size == 0 ){
            $size = $setSize;
            ++$set;
        }
        
        $f =~ /(.*)(.pssm)/;
        my $dssp_file = "$1.dssp";
        my ( $nh, $ns, $nc ) = calc_SS_content($dssp_file);
        $helix_content[$set] += $nh / ($nh + $ns + $nc) * 100 / $setSize;
        $sheet_content[$set] += $ns / ($nh + $ns + $nc) * 100 / $setSize;
        $coils_content[$set] += $nc / ($nh + $ns + $nc) * 100 / $setSize;
        
        --$size;
    }
    
        
    return \@sheet_content, \@helix_content, \@coils_content;
}

##################################################################################################################################

sub calc_range {
    my $arrayref = shift;
    my $min = 100;
    my $max = -100;
    foreach my $val (@$arrayref){
        if ($val < $min) {
            $min = $val;
        }
        if ($val > $max) {
            $max = $val;
        }
    }
    return $max - $min;
}

##################################################################################################################################

sub calc_SS_content{
    my $nh,$ns,$nc;

    my $file_path = shift or die $1;

    open(my $FH, '<', $file_path) or die $1;

    my $dssp = <$FH> or die $1;
    chomp $dssp;
    $nh = $dssp =~ tr/H//;
    $ns = $dssp =~ tr/E//;
    $nc = $dssp =~ tr/-//;
    return $nh, $ns, $nc;
    
}
##################################################################################################################################

sub shuffle {
  my $array = shift;

  my $i;
  for ( $i = @$array ; --$i ; ) {
    my $j = int rand( $i + 1 );
    next if $i == $j;
    @$array[ $i, $j ] = @$array[ $j, $i ];
  }
    
}

##################################################################################################################################
# keep a note of the shuffled list of files.
# useful for when a cross-validation fails and can resume at the point of failure.
sub store_shuffle {
  my ( $list, $setSize, $iterNum ) = @_;

  open( my $FH, ">best_shuffle_it_".$iterNum.".log" ) or warn "WARNING! unable to open 'resume.log': $!";
  return unless $FH;

  my $set  = 1;
  my $size = 0;
  for my $f (@$list) {
    if ( $size == 0 ) {
      print $FH "#SET $set\n";
      ++$set;
      $size = $setSize;
    }
    print $FH "$f\n";
    --$size;
  }
  close($FH);
}

##################################################################################################################################

#!/cluster/gjb_lab/2472402/miniconda/envs/jnet/bin/perl

use strict;
use warnings;
use File::Basename;

main();

sub get_dssp_non_DB{

    my $path='/homes/adrozdetskiy/Projects/jpredJnet231ReTrainingSummaryTable/scores/training/1348/'; # path to the 1348 dssp files. can have other files
    
    my @files=glob "$path*.dssp";
    
    my %data; # key: domain name, value: a dssp string
    
    die $! unless (@files);
    
    foreach my $file (@files){
        my $base = basename ($file);
        open(FH, '<', $file) or die "unable to open $file. Died $! \n";
        my $domain; 
        my $dssp;
        while (<FH>){
            chomp;
            if ($_=~/\>/){
                $domain=$';
                # chomp $domain;
            }
            else {
                $dssp=$_;
            }
        }
        die unless $domain and $dssp;
        die "Aborting. Inserting duplicate dssp for domain $domain\n" if exists $data{$domain};
        $data{$domain}{'dssp'} = $dssp;
    }
    
    return \%data;    
    
}


# test the retrieval of elements
sub main {
    
    my $path='/homes/adrozdetskiy/Projects/jpredJnet231ReTrainingSummaryTable/scores/training/1348/'; # path to the 1348 dssp files. can have other files

    my $dsspData=get_dssp_non_DB($path);

    foreach my $domain (keys % $dsspData){
        print "$domain $dsspData->{$domain}{'dssp'}\n";
    
    }
}



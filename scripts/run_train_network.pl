#!/cluster/gjb_lab/2472402/miniconda/envs/jnet_train/bin/perl

# run the following command on a login node
# qsub scripts/run_train_network.sh
# this is the script to edit, do not edit the .sh script
 
use strict;
use warnings;

my $cmd = '/cluster/gjb_lab/2472402/scripts/train_network.pl';
my $type = 'pssm';
my $dir = '/cluster/gjb_lab/2472402/outputs/jpred_train/pssm-cross-val6';
my $data = '/homes/adrozdetskiy/Projects/JnetDatasets/Jnet_training_output_v2/cross-val6/';
my $layer = 2;
my $out = '/cluster/gjb_lab/2472402/outputs/jpred_train/pssm-cross-val6';
my $iters = 300;
my $nhid = 100;
my $valid = 1;

system("perl $cmd --type $type --dir $dir --layer $layer --out $out --data $data --iters $iters --nhid $nhid --valid $valid");

#!/bin/bash
#$ -pe smp 16
#$ -jc long
#$ -mods l_hard mfree 16G

# run the following command on a login node
# qsub scripts/run_train_network.sh

source /cluster/gjb_lab/2472402/miniconda/bin/activate jnet 
wdir=/cluster/gjb_lab/2472402/outputs/snns_cv_24Sep/cross-val3
perl /cluster/gjb_lab/2472402/jpred_train/train_network.pl --type hmm --dir $wdir/hmm --out $wdir/hmm --data $wdir/data

#!/bin/bash
#$ -pe smp 16
#$ -jc long
#$ -mods l_hard mfree 16G

# run the following command on a login node
# qsub scripts/run_train_network.sh

source /cluster/gjb_lab/2472402/miniconda/bin/activate jnet_train 
perl /cluster/gjb_lab/2472402/scripts/run_train_network.pl 

#!/bin/bash
#$ -pe smp 16
#$ -jc long
#$ -mods l_hard mfree 16G

# activate environment where jupyterlab is installed
# source /cluster/gjb_lab/2472402/miniconda/bin/activate jupyternb

jupyter lab --no-browser --ip=$(hostname --fqdn) 



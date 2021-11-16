#!/usr/bin/bash
#$ -jc long
#$ -mods l_hard mfree 16G
#$ -pe smp 16

source /cluster/gjb_lab/2472402/miniconda/bin/activate sandbox
python3.9 /cluster/gjb_lab/2472402/scripts/hmm_cross_val.py

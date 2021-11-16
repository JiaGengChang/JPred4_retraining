#!/bin/bash
#$ -pe smp 16
#$ -jc short
#$ -adds l_hard gpu 4
#$ -mods l_hard mfree 16G
#$ -m ea
#$ -M 2472402@dundee.ac.uk 
#$ -wd /cluster/gjb_lab/2472402/outputs/2021-09-03


source /cluster/gjb_lab/2472402/ml-env/bin/activate 
python 2021-09-03-SGD-Clf.py

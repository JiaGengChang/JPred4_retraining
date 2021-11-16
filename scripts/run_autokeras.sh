#!/bin/bash
#$ -pe smp 16
#$ -jc short
#$ -adds l_hard gpu 2
#$ -mods l_hard mfree 16G
#$ -m ea
#$ -M 2472402@dundee.ac.uk 
#$ -wd /cluster/gjb_lab/2472402/outputs/2021-08-30-autokeras_test/pssm


source /cluster/gjb_lab/2472402/ml-env/bin/activate 
python /cluster/gjb_lab/2472402/scripts/autokeras_cv_2021-08-30.py 'pssm' 



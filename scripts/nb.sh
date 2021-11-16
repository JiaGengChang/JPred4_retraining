#!/bin/bash
#$ -pe smp 2
#$ -jc short
#$ -mods l_hard mfree 6G
#$ -e log.nb
#$ -o /dev/null 

#source /cluster/gjb_lab/2472402/miniconda/bin/activate kg
jupyter lab --no-browser --ip=$(hostname --fqdn) 


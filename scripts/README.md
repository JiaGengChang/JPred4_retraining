# Source files directory

Explanation for some scripts

### best_shuffle_by_cutoff.pl
There is a bug in this script where the shuffle stored is not the best shuffle. 
This script has been replaced by ~/jupyter_notebooks/machine_learning/2021-09-21-measure-shuffle-SS-content.py which is a python version that does not have the same bug

### pdb_to_dssp_batch.py
Submits a bunch of PDBs to DSSP webserver.

### Parse_dssp_to_SS.py 
Script hacked from blom lab dms_tools2 (https://github.com/jbloomlab/dms_tools2) to parse stdout output of dssp program into a dataframe. 
I have many pickled objects of the dataframes from this script in ~/data/AF-pdb-files-jnet

### get_dssp.pl
Obtains 8 state dssp from JNET database

### Run_wrapper.sh
Job submission script for jpred_train/wrapper.pl. 

### resume_scoring.pl
Sometimes jpred_train/wrapper.pl crashes at the stage where `make` is required. This script resumes the wrapper script from the crash.

### calSOV
Binary for SOV calculation. Older versions of SOV in jpred_train/code bin are only for 32 bit architecture


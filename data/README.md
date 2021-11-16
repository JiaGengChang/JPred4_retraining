# Data directory

### `alphafold-alignments`
Outputs of alignment jupyter notebooks (in `jupyter_notebooks/alphafold`). Also contains list of uniprot IDs which I used in the process of downloading batches of PDBe files from AlphaFold. 

### `dictionaries`
Text and `.csv` files for basic text manipulating operations. A lot of files start with a 4 digit number which corresponds to the number of domains in that file. 

### `retr231_raw_files`
Training and blind test files for 1507 sequences. Probably the most important directory here as it is the JPred dataset. The JPred dataset available online does not have the critical `.hmm` and `.pssm` files.

### `retr231_shuffles`
3 example train-test splits (which I call shuffles because I generate them by shuffling) which have very similar secondary structure content across the 7 splits. In the later stages of the project I was focused on training using cross-validation folds with high similarity in an attempt to deal with validation loss being lower than training loss. 

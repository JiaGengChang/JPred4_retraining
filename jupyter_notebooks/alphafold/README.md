# Jupyter notebooks to compare alphafold vs Jpred performance

### 2021-09-07-pdb-json-to-dssp.ipynb
Compare mapping of PDB Ids to Uniprot entries. Some are 1-1 mapping, others have multiple uniprot entires.

### 2021-09-08-AF-pdb-to-dssp.ipynb
AF = alphafold
This script converts uniprotIds into alphafold urls, downloads these pdb files, runs dssp on these files, and converts them into dataframes storing secondary structure info saved as .pkl objects

### 2021-09-09-AF-pdb-to-dssp-2.ipynb
Carrying on from 2021-09-09-AF-pdb-to-dssp.ipynb
Day 2 of trying to align alphafold predictions with scope sequences

### 2021-09-10-AF-jpred-align-clean-ver.ipynb
Aligning protein sequence of uniprot (AlphaFold) and SCOPe (jpred)

### 2021-09-10-AF-jpred-align-debug-ver.ipynb
Same as above but used for debugging 

### Alignment functions
* 2021-09-13-align-functions.ipynb
* 2021-09-14-align-functions-contd-Copy1.ipynb
* 2021-09-14-align-functions-contd.ipynb
Smith waterman algorithm to try and align uniprot and jpred training sequences




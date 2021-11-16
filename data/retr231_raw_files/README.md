# Training and blind test files used for JPred4 training

These files were obtained from Alexey Drozdetskiy. Consisting of 1348 training examples and 149 blind test examples. The blind test examples have not been used anywhere in this project.

## Each SCOPe domain has a few files associated with it:
* `.fasta`: Amino acid sequence. For reference.
* `.seq`: Amino acid sequence in human readable format (60 characters per line)
* `.dssp`: 3 state secondary structure. They are the prediction labels.
* `.profile`: PSI-BLAST output. Shows the last PSI-BLAST PSSM matrix computed. Not used for training.
* `.hmm`: One of the inputs for training and prediction. 
* `.pssm`: Another input for training and prediction
* `.jnet`: JPred output



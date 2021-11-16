# Jupyter notebooks and python scripts for neural network training

### 2021-08-30-autokeras.ipynb
Not significant. Testing out autokeraas which I did not use eventually.

### 2021-09-03-nbconverter.ipynb
Script to convert `.ipynb` to `.py` script for batch submission 

### 2021-09-15-joint-cross-val.ipynb
Script to do combined training on HMM and PSSM matrices, for both sequence-to-structure and structure-to-structure layer. This script is converted to `.py` script and submitted for cross-validation.
The nature of this workflow is procedural.

### 2021-09-18-jnetclassifier.ipynb
Work in progress, object-oriented version of the HMM_cross_val.xxx scripts
Should theoretically train much much faster - as most functions like windowing has been shifted into the tensorflow computational graph.
Downside:
Current version trains both layers at the same time, meaning which I suspect leads to poorer accuracies of around 80% - an improvement would be to train layers separately


### 2021-09-20-resume-log-cross-val.ipynb
Run cross validation from serialized dataset. Faster than HMM_cross_val.py and PSSM_cross_val.py because it does not require preprocessing functions. I am using sklearn here.

### 2021-09-21-measure-shuffle-SS-content.ipynb/py
Used to generate shuffles for training. Run to generate a split to train jnet on.
Finds a shuffle that falls below a certain threshold
One can also hack a resume.log file to use to run jnet training on the same shuffle (if no resume.log file is present in working directory, jnet training code will come up with its own shuffle - not ideal)

### HMM.ipynb
Very short example that reads in HMM profiles, processes data for input, and trains a NN. Minimal working example used in week 2. No cross-validation.

### HMM_cross_val.ipynb
Script partially adapted from cross_val_old.ipynb. A similar version of this script, called PSSM_cross_val.ipynb, exists
This notebook runs on hmm/pssm files using the sets defined in archives available online. The datasets are obtained from `/homes/adrozdetskiy/Projects/jpredJnet231ReTrainingSummaryTable/data/training/(1348)`. I created this notebook to run checks so that the equivalent .py script will not crash when submitted to the scheduler. The actual script used to run cross validation is stored in `/cluster/gjb_lab/2472402/scripts/hmm_cross_val.py`, which is wrapped by a bash script (`hmm_cross_val.sh`) for submission to the scheduler

### PSSM_cross_val.ipynb
See `HMM_cross_val.ipynb`.

### HMM_cross_val_last_day.ipynb/py
* Last ran on: 20/09/2021. Not actually the last day. 
* The most recent cross val scripts I had been using
* Reduced time for data I/O as it loads serialized objects.
* It has cleaner text output
* Saves model1 before model2 and checks for presence of model1 so that one can resume training if it crashes halfway during the training of model2
* More pythonic code
* It can also be run on PSSM and PSSMb, just need to specify in the keyword arguments

### (hmm-)cross_val_old.ipynb
Old cross validation script, for profile HMM.

### joint-cv.py
Something I worked on in the last few days.
Combined HMM and PSSM cross validation script, makes use of tf.function decorator. Lower accuracy than procedural version (joint-cross-val.ipynb) because it trains layer 1 and 2 at the same time, but more scaleable than procedural version and probably trains faster.

### jnet-tf-oop.ipynb
Google colab notebook to train neural network classifier using tensorflow graph computation. Only dummy predictors and labels used here at this stage. Can be followed up on.



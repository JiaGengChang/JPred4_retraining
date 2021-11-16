# Notebooks for visualizing model performance

### 2021-08-26-means-and-plots.ipynb 
Gathers scores from `cv[1-7]_scores.csv` and calculates the mean and standard deviation of prediction accuracies. 

### 2021-08-31-bqplot-test.ipynb 
Test plotting using bqplot. Works only when you install jupyterlab in the same environment as you install bqplot, and launch a notebook from this environment
Also the first scatterplot of SNNS vs Keras came from here.

### 2021-09-01-bqplot-25Aug.ipynb 
Plot of SNNNS vs Keras scatterplot using bqplot for experiments run on 25 August 2021. Separate HMM and PSSM scatterplots, not joint prediction.

### 2021-09-[01/20]-bqplot-26Aug_jpred.ipynb, 
Same as 25 Aug but instead of looking at HMM and PSSM separately, it plots joint accuracies.

### CV-plots.ipynb 
Mother of all notebooks here, contains not just training/validation loss curves, but also measuring accuracy, measuring secondary structure content, experimenting with different ways to represent training results. 
There is not really a need to look at this notebook because they are just tests, except for the scatterplots under the section '`Visualizing accuracies`'.

### 2021-09-21-CV-plots.ipynb 
Copied from CV-plots.ipynb, analysis of cross-validation results for experiments run on 20 September 2021. The usual training vs validation loss curves.

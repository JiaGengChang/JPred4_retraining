# Notebooks that evaluate the prediction accuracy and segment overlap (SOV) score of keras and SNNS models

### sov-and-accuracy.ipynb
Good place to start to see how the final results are presented in different tracks. The code takes `cv[1-7]\_scores.csv` and `cv[1-7]\_.knet` files from both keras and SNNS scripts and presents them in a common format. The rest of the scripts convert raw output into the `cv[1-7]\_scores.csv` and `cv[1-7]\_.knet` formats.

### 2021-08-26-sov-and-accuracy-control.ipynb
Measure accuracy and SOV score of SNNS cross validation predictions


### 2021-08-26-sov-and-accuracy.ipynb
Measure accuracy and SOV score of Keras cross validation predictions


### 2021-08-27-bottom-line-results.ipynb/py
Output one line of results per fold of cross validation into a csv file, for both SNNS results and Keras training results


### 2021-08-27-jnetval-stats.ipynb
Process the results of score_jnet.csv, one of the outputs of the Perl run_wrapper.pl script, for each fold of cross-validation, into a single csv file called score-jnetval-analysis.


### 2021-08-27-jury-keras.ipynb
Average the prediction for separate keras networks to produce 'knet' predictions. This is known as joint prediction.


### 2021-08-27-jury-snns.ipynb
Produces .csv and .knet files used to generate scatterplots. Unlike the keras version above, joint prediction is already done by the C code written into JPred, just has to be read from .jnet files.


### old-accuracy.ipynb, old-predictions.ipynb
Old notebook that evaluates training (recall) accuracy of HMM layers and PSSM layers, based on predictions.



# JPred4 retraining project repo
Contains JPred4 training and deployment code written mostly in perl belonging to Jpred4, as well as jupyter notebooks and python scripts for implementing the training with keras.
Everything apart from `jpred_code` and `jpred_train` by Jia Geng over 2021 summer under the supervision of Geoff and Stuart.

<br>

### `data` 
Data files. Training data, blind test data, some dictionaries to lookup SCOPe IDs and jnet IDs.

### `jpred_code`
Code for the deployment of jpred, makes use of trained JNet binaries. Similar to the one found on the JPred website under 'source code'.

### `jpred_train`
Code for the training of JNet. This submits batch jobs to SNNS (http://www.ra.cs.uni-tuebingen.de/SNNS/welcome.html). To run this code there are a lot of perl dependencies.

### `jupyter_notebooks`
Notebooks for the keras implementation of JNet, as well as tools for evaluating and visualizing prediction accuracy.

### `scripts` 
Some scripts here are wrappers for submission to the job scheduler, but those ending with `.py` are scripts converted from jupyter notebooks. Includes scripts for doing cross-validation.

### `presentations`
Presentation slides and a script that I used for the first presentation.

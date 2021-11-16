#!/usr/bin/env python

from tensorflow import keras
from tensorflow.keras import layers
from datetime import datetime
import numpy as np
import pandas as pd
import os
from os import path
import sys
import pickle

# this function is copied from HMM.ipynb
# array: numpy array
# flank: positive integer
def sliding_window(array, flank):
    assert flank > 0
    assert type(array) is np.ndarray
    assert np.logical_not(np.isnan(np.sum(array)))
    nrow = array.shape[0]
    assert nrow > 0
    ncol = array.shape[1]
    assert ncol > 0
    res = np.empty(shape=(nrow, (2*flank+1)*ncol))
    res[:] = np.nan
    for i in list(range(0,nrow)):
        s, e = i-flank, i+flank+1
        k = 0;
        for j in list(range(s,e)):
            if (j < 0 or j >= nrow):
                res[i, k:k+ncol] = 0
            else:
                assert np.logical_not(np.isnan(np.sum(array[j])))
                assert array[j].shape == (ncol,)
                res[i, k:k+ncol] = array[j]
            k += ncol
    assert np.logical_not(np.isnan(np.sum(res)))
    assert res.shape == (nrow, (2*flank+1)*ncol)
    return res

# this function rounds predictions into 1 and 0s
def argmax(arr):
    n, c = arr.shape
    assert c == 3
    assert type(arr) is np.ndarray
    assert np.logical_not(np.isnan(np.sum(arr)))
    res = np.empty(shape=(n,c))
    res[:] = np.nan
    for i in list(range(0,n)):
        max_idx = np.argmax(arr[i])
        if max_idx == 0:
            res[i] = np.array([1, 0, 0])
        elif max_idx == 1:
            res[i] = np.array([0, 1, 0])
        else:
            assert max_idx == 2
            res[i] = np.array([0, 0, 1])
    assert np.logical_not(np.isnan(np.sum(res)))
    return res

def get_dssp(ID):
    path = '/homes/adrozdetskiy/Projects/JnetDatasets/DSSP_out/' + ID + '.sec'
    ls = list(pd.read_csv(path).loc[0].values)
    ls[0] = ls[0][-1:] # remove the DSSP: part from first list item
    res = np.empty(shape=(len(ls),3))
    res[:] = np.nan
    for i in range(0,len(ls)):
        if ls[i] == 'H':
            res[i] = np.array([1,0,0])
        else:
            if ls[i] == 'E' or ls[i] == 'B':
                res[i] = np.array([0,1,0])
            else:
                assert ls[i] != None
                res[i] = np.array([0,0,1])
    assert not np.isnan(np.sum(res))
    return res

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)
    

# first make sure that output path is valid, otherwise computation will go to waste
out_path = '/cluster/gjb_lab/2472402/outputs/hmm_cross_val/'
assert path.exists(out_path)
assert len(os.listdir(out_path)) == 0; # do not want to write over existing files
assert out_path[-1] == '/'


# path to training and validation examples
# paths = ["/homes/adrozdetskiy/Projects/JnetDatasets/Jnet_training_output_v2/cross-val%d/" % num for num in range(1,8)]
paths = ["/homes/adrozdetskiy/Projects/JnetDatasets/Jnet_training_output_v2/cross-val%d/" % num for num in range(1,8)]

# sequence dictionary or sd. need this to retrieve dssp information
sd = pickle.load(open('/cluster/gjb_lab/2472402/data/cross-val/cross_val_dict.pkl','rb')) 


# for each fold in the 7 fold cross validation procedure, do...
for counter, path in enumerate(paths):

    counter += 1 # start from 1
    
    eprint('Commencing fold %d of cross validation at %s'%(counter, datetime.now().strftime("%D %H:%M:%S")))

    train_path = path + 'data/'
    valid_path = path + 'valid/'
    
    # get file names ending with .hmm
    train_files = [f for f in os.listdir(train_path) if f[-4:] == '.hmm']
    valid_files = [f for f in os.listdir(valid_path) if f[-4:] == '.hmm']
    
    # comment out these lines after dry run
    # train_files = train_files[0:12]
    # valid_files = valid_files[0:2]
    
    # get X_train and X_valid

    # read profile hmms as numpy arrays
    train_hmm = [np.genfromtxt(fname = train_path + fn) for fn in train_files]
    valid_hmm = [np.genfromtxt(fname = valid_path + fn) for fn in valid_files]
    
    # window profile hmms to get patterns
    # layer 1 sliding window flank = 8
    X_train = [sliding_window(hmm, flank=8) for hmm in train_hmm]
    X_valid = [sliding_window(hmm, flank=8) for hmm in valid_hmm]

    # get Y_train and Y_valid
    
    # remove .hmm extension and convert to int for lookup
    train_numbers = [int(fn[:-4]) for fn in train_files]
    valid_numbers = [int(fn[:-4]) for fn in valid_files] 
    
    # lookup seqIDs given jnet number
    train_dssp_IDs = [sd[sd.number == num].letters.values[0] for num in train_numbers]
    valid_dssp_IDs = [sd[sd.number == num].letters.values[0] for num in valid_numbers]
    
    # obtain 3-column DSSP of domains given their seqID. See get_dssp() defined above
    Y_train = [get_dssp(ID) for ID in train_dssp_IDs]
    Y_valid = [get_dssp(ID) for ID in valid_dssp_IDs]

    assert all([y.shape[1] == 3 for y in Y_train])
    assert all([y.shape[1] == 3 for y in Y_valid])
    assert all([x.shape[0] == y.shape[0] for (x, y) in zip(X_train, Y_train)])
    assert all([x.shape[0] == y.shape[0] for (x, y) in zip(X_valid, Y_valid)])

    # get stacked versions for layer 1 input
    X_train_stacked = np.concatenate(tuple(X_train))
    X_valid_stacked = np.concatenate(tuple(X_valid))
    Y_train_stacked = np.concatenate(tuple(Y_train))
    Y_valid_stacked = np.concatenate(tuple(Y_valid))

    # sanitys check before passing into model1
    assert X_train_stacked.shape[0] == Y_train_stacked.shape[0]
    assert X_valid_stacked.shape[0] == Y_valid_stacked.shape[0]
    
    assert X_train_stacked.shape[1] == 408
    assert X_valid_stacked.shape[1] == 408
    
    assert Y_train_stacked.shape[1] == 3
    assert Y_valid_stacked.shape[1] == 3
    
    assert X_train_stacked.dtype =='float64'
    assert X_valid_stacked.dtype == 'float64'
    
    assert Y_train_stacked.dtype =='float64'
    assert Y_valid_stacked.dtype == 'float64'

    # sequence to structure layer
    model1 = keras.Sequential([
        layers.Dense(units = 100, activation ='sigmoid', input_shape=[408]),
        layers.Dense(units = 3, activation ='softmax')
    ])

    model1.compile(optimizer='sgd', loss='MSE', metrics=[])

    eprint('Fitting layer 1 model. %s' % datetime.now().strftime("%H:%M:%S"))

    history1 = model1.fit(X_train_stacked, Y_train_stacked,
                          validation_data = (X_valid_stacked,Y_valid_stacked),
                          batch_size = 128,
                          epochs = 300, 
                          verbose = 0)

    eprint('Calculating layer 1 predictions. %s' % datetime.now().strftime("%H:%M:%S"))

    # obtain layer 1 predictions and apply argmax to get 1s and 0s
    # do this also for X_valid because X_valid needs to be same shape as X_train
    Y_pred_train = [argmax(model1.predict(X)) for X in X_train]
    Y_pred_valid = [argmax(model1.predict(X)) for X in X_valid]

    # process layer 1 predictions into layer 2 X input
    # layer 2 sliding window flank = 9
    X_train_2 = [sliding_window(Y, flank = 9) for Y in Y_pred_train]
    X_valid_2 = [sliding_window(Y, flank = 9) for Y in Y_pred_valid]
    X_train_2_stacked = np.concatenate(tuple(X_train_2))
    X_valid_2_stacked = np.concatenate(tuple(X_valid_2))
    
    # sanity checks before passing into model2
    assert X_train_2_stacked.shape[0] == Y_train_stacked.shape[0]
    assert X_valid_2_stacked.shape[0] == Y_valid_stacked.shape[0]
    
    assert X_train_2_stacked.shape[1] == 57
    assert X_valid_2_stacked.shape[1] == 57
    
    assert X_train_stacked.dtype == 'float64'
    assert X_valid_stacked.dtype == 'float64'
    
    # structure to structure layer
    model2 = keras.Sequential([
        layers.Dense(units=100, activation='sigmoid', input_shape=[57]), 
        layers.Dense(units=3, activation = 'softmax')
    ])

    model2.compile(
        optimizer='sgd', 
        loss='MSE',
        metrics=['accuracy']
    )

    eprint('Fitting layer 2 model. %s' % datetime.now().strftime("%H:%M:%S"))

    history2 = model2.fit(
        X_train_2_stacked, Y_train_stacked, # y_train is unchanged
        validation_data = (X_valid_2_stacked, Y_valid_stacked), # y_valid is unchanged
        batch_size = 128, 
        epochs = 300, 
        verbose = 0 
    )

    # save results 
    eprint('Saving results to %s' % out_path)

    history = [pd.DataFrame(history1.history), pd.DataFrame(history2.history)]
    pickle.dump(history, open(out_path + 'results_%d.pkl' % counter, 'wb'), protocol=pickle.HIGHEST_PROTOCOL)

    model1.save(out_path + 'fold%d_model1' % counter, save_format = 'tf') # tensorflow SavedModel format
    model2.save(out_path + 'fold%d_model2' % counter, save_format = 'tf')

    # finish current fold
    eprint('Finished fold %d of cross validation at %s\n' % (counter, datetime.now().strftime("%D %H:%M:%S")))

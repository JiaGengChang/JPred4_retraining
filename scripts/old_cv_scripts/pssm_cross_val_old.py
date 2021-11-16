#!/usr/bin/env python

# import modules
from tensorflow import keras
from tensorflow.keras import layers
import numpy as np
import pandas as pd
import pickle
from datetime import datetime
from os import path # to check that output path is valid
import sys # for print function

# function to print to std err
def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

# function to generate cross validation indices
# custom implementation of stratifiedkfold from sklearn.model_selection
# by altering the upper bound for
def train_test_split(folds):
    d_list = [] # list of dictionaries to return at end of func
    for test_idx in range(0,folds):
        all_idx = list(range(0,folds))
        train_idx = [idx for idx in all_idx if idx != test_idx]
        d = {'test_idx': test_idx, 'train_idx' : train_idx} # d is a dictionary of test and train indices
        d_list.append(d)
    return d_list 


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

# first make sure that output path is valid, otherwise computation will go to waste
out_path = '/cluster/gjb_lab/2472402/outputs/pssm_cross_val/'
assert path.exists(out_path)
assert out_path[-1] == '/'

# import training data
X = pickle.load(open('/cluster/gjb_lab/2472402/data/cross-val/pssm-sdxwli-seqs-X.pkl','rb'))
Y = pickle.load(open('/cluster/gjb_lab/2472402/data/cross-val/pssm-sdxwli-seqs-y.pkl','rb'))

# comment out these lines after dry run. 
# X = [x[0:2] for x in X]
# Y = [y[0:2] for y in Y]

# counter for cross validation
counter = 1

# for each fold in the 7 fold cross validation procedure, do...
for current_split in train_test_split(folds=7): 
    
    eprint('Commencing fold %d of cross validation at %s'%(counter, datetime.now().strftime("%D %H:%M:%S")))
    
    # get which set will be used for validation (test_idx), the remaining 6 will be usede for training (train_idx)
    train_idx = current_split['train_idx']
    test_idx = current_split['test_idx']
    
    # obtain test pssm profile (X) and dssp information (y)
    # TODO create X_test_stacked
    
    X_test = np.vstack(X[test_idx])
    Y_test = np.vstack(Y[test_idx])

    assert X_test.dtype=='float64'
    assert Y_test.dtype=='float64'
    
    assert X_test.shape[0] == Y_test.shape[0]
    assert X_test.shape[1] == 340
    assert Y_test.shape[1] == 3
    
    

    # obtain train pssm profile (X) and dssp information (Y)
    X_train = np.concatenate(tuple([X[idx] for idx in train_idx]), dtype=object)
    Y_train = np.concatenate(tuple([Y[idx] for idx in train_idx]), dtype=object)
    
    X_train_stacked = np.concatenate(X_train) # dtype=float64
    Y_train_stacked = np.concatenate(Y_train)
    
    assert X_train_stacked.dtype=='float64'
    assert Y_train_stacked.dtype=='float64'
    
    assert X_train_stacked.shape[0] == Y_train_stacked.shape[0]
    assert X_train_stacked.shape[1] == 340
    assert Y_train_stacked.shape[1] == 3
    
    # sequence to structure layer
    model1 = keras.Sequential([
        layers.Dense(units=100, activation='sigmoid', input_shape=[340]),
        layers.Dense(units=3, activation='softmax')
    ])

    model1.compile(optimizer='sgd', loss='categorical_crossentropy', metrics=['accuracy'])

    eprint('Fitting layer 1 model. %s' % datetime.now().strftime("%H:%M:%S"))
    
    history1 = model1.fit(X_train_stacked, Y_train_stacked,
                          validation_data=(X_test,Y_test),
                          batch_size=128,
                          epochs=300, 
                          verbose=0)
    
    eprint('Calculating layer 1 predictions. %s' % datetime.now().strftime("%H:%M:%S"))
    
    # obtain layer 1 predictions and simplify it with argmax
    Y_pred = [argmax(model1.predict(X)) for X in X_train]
    
    # convert layer 1 Y output into layer 2 X input
    X_train_2 = [sliding_window(Y, flank=9) for Y in Y_pred]
    X_train_2_stacked = np.concatenate(tuple(X_train_2))
    
    # structure to structure layer
    model2 = keras.Sequential([
        layers.Dense(units=100, activation='sigmoid', input_shape=[57]), 
        layers.Dense(units=3, activation = 'softmax')
    ])
    
    model2.compile(
        optimizer='sgd', 
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    # feed X_test through layer 1 because we are testing it on layer 2
    # TODO error here because sliding window should be done at sequence level, but X_test is stacked
    X_test = model1.predict(X_test)
    X_test = sliding_window(X_test, flank=9)
    
    eprint('Fitting layer 2 model. %s' % datetime.now().strftime("%H:%M:%S"))

    history2 = model2.fit(
        X_train_2_stacked, Y_train_stacked, # note y_train is unchanged
        validation_data=(X_test, Y_test), # this time include test data
        batch_size=128, 
        epochs=300, 
        verbose=0, 
    )
    
    # save results 
    eprint('Saving results to %s' % out_path)

    history = [pd.DataFrame(history1.history), pd.DataFrame(history2.history)]
    pickle.dump(history, open(out_path + 'results_%d.pkl' % counter, 'wb'), protocol=pickle.HIGHEST_PROTOCOL)

    model1.save(out_path + 'fold%d_model1' % counter, save_format = 'tf') # tensorflow SavedModel format
    model2.save(out_path + 'fold%d_model2' % counter, save_format = 'tf')

    # finish current fold
    eprint('Finished fold %d of cross validation at %s\n' % (counter, datetime.now().strftime("%D %H:%M:%S")))
    
    # increment counter and continue
    counter += 1

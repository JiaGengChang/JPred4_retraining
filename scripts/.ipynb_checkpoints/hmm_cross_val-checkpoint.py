#!/usr/bin/env python
# import modules
from tensorflow import keras
from tensorflow.keras import layers
import numpy as np
import pandas as pd
import pickle
import os
import sys
from datetime import datetime
from os import path

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

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)
    
# given string of dssp s, one hot encode it in E, H,C order ## note this is different from previous ways
# e.g. input
def onehotstring(s):
    res = np.empty(shape=(len(s),3))
    res[:] = np.nan
    for i in range(0,len(s)):
        if s[i] == 'H':
            res[i] = np.array([0,1,0])
        else:
            if s[i] == 'E':
                res[i] = np.array([1,0,0])
            else:
                assert s[i]
                res[i] = np.array([0,0,1])
    assert not np.isnan(np.sum(res))
    return res

subtype='HMM' # <-- change this value

assert subtype=='PSSM' or subtype=='HMM'
if subtype=='HMM':
    ext=".hmm"
    L1_INPUT_SHAPE=408
else:
    assert subtype=='PSSM'
    ext=".pssm"
    L1_INPUT_SHAPE=340

# declare constants
BATCH_SIZE=256 
N_EPOCHS_1=300
N_EPOCHS_2=300
N_HID=100

debug=False

all_seqIDs_folder="/homes/adrozdetskiy/Projects/jpredJnet231ReTrainingSummaryTable/scores/training/"
all_domains_folder="/homes/adrozdetskiy/Projects/jpredJnet231ReTrainingSummaryTable/scores/training/1348/"
data_dir="/cluster/gjb_lab/2472402/snns_cross_val_25_Aug" # SNNS directory. remember to change

for i in range(1,8):
    
    root_folder="/cluster/gjb_lab/2472402/outputs/keras_train_CV/%s/26Aug" % subtype
    assert path.exists(root_folder), "Root folder %s does not exist" % root_folder
    # create out folder
    out_folder=os.path.join(root_folder, "cross-val%d/" % i)
    if path.exists(out_folder):
        assert not os.listdir(out_folder), "Output directory %s exists and is not empty. Aborted." % out_folder
    else:
        os.system("mkdir %s" % out_folder)
    
    Xtrain1_list,Ytrain_list=[],[] #Ytrain is same for both layers
    Xvalid1_list,Yvalid_list=[],[] #Yvalid is same for both layers
    
    train_folder=os.path.join(data_dir,"cross-val%d/data/" % i)
    valid_folder=os.path.join(data_dir,"cross-val%d/valid/" % i)
    train_seqIDs=sorted([_[:-4] for _ in os.listdir(train_folder) if _.endswith('.hmm')])
    valid_seqIDs=sorted([_[:-4] for _ in os.listdir(valid_folder) if _.endswith('.hmm')])
    assert valid_seqIDs
    assert train_seqIDs
    
    # read the pssm/hmm files
    train_profile_files=sorted([_ for _ in os.listdir(train_folder) if _.endswith(ext)])
    valid_profile_files=sorted([_ for _ in os.listdir(valid_folder) if _.endswith(ext)])
    assert train_profile_files
    assert valid_profile_files
    
    # read the dssp files - both of which are in train_folder (jpred training code bug?)
    train_dssp_files=sorted([os.path.join(train_folder,_+'.dssp') for _ in train_seqIDs])
    valid_dssp_files=sorted([os.path.join(train_folder,_+'.dssp') for _ in valid_seqIDs])
    assert train_dssp_files
    assert valid_dssp_files
    
    # read input files one by one and convert to list of patterns
    for f in train_profile_files:
        profile=np.genfromtxt(train_folder+f)
        pattern=sliding_window(profile,flank=8)
        Xtrain1_list.append(pattern)

    for f in valid_profile_files:
        profile=np.genfromtxt(valid_folder+f)
        pattern=sliding_window(profile,flank=8)
        Xvalid1_list.append(pattern)
    
    # read dssp information 
    for dsspf in train_dssp_files:
        with open(dsspf,'r') as f:
            string_dssp=f.read().rstrip() # rstrip is perl equivalent of chomp
            dssp=onehotstring(string_dssp)
            Ytrain_list.append(dssp)
    assert Ytrain_list
    
    for dsspf in valid_dssp_files:
        with open(dsspf,'r') as f:
            string_dssp=f.read().rstrip()
            dssp=onehotstring(string_dssp)
            Yvalid_list.append(dssp)
    assert Yvalid_list
    
    # end of part modified 24 Aug
    
    assert len(Xtrain1_list)==len(Ytrain_list) # should see 1151 or 1153 sequences
    eprint("train size (should be 1155 or 1157): %d" % len(Ytrain_list))
    assert len(Xvalid1_list)==len(Yvalid_list) # should see 193 or 191 sequences
    eprint("validation size (should be 193 or 191): %d" % len(Yvalid_list))
    
    if (debug):
        Xtrain1_list=Xtrain1_list[0:1]
        Ytrain_list=Ytrain_list[0:1]
        Xvalid1_list=Xvalid1_list[0:1]
        Yvalid_list=Yvalid_list[0:1]
        N_EPOCHS=1
        N_HID=1
    
    # collapse the domain-level partitioning of the patterns
    Xtrain1=np.vstack(Xtrain1_list) 
    Ytrain=np.vstack(Ytrain_list) 
    Xvalid1=np.vstack(Xvalid1_list) 
    Yvalid=np.vstack(Yvalid_list) 
    assert sum([df.shape[0] for df in Xtrain1_list])==sum([df.shape[0] for df in Ytrain_list])
    
    if (debug):
        Xtrain1=Xtrain1[0:1]
        Ytrain=Ytrain[0:1]
        Xvalid1=Xvalid1[0:1]
        Yvalid=Yvalid[0:1]
    
    # sequence to structure layer
    model1 = keras.Sequential([
        layers.Dense(units = N_HID, activation ='sigmoid', input_shape=[L1_INPUT_SHAPE]),
        layers.Dense(units = 3, activation ='softmax')
    ])
    
    model1.compile(optimizer='sgd', loss='categorical_crossentropy')
    
    eprint('%s. Fitting layer 1 model.' % datetime.now().strftime("%H:%M:%S"))
    history1 = model1.fit(Xtrain1, Ytrain,
                          validation_data=(Xvalid1,Yvalid),
                          batch_size=BATCH_SIZE,
                          epochs=N_EPOCHS_1,
                          verbose=0)    
    
    # free up RAM
    del Xtrain1, Xvalid1
    
    # skin the cat - pass layer 1 input through model 1 to get layer 2 input
    Xtrain2_list = [sliding_window(model1.predict(X),flank=9) for X in Xtrain1_list]
    Yvalid_pred1 = [model1.predict(X) for X in Xvalid1_list]
    Xvalid2_list = [sliding_window(X,flank=9) for X in Yvalid_pred1]
    
    Xtrain2=np.vstack(Xtrain2_list)
    Xvalid2=np.vstack(Xvalid2_list)
    #Yvalid is the same as layer 1
    #Ytrain is the same as layer 1
    
    if (debug):
        Xtrain2=Xtrain2[0:1]
        Xvalid2=Xvalid2[0:1]
    
    # structure to structure layer
    model2 = keras.Sequential([
        layers.Dense(units = N_HID, activation ='sigmoid', input_shape=[57]),
        layers.Dense(units = 3, activation ='softmax')
    ])
    model2.compile(optimizer='sgd', loss='categorical_crossentropy')
    
    eprint('%s. Fitting layer 2 model.' % datetime.now().strftime("%H:%M:%S"))
    history2 = model2.fit(Xtrain2, Ytrain,
                          validation_data=(Xvalid2,Yvalid),
                          batch_size=BATCH_SIZE,
                          epochs=N_EPOCHS_2,
                          verbose=0) 
    
    # free up RAM
    del Xtrain2, Xvalid2
    
    # get predictions for validation set (to calculate accuracy)
    eprint('%s. Generating layer 2 predictions.' % datetime.now().strftime("%H:%M:%S"))
    Yvalid_pred2=[model2.predict(X) for X in Xvalid2_list]
    
    # pickle training history and predictions for validation set 
    eprint('%s. Saving inputs and results.' % datetime.now().strftime("%H:%M:%S"))
    results_file = out_folder + 'results.pkl'
    model1_folder = out_folder + 'model1'
    model2_folder = out_folder + 'model2'
    # write out the results of the training
    with open(results_file,'wb') as f:
        pickle.dump(obj=((history1.history, history2.history), # histories for plotting
                         (valid_seqIDs,Yvalid_list,Yvalid_pred1,Yvalid_pred2)), # domains with their truths and predictions
                    file=f,
                    protocol=pickle.HIGHEST_PROTOCOL)
    # save sequence model and structure model
    model1.save(model1_folder,save_format = 'tf') # tensorflow SavedModel format
    model2.save(model2_folder,save_format = 'tf') # tensorflow SavedModel format
#!/cluster/gjb_lab/2472402/envs/ml-env/bin/python
#$ -pe smp 8
#$ -jc short
#$ -adds l_hard gpu 2
#$ -mods l_hard mfree 16G
#$ -m ea
#$ -M 2472402@dundee.ac.uk
#$ -cwd

# # HMM cross validation notebook

# Last ran on: 20/09/2021
# 
# This version runs on serialized dataset

# # Import modules 

# In[ ]:


# import modules
import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
from tensorflow import keras
from tensorflow.keras import layers
import numpy as np
import pandas as pd
import pickle
import sys
from datetime import datetime
from os import path
from joblib import Parallel,delayed

# # Helper functions 

# In[33]:


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

# obtain 7 sets of indices from resume.log, which is an output of shuffle.pl
def get_splits(resume_log_file):
    val_splits = []
    set_idx = -1
    cur_set = set() 
    with open(resume_log_file,'r') as f:
        lines = f.read().splitlines()
        for line in lines:
            if line.startswith('#SET'):
                if set_idx > -1:
                    val_splits.append(cur_set)
                    cur_set = set()
                set_idx += 1
            else:
                seqID = line.split('/')[-1].replace('.pssm','')
                cur_set.add(seqID)
        # append last set which is not followed by another line '#SET...'
        val_splits.append(cur_set)
    assert sum([len(s) for s in val_splits])==1348
    return val_splits


# # Cross-validation function

# In[ ]:


def run_CV(debug=False,**args):
    
    subtype = args['subtype']
    BATCH_SIZE = args['BATCH_SIZE']
    N_HID = args['N_HID']
    N_EPOCHS = args['N_EPOCHS']
    expt_name = args['expt_name']

    assert subtype in ['HMM','PSSMa','PSSMb']
    assert expt_name
    
    #kf = get_splits('/cluster/gjb_lab/2472402/data/retr231_shuffles/shuffle02/best_shuffle_th_1.log')
    with open('/cluster/gjb_lab/2472402/data/shuffle_keras/shuffle_1.05.pkl','rb') as f:
        kf,_ = pickle.load(f)
    kf = [[str(seqID) for seqID in kf_list] for kf_list in kf]
    
    ROOT='/cluster/gjb_lab/2472402/data/retr231/'
    subtype_root = {'HMM':'hmm','PSSMa':'pssm','PSSMb':'pssm'}[subtype]
    DATA=ROOT + subtype_root + '1.pkl'
    DSSP=ROOT+'dssp.pkl'    
    
    with open(DATA,'rb') as f:
        X=pickle.load(f)
    with open(DSSP,'rb') as f:
        y=pd.DataFrame(pickle.load(f))
    
    X.loc[:,'seqID'] = [c.split('_')[0] for c in X.index]
    y.loc[:,'seqID'] = [c.split('_')[0] for c in y.index]    
    
    for k in range(7):

        eprint('Beginning cross validation fold',k+1)
        
        # gather train and validation seqIDs
        valid_idx = list(kf[k])
        train_idx = (set().union(*(kf[0:k] + kf[k+1:])))
        # partition train and validation data
        X_train = X[X['seqID'].isin(train_idx)].drop(['seqID'],axis=1)
        X_valid = X[X['seqID'].isin(valid_idx)].drop(['seqID'],axis=1)
        y_train = y[y['seqID'].isin(train_idx)].drop(['seqID'],axis=1)
        y_valid = y[y['seqID'].isin(valid_idx)].drop(['seqID'],axis=1)
        
        # create output folder
        i = k+1
        subtype_dir = {'HMM':'HMM','PSSMa':'PSSM','PSSMb':'PSSMb'}[subtype]
        root_folder="/cluster/gjb_lab/2472402/outputs/keras_train_CV/%s/%s" % (subtype_dir,expt_name)
        assert os.path.exists(root_folder)
        # create out folder
        out_folder=os.path.join(root_folder, "cross-val%d/" % i)
        if path.exists(out_folder) and not debug:
            assert not os.listdir(out_folder), "Output directory %s exists and is not empty. Aborted." % out_folder
        else:
            if not path.exists(out_folder):
                os.system("mkdir %s" % out_folder)
            else:
                eprint(out_folder,'already exists and in debugging mode so using that.')

        if debug:
            X_train = X_train[::100]
            X_valid = X_valid[::100]
            y_train = y_train[::100]
            y_valid = y_valid[::100]

        if debug and os.path.exists(out_folder+'/model1'):
            eprint('In debugging mode and model1 found. Loading model1...')
            model1 = keras.models.load_model(out_folder+'/model1')
        else:
            # sequence to structure layer
            model1 = keras.Sequential([
                layers.Dense(units = N_HID, activation ='sigmoid', input_shape=[408 if subtype=='HMM' else 340]),
                layers.Dense(units = 3, activation ='softmax')
            ])

            model1.compile(optimizer='sgd', loss='categorical_crossentropy',metrics=['accuracy'])

            eprint('%s. Fitting layer 1 model.' % datetime.now().strftime("%H:%M:%S"))
            history1 = model1.fit(X_train, y_train,
                                  validation_data=(X_valid,y_valid),
                                  batch_size=BATCH_SIZE,
                                  epochs=N_EPOCHS,
                                  verbose=0)

            eprint('%s. Saving model 1...' % datetime.now().strftime("%H:%M:%S"))
            model1_folder = out_folder + 'model1'
            model1.save(model1_folder,save_format = 'tf') # tensorflow SavedModel format
        
        eprint('Processing layer 1 inputs for layer 2')
        # structure to structure layer
        train_group = X[X['seqID'].isin(train_idx)].groupby(['seqID'])
        valid_group = X[X['seqID'].isin(valid_idx)].groupby(['seqID'])
        Xtrain1_list = [groupby_df.drop(['seqID'],axis=1) for _,groupby_df in train_group]
        Xvalid1_list = [groupby_df.drop(['seqID'],axis=1) for _,groupby_df in valid_group]
        
        yvalid_group = y[y['seqID'].isin(valid_idx)].groupby(['seqID'])
        Yvalid_list= [groupby_df.drop(['seqID'],axis=1) for _,groupby_df in yvalid_group]
        valid_seqIDs = [groupby_df['seqID'][0] for _,groupby_df in yvalid_group]
        
        # fixed bug where valid_seqIDs was a list of pd.Series rather than a list of str
        assert all([isinstance(seqID,str) for seqID in valid_seqIDs])
        
        del valid_group, train_group, yvalid_group

        # skin the cat - pass layer 1 input through model 1 to get layer 2 input
        Xtrain2_list = [sliding_window(model1.predict(X),flank=9) for X in Xtrain1_list]
        Yvalid_pred1 = [model1.predict(X) for X in Xvalid1_list]
        Xvalid2_list = [sliding_window(X,flank=9) for X in Yvalid_pred1]

        Xtrain2=np.vstack(Xtrain2_list)
        Xvalid2=np.vstack(Xvalid2_list)

        if debug:
            Xtrain2 = Xtrain2[::100]
            Xvalid2 = Xvalid2[::100]
        
        if debug and os.path.exists(out_folder+'/model2'):
            eprint('In debugging mode and model2 found. Loading model2...')
            model2 = keras.models.load_model(out_folder+'/model2')
        else:
            # structure to structure layer
            model2 = keras.Sequential([
                layers.Dense(units = N_HID, activation ='sigmoid', input_shape=[57]),
                layers.Dense(units = 3, activation ='softmax')
            ])
            model2.compile(optimizer='sgd', loss='categorical_crossentropy',metrics=['accuracy'])

            eprint('%s. Fitting layer 2 model.' % datetime.now().strftime("%H:%M:%S"))
            history2 = model2.fit(Xtrain2, y_train,
                                  validation_data=(Xvalid2,y_valid),
                                  batch_size=BATCH_SIZE,
                                  epochs=N_EPOCHS,
                                  verbose=0) 

            eprint('%s. Saving layer 2 model.' % datetime.now().strftime("%H:%M:%S"))
            model2_folder = out_folder + 'model2'
            model2.save(model2_folder,save_format = 'tf') # tensorflow SavedModel format
        
            # free up RAM
            del Xtrain2, Xvalid2

        # get predictions for validation set (to calculate accuracy)
        eprint('%s. Generating layer 2 predictions.' % datetime.now().strftime("%H:%M:%S"))
        Yvalid_pred2=[model2.predict(X) for X in Xvalid2_list]

        # pickle training history and predictions for validation set 
        eprint('%s. Saving model history.' % datetime.now().strftime("%H:%M:%S"))
        results_file = out_folder + 'results.pkl'
        
        if debug:
            eprint('%s. Skipped saving of model history.' % datetime.now().strftime("%H:%M:%S"))
            with open(results_file,'wb') as f:
                pickle.dump(obj=((None,None), # histories for plotting
                                 (valid_seqIDs,Yvalid_list,Yvalid_pred1,Yvalid_pred2)), # domains with their truths and predictions
                            file=f,
                            protocol=pickle.HIGHEST_PROTOCOL)                
        else:
            with open(results_file,'wb') as f:
                pickle.dump(obj=((history1.history, history2.history), # histories for plotting
                                 (valid_seqIDs,Yvalid_list,Yvalid_pred1,Yvalid_pred2)), # domains with their truths and predictions
                            file=f,
                            protocol=pickle.HIGHEST_PROTOCOL)


# # Main code


if __name__ == "__main__":
    
    expt_name = '1Oct'
    N_EPOCHS = 300
    BATCH_SIZE = 128 
    DEBUG=0
    
    if DEBUG:
        eprint('Running in debugging mode')
        
    assert len(sys.argv)==2
    assert sys.argv[1] in ['hmm','pssma','pssmb']
    
    hmm = {
        'subtype':'HMM',
        'BATCH_SIZE':BATCH_SIZE,
        'N_HID':100,
        'N_EPOCHS':N_EPOCHS,
        'expt_name':expt_name
    }
    pssma = {
        'subtype':'PSSMa',
        'BATCH_SIZE':BATCH_SIZE,
        'N_HID':100,
        'N_EPOCHS':N_EPOCHS,
        'expt_name':expt_name
    }  
    pssmb = {
        'subtype':'PSSMb',
        'BATCH_SIZE':BATCH_SIZE,
        'N_HID':20,
        'N_EPOCHS':N_EPOCHS,
        'expt_name':expt_name
    }
     
    subtype = {'hmm':hmm,
               'pssma':pssma,
               'pssmb':pssmb}[sys.argv[1]]
    
    run_CV(debug=DEBUG,**subtype)


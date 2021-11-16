#!/cluster/gjb_lab/2472402/ml-env/bin/python
#$ -jc short
#$ -adds l_hard gpu 4
#$ -pe smp 16
#$ -mods l_hard mfree 16G
#$ -cwd

# # Combined HMM and PSSM cross validation script 

# ## Setup notebook

# In[1]:


import pandas as pd
import numpy as np
import os
import sys
import glob
import time
import random
from joblib import Parallel,delayed,Memory
import builtins 

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2' # suppress INFO and WARNING from tensorflow 
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import Sequential,layers

cachedir = './cachedir'
memory = Memory(cachedir,verbose=0)
data_dir = '/cluster/gjb_lab/2472402/data/retr231_raw_files/training/'


# ## Check sanity of data files

# In[2]:


def input_check():
    # not actually needed but it does a sanity check on input data
    dssp_files = glob.glob(data_dir + '*.dssp')
    hmm_files = glob.glob(data_dir + '*.hmm')
    pssm_files = glob.glob(data_dir + '*.pssm')
    seq_files = glob.glob(data_dir + '*.fasta')
    seqIDs = [f.split('/')[-1][:-5] for f in dssp_files]
    set_seqIDs_all = set([f.split('/')[-1][:-6] for f in seq_files])
    set_seqIDs = set(seqIDs)
    unused_seqIDs = set_seqIDs ^ set_seqIDs_all # 9 of them are unused
    seq_files = [f for f in seq_files if f.split('/')[-1][:-6] not in unused_seqIDs]
    assert all([len(x)==1348 for x in [dssp_files,hmm_files,pssm_files,seq_files,seqIDs]])

# ## Functions

# ### Train structure layer

# In[3]:


def train_struct_networks(train_idx_set,valid_idx_set,**params):
    
    lr = params['learning_rate']
    md = params['min_delta']
    fold_dir = params['fold_dir']
    epochs = params['epochs'] if params['epochs'] else 300
    
    train_data = generate_data_for_NN2(train_idx_set,fold_dir)
    valid_data = generate_data_for_NN2(valid_idx_set,fold_dir)
    
    # can have separate loss fn and optimizer for hmm and pssm in future
    loss_fn = keras.losses.CategoricalCrossentropy()
    optimizer = keras.optimizers.SGD(learning_rate=lr)
    hmm_metric_train = keras.metrics.CategoricalAccuracy()
    hmm_metric_valid = keras.metrics.CategoricalAccuracy()
    pssm_metric_train = keras.metrics.CategoricalAccuracy()
    pssm_metric_valid = keras.metrics.CategoricalAccuracy()
    ru = tf.keras.initializers.RandomUniform(minval=-0.05, maxval=0.05) # follow jpred

    hmm2_NN = Sequential([
        layers.Dense(units = 100, input_shape=[57], activation='sigmoid',kernel_initializer=ru),
        layers.Dense(units = 3, activation ='softmax',kernel_initializer=ru),
    ])
    pssm2_NN = Sequential([
        layers.Dense(units = 100, input_shape=[57], activation='sigmoid',kernel_initializer=ru),
        layers.Dense(units = 3, activation ='softmax',kernel_initializer=ru),
        ])
    
    @tf.function( # prevent retracing
        input_signature=[tf.TensorSpec(shape=(None,3)),
                         tf.TensorSpec(shape=(None,57)),
                         tf.TensorSpec(shape=(None,57)),
                        ]
    )
    def train_step(labels,hmm_data, pssm_data):
        # forward pass on hmm2 neural network
        with tf.GradientTape() as hmm_tape:
            hmm_proba = hmm2_NN(hmm_data, training=True)
            hmm_loss = loss_fn(labels, hmm_proba)

        # forward pass on pssm2 neural network
        with tf.GradientTape() as pssm_tape:
            pssm_proba = pssm2_NN(pssm_data, training=True)
            pssm_loss = loss_fn(labels, pssm_proba)

        hmm_grads = hmm_tape.gradient(hmm_loss, hmm2_NN.trainable_weights)
        pssm_grads = pssm_tape.gradient(pssm_loss, pssm2_NN.trainable_weights)

        optimizer.apply_gradients(zip(hmm_grads, hmm2_NN.trainable_weights))
        optimizer.apply_gradients(zip(pssm_grads, pssm2_NN.trainable_weights))

        hmm_metric_train.update_state(labels, hmm_proba)
        pssm_metric_train.update_state(labels, pssm_proba)

        return hmm_loss, pssm_loss

    @tf.function( 
        input_signature=[tf.TensorSpec(shape=(None,3)),
                         tf.TensorSpec(shape=(None,57)),
                         tf.TensorSpec(shape=(None,57)),
                        ]
    )
    def valid_step(labels,hmm_data, pssm_data):
        hmm_proba = hmm2_NN(hmm_data, training=False)
        pssm_proba = pssm2_NN(pssm_data, training=False)
        hmm_metric_valid.update_state(labels, hmm_proba)
        pssm_metric_valid.update_state(labels, pssm_proba)
        
        # return validation loss for early stopping
        hmm_loss = loss_fn(labels, hmm_proba)
        pssm_loss = loss_fn(labels, pssm_proba)
        
        return hmm_loss, pssm_loss
    
    # print to log2.txt
    def print(*args,**kwargs):
        with open(fold_dir + 'log2.txt','a') as f:
            kwargs['file']=f
            return builtins.print(*args,**kwargs)
        
    print('Training structure to structure networks...')
    
    hmm_valid_loss = [] # for early stopping
    pssm_valid_loss = []
    hmm_training_finished = False
    pssm_training_finished = False
    
    for epoch in range(epochs):
        start_time = time.time()
        
        epoch_hmm_Tloss = 0
        epoch_pssm_Tloss = 0
        train_seqIDs = list(train_data.keys())
        random.shuffle(train_seqIDs)
        for step, seqID in enumerate(train_seqIDs):
            batch_size = len(train_data[seqID])
            labels = train_data[seqID][:,0:3]
            hmm_data = train_data[seqID][:,3:60]
            pssm_data = train_data[seqID][:,60:117]
            
            labels = tf.convert_to_tensor(labels, dtype=tf.float32)
            hmm_data = tf.convert_to_tensor(hmm_data, dtype=tf.float32)
            pssm_data = tf.convert_to_tensor(pssm_data, dtype=tf.float32)
            
            hmm_loss,pssm_loss = train_step(labels,hmm_data,pssm_data)
            
            epoch_hmm_Tloss += hmm_loss/batch_size
            epoch_pssm_Tloss += pssm_loss/batch_size
            
        hmm_acc_train = hmm_metric_train.result()
        pssm_acc_train = pssm_metric_train.result()
        hmm_metric_train.reset_states()
        pssm_metric_train.reset_states()
        
        # end of epoch validation
        epoch_hmm_loss = 0
        epoch_pssm_loss = 0
        valid_seqIDs = list(valid_data.keys())
        random.shuffle(valid_seqIDs)
        for step, seqID in enumerate(valid_seqIDs):
            batch_size = len(valid_data[seqID])
            labels = valid_data[seqID][:,:3]
            hmm_data = valid_data[seqID][:,3:60]
            pssm_data = valid_data[seqID][:,60:117]
            labels = tf.convert_to_tensor(labels, dtype=tf.float32)
            hmm_data = tf.convert_to_tensor(hmm_data, dtype=tf.float32)
            pssm_data = tf.convert_to_tensor(pssm_data, dtype=tf.float32)
            
            hmm_loss,pssm_loss = valid_step(labels,hmm_data,pssm_data)
            
            epoch_hmm_loss += hmm_loss/batch_size
            epoch_pssm_loss += pssm_loss/batch_size
        
        hmm_acc_valid = hmm_metric_valid.result()
        pssm_acc_valid = pssm_metric_valid.result()
        hmm_metric_valid.reset_states()
        pssm_metric_valid.reset_states()
        
        print(
            "Epoch %d HMM_acc %.4f PSSM_acc %.4f HMM_loss %.4f PSSM_loss %.4f HMM_Tacc %.4f PSSM_Tacc %.4f HMM_Tloss %.4f PSSM_Tloss %.4f" 
            % (
            epoch, hmm_acc_valid, pssm_acc_valid, epoch_hmm_loss, epoch_pssm_loss,
                hmm_acc_train, pssm_acc_train, epoch_hmm_Tloss, epoch_pssm_Tloss
            )
        )
        
        # check for early stopping
        hmm_stopEarly = Callback_EarlyStopping(hmm_valid_loss, min_delta=md, patience=20)
        pssm_stopEarly = Callback_EarlyStopping(pssm_valid_loss, min_delta=md, patience=20)
        
        if not hmm_training_finished:
            if hmm_stopEarly:
                print("Early stopping for hmm2_NN at epoch %d/%d" % (epoch,epochs))
                hmm1_NN.save(fold_dir + 'hmm2_NN')
                hmm_training_finished = True
        
        if not pssm_training_finished:
            if pssm_stopEarly:
                print("Early stopping for pssm2_NN at epoch %d/%d" % (epoch,epochs))
                pssm1_NN.save(fold_dir + 'pssm2_NN')
                pssm_training_finished = True
        
        if hmm_training_finished and pssm_training_finished:
            print("Training finished at epoch %d/%d" % (epoch,epochs))
            break
            
    print("Training finished at epoch %d" % epochs)
    if hmm_training_finished:
        hmm2_NN.save(fold_dir + 'hmm2_NN_%d' % (epochs))
    else:
        hmm2_NN.save(fold_dir + 'hmm2_NN')
    if pssm_training_finished:
        pssm2_NN.save(fold_dir + 'pssm2_NN_%d' % (epochs))
    else:
        pssm2_NN.save(fold_dir + 'pssm2_NN')


# ### Train sequence layer 

# In[4]:


# Custom training loop 
# Called from within cross-validation loop
# once per cross-validation
def train_seq_networks(train_idx_set,valid_idx_set,**params):
    
    lr = params['learning_rate']
    md = params['min_delta']
    fold_dir = params['fold_dir']
    epochs = params['epochs'] if params['epochs'] else 300
    
    train_data = generate_data(train_idx_set)
    valid_data = generate_data(valid_idx_set)
    
    # can have separate loss fn and optimizer for hmm and pssm in future
    loss_fn = keras.losses.CategoricalCrossentropy()
    optimizer = keras.optimizers.SGD(learning_rate=lr)
    ru = tf.keras.initializers.RandomUniform(minval=-0.05, maxval=0.05) # follow jpred
    hmm_metric = keras.metrics.CategoricalAccuracy()
    pssm_metric = keras.metrics.CategoricalAccuracy()
    
    hmm1_NN = Sequential([
        layers.Dense(units = 100, input_shape=[408], activation='sigmoid',kernel_initializer=ru),
        layers.Dense(units = 3, activation ='softmax',kernel_initializer=ru),
    ])
    pssm1_NN = Sequential([
        layers.Dense(units = 100, input_shape=[340], activation='sigmoid',kernel_initializer=ru),
        layers.Dense(units = 3, activation ='softmax',kernel_initializer=ru),
    ])
    
    @tf.function(input_signature=[tf.TensorSpec(shape=(None,3)),
                         tf.TensorSpec(shape=(None,408)),
                         tf.TensorSpec(shape=(None,340)),])
    def train_step(labels,hmm_data,pssm_data):
        # forward pass on hmm1 neural network
        with tf.GradientTape() as hmm_tape:
            hmm_proba = hmm1_NN(hmm_data, training=True)
            hmm_loss = loss_fn(labels, hmm_proba)

        # forward pass on pssm1 neural network
        with tf.GradientTape() as pssm_tape:
            pssm_proba = pssm1_NN(pssm_data, training=True)
            pssm_loss = loss_fn(labels, pssm_proba)

        hmm_grads = hmm_tape.gradient(hmm_loss, hmm1_NN.trainable_weights)
        pssm_grads = pssm_tape.gradient(pssm_loss, pssm1_NN.trainable_weights)

        optimizer.apply_gradients(zip(hmm_grads, hmm1_NN.trainable_weights))
        optimizer.apply_gradients(zip(pssm_grads, pssm1_NN.trainable_weights))
        
        return hmm_loss,pssm_loss

     
    @tf.function(input_signature=[tf.TensorSpec(shape=(None,3)),
                                  tf.TensorSpec(shape=(None,408)),
                                  tf.TensorSpec(shape=(None,340)),])
    def valid_step(labels,hmm_data, pssm_data):
        hmm_proba = hmm1_NN(hmm_data, training=False)
        pssm_proba = pssm1_NN(pssm_data, training=False)
        
        hmm_metric.update_state(labels, hmm_proba)
        pssm_metric.update_state(labels, pssm_proba)
        
        # return validation loss for early stopping
        hmm_loss = loss_fn(labels, hmm_proba)
        pssm_loss = loss_fn(labels, pssm_proba)
        return hmm_loss, pssm_loss
    
    # print to log.txt
    def print(*args,**kwargs):
        with open(fold_dir + 'log.txt','a') as f:
            kwargs['file']=f
            return builtins.print(*args,**kwargs)
    
    print('Training sequence to structure networks...')
    hmm_valid_loss = [] # for early stopping
    pssm_valid_loss = []
    hmm_training_finished = False
    pssm_training_finished = False
    
    for epoch in range(epochs):
        start_time = time.time()
        
        epoch_hmm_Tloss = 0
        epoch_pssm_Tloss = 0
        train_seqIDs = list(train_data.keys())
        random.shuffle(train_seqIDs)
        for step, seqID in enumerate(train_seqIDs):
            
            batch_size = len(train_data[seqID])
            labels = train_data[seqID][:,0:3]
            hmm_data = train_data[seqID][:,3:411]
            pssm_data = train_data[seqID][:,411:751]
            labels = tf.convert_to_tensor(labels, dtype=tf.float32)
            hmm_data = tf.convert_to_tensor(hmm_data, dtype=tf.float32)
            pssm_data = tf.convert_to_tensor(pssm_data, dtype=tf.float32)
            
            hmm_loss, pssm_loss = train_step(labels,hmm_data,pssm_data)
            
            epoch_hmm_Tloss += hmm_loss/batch_size
            epoch_pssm_Tloss += pssm_loss/batch_size
        
        # calculate training accuracy
        for step, seqID in enumerate(train_seqIDs):
            batch_size = len(train_data[seqID])
            labels = train_data[seqID][:,0:3]
            hmm_data = train_data[seqID][:,3:411]
            pssm_data = train_data[seqID][:,411:751]
            labels = tf.convert_to_tensor(labels, dtype=tf.float32)
            hmm_data = tf.convert_to_tensor(hmm_data, dtype=tf.float32)
            pssm_data = tf.convert_to_tensor(pssm_data, dtype=tf.float32)
            
            valid_step(labels,hmm_data,pssm_data)
        
        hmm_acc_train = hmm_metric.result()
        pssm_acc_train = pssm_metric.result()
        hmm_metric.reset_states()
        pssm_metric.reset_states()
        
        # end of epoch validation
        epoch_hmm_loss = 0
        epoch_pssm_loss = 0
        valid_seqIDs = list(valid_data.keys())
        random.shuffle(valid_seqIDs)
        for step, seqID in enumerate(valid_seqIDs):
            batch_size = len(valid_data[seqID])
            labels = valid_data[seqID][:,:3]
            hmm_data = valid_data[seqID][:,3:411]
            pssm_data = valid_data[seqID][:,411:751]
            labels = tf.convert_to_tensor(labels, dtype=tf.float32)
            hmm_data = tf.convert_to_tensor(hmm_data, dtype=tf.float32)
            pssm_data = tf.convert_to_tensor(pssm_data, dtype=tf.float32)
            
            hmm_loss, pssm_loss = valid_step(labels,hmm_data,pssm_data)
            
            epoch_hmm_loss += hmm_loss/batch_size
            epoch_pssm_loss += pssm_loss/batch_size
        
        hmm_valid_loss.append(epoch_hmm_loss)
        pssm_valid_loss.append(epoch_pssm_loss)
        hmm_acc_valid = hmm_metric.result()
        pssm_acc_valid = pssm_metric.result()
        hmm_metric.reset_states()
        pssm_metric.reset_states()
        
        print(
            "Epoch %d HMM_acc %.4f PSSM_acc %.4f HMM_loss %.4f PSSM_loss %.4f HMM_Tacc %.4f PSSM_Tacc %.4f HMM_Tloss %.4f PSSM_Tloss %.4f" 
            % (
            epoch, hmm_acc_valid, pssm_acc_valid, epoch_hmm_loss, epoch_pssm_loss,
                hmm_acc_train, pssm_acc_train, epoch_hmm_Tloss, epoch_pssm_Tloss
            )
        )
        
        # check for early stopping
        hmm_stopEarly = Callback_EarlyStopping(hmm_valid_loss, min_delta=md, patience=20)
        pssm_stopEarly = Callback_EarlyStopping(pssm_valid_loss, min_delta=md, patience=20)
        
        if not hmm_training_finished:
            if hmm_stopEarly:
                print("Early stopping for hmm1_NN at epoch %d/%d" % (epoch,epochs))
                hmm1_NN.save(fold_dir + 'hmm1_NN')
                hmm_training_finished = True
        
        if not pssm_training_finished:
            if pssm_stopEarly:
                print("Early stopping for pssm1_NN at epoch %d/%d" % (epoch,epochs))
                pssm1_NN.save(fold_dir + 'pssm1_NN')
                pssm_training_finished = True
        
        if hmm_training_finished and pssm_training_finished:
            print("Training finished at epoch %d/%d" % (epoch,epochs))
            break
            
    print("Training finished at epoch %d" % epochs)
    if hmm_training_finished:
        hmm1_NN.save(fold_dir + 'hmm1_NN_%d' % (epochs))
    else:
        hmm1_NN.save(fold_dir + 'hmm1_NN')
    if pssm_training_finished:
        pssm1_NN.save(fold_dir + 'pssm1_NN_%d' % (epochs))
    else:
        pssm1_NN.save(fold_dir + 'pssm1_NN')


# ### Callback fn 


# In[6]:


def Callback_EarlyStopping(LossList, min_delta=0.1, patience=20):
    #No early stopping for 2*patience epochs 
    if len(LossList)//patience < 2 :
        return False
    #Mean loss for last patience epochs and second-last patience epochs
    mean_previous = np.mean(LossList[::-1][patience:2*patience]) #second-last
    mean_recent = np.mean(LossList[::-1][:patience]) #last
    #you can use relative or absolute change
    delta_abs = np.abs(mean_recent - mean_previous) #abs change
    delta_abs = np.abs(delta_abs / mean_previous)  # relative change
    return delta_abs < min_delta


# ### Generate data

# In[7]:


@memory.cache
def generate_data_for_NN2(set_of_seqID,fold_dir):
    hmm1_NN = keras.models.load_model(fold_dir+'hmm1_NN')
    pssm1_NN = keras.models.load_model(fold_dir+'pssm1_NN')
    data_in = generate_data(set_of_seqID)
    
    def process_seqID(data):
        label = data[:,:3]
        hmm1_in = data[:,3:411]
        pssm1_in = data[:,411:751]
        hmm1_out = hmm1_NN(hmm1_in, training=False).numpy()
        pssm1_out = pssm1_NN(pssm1_in, training=False).numpy()
        hmm2_in = sliding_window(hmm1_out, flank=9)
        pssm2_in = sliding_window(pssm1_out, flank=9)
        assert hmm2_in.shape[1]==57
        assert pssm2_in.shape[1]==57
        result = np.concatenate([label,hmm2_in,pssm2_in],axis=1)
        return result
    
    arr_dict = {}
    start_time = time.time()
    for seqID in set_of_seqID:
        arr_dict[seqID] = process_seqID(data_in[seqID])
    print("Took %s seconds to process %d seqIDs" % (time.time() - start_time, len(set_of_seqID)))
    return arr_dict
        
# run this function to process multiple IDs
def generate_data(seqIDs):
    arr_list = Parallel(n_jobs=-1,verbose=0)(delayed(process_seqID)(seqID) for seqID in seqIDs)
    return {seqID: arr for seqID, arr in zip(seqIDs,arr_list)}

# get splits from resume.log generated by Perl shuffling scripts 
# returns sets of strings of seqIDs 
@memory.cache
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

# produces a single numpy array for each sequence
@memory.cache
def process_seqID(seqID):
    data_dir = '/cluster/gjb_lab/2472402/data/retr231_raw_files/training/'
    hmm_path = data_dir + seqID + '.hmm'
    pssm_path = data_dir + seqID + '.pssm'
    dssp_path = data_dir + seqID + '.dssp'
    assert os.path.exists(pssm_path)
    hmm = np.loadtxt(hmm_path,delimiter=' ')
    hmm = sliding_window(hmm,flank=8)
    pssm = np.loadtxt(pssm_path,delimiter=' ')
    pssm = sliding_window(pssm,flank=8)
    dssp = get_dssp(dssp_path)
    res = np.concatenate([dssp,hmm,pssm],axis=1)
    return res


# ### Old functions

# In[8]:


# in: np array. out: np array linearized over sliding window
def sliding_window(array, flank):
    assert flank > 0
    assert type(array) is np.ndarray
    assert np.logical_not(np.isnan(np.sum(array)))
    nrow = array.shape[0]
    assert nrow > 0
    ncol = array.shape[1]
    assert ncol > 0
    res = np.empty(shape=(nrow, (2*flank+1)*ncol),dtype=np.float32)
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

def encode(s):
    res = np.empty(shape=(len(s),3),dtype=np.byte)
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

def get_dssp(dssp_path):
    with open(dssp_path,'r') as f:
        dssp = f.read().strip()
    return encode(dssp)


# ### Run CV

# In[15]:


def split_train_valid(val_fold):
    valid_set = val_splits[val_fold]
    train_set = set().union(*(val_splits[:val_fold] + val_splits[val_fold+1:]))
    return train_set, valid_set

# main cross validation function here
def run_cross_validation(val_splits):
    
    def split_train_valid(val_fold):
        valid_set = val_splits[val_fold]
        train_set = set().union(*(val_splits[:val_fold] + val_splits[val_fold+1:]))
        return train_set, valid_set    
    
    def train_fold(fold):
        train_set, valid_set = split_train_valid(fold)
        fold_dir = './18-09-1/%s/' % fold
        if not os.path.exists(fold_dir):
            os.system('mkdir -p ' + fold_dir)
            
        seq_NN_params = {
            'fold_dir' : fold_dir,
            'learning_rate':1e-2,
            'min_delta':1e-3,
            'epochs':300,
        }
        struct_NN_params = {
            'fold_dir' : fold_dir,
            'learning_rate':1e-2,
            'min_delta':1e-3,
            'epochs':300,
        }
        train_seq_networks(train_set, valid_set, **seq_NN_params)
        train_struct_networks(train_set, valid_set, **struct_NN_params)
    
    #return Parallel(n_jobs=-1,verbose=0)(delayed(train_fold)(fold) for fold in range(7))
    
    for fold in range(7):
        train_fold(fold)


# ## Current cell

if __name__ == "__main__":
    val_splits = get_splits('/cluster/gjb_lab/2472402/data/retr231_shuffles/shuffle02/best_shuffle_th_1.log')
    run_cross_validation(val_splits)


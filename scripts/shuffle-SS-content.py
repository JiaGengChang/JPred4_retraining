#!/cluster/gjb_lab/2472402/ml-env/bin/python
#$ -jc short
#$ -pe smp 4
#$ -mods l_hard mfree 2G
#$ -cwd

import os
import numpy as np
import pandas as pd
import pickle
import sys
from os import path
import glob
import random
import pickle
from joblib import Memory
pd.options.display.float_format = "{:,.2f}".format
cachedir = './cachedir'
memory = Memory(cachedir,verbose=0)


# In[45]:


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
                seqID = int(line.split('/')[-1].replace('.pssm',''))
                cur_set.add(seqID)
        # append last set which is not followed by another line '#SET...'
        val_splits.append(cur_set)
    assert sum([len(s) for s in val_splits])==1348
    return val_splits

def read_sec_df():
    df = pd.read_csv('/cluster/gjb_lab/2472402/data/1507_sec.csv',names=['seqID','domain','sec'])
    return df

@memory.cache
def sec_to_arr(sec_string):
    res = np.empty(shape=(len(sec_string),3))
    res[:] = np.nan
    for i in range(0,len(sec_string)):
        if sec_string[i:i+1] == 'H':
            res[i] = np.array([0,1,0])
        else:
            if sec_string[i:i+1] == 'E' or sec_string[i:i+1] == 'B':
                res[i] = np.array([1,0,0])
            else:
                assert sec_string[i:i+1] != None
                res[i] = np.array([0,0,1])
    assert not np.isnan(np.sum(res))
    return pd.DataFrame(res)


@memory.cache
def build_cache():
    cache = {}
    sec_df = read_sec_df()
    for i,row in sec_df.iterrows():
        cache[row.seqID] = sec_to_arr(row.sec)
    assert len(cache) == 1507
    return cache

def get_content_df_from_file(resume_log_file):
    df = read_sec_df()
    kf = get_splits(resume_log_file)
    content_df = []
    for i,idxs in enumerate(kf):
        arr = list(map(lambda s: sec_to_arr(s), df[df.seqID.isin(idxs)].sec))
        arr = pd.concat(arr)
        E, H, C = arr.sum(axis=0)/len(arr) * 100
        content_df.append([i,H,E,C])
    
    return pd.DataFrame(content_df,columns=['Fold','Helix','Sheet','Coil'])


def check_df(df,threshold):
    H = df.loc[7,'Helix']
    E = df.loc[7,'Sheet']
    C = df.loc[7,'Coil']
    return H < threshold and E < threshold and C < threshold    


def split_list(ls):
    res = []
    k = int(np.ceil(len(ls)/7))
    idxs = range(0,len(ls),k)
    
    for i in idxs:
        res.append(ls[i:i+k])

    return res

def get_best_split(threshold):
    
    seqIDs = [int(f.split('/')[-1][:-5]) for f in glob.glob('/cluster/homes/adrozdetskiy/Projects/jpredJnet231ReTrainingSummaryTable/scores/training/*.pssm')]
    
    cache = build_cache()
    
    def get_content_df():
        content_df = []
        splits = split_list(seqIDs)
        for i,split in enumerate(splits):
            arr = [cache[seqID] for seqID in split]
            arr = pd.concat(arr)
            E, H, C = arr.sum(axis=0)/len(arr) * 100
            content_df.append([i,H,E,C])
        content_df = pd.DataFrame(content_df,columns=['Fold','Helix','Sheet','Coil'])
        dH =  content_df.Helix.max() - content_df.Helix.min()
        dE =  content_df.Sheet.max() - content_df.Sheet.min()
        dC = content_df.Coil.max() - content_df.Coil.min()
        content_df.loc[len(content_df)] = [7,dH,dE,dC]
        return splits,content_df
    
    i = 0
    
    while True:
        i += 1
        random.shuffle(seqIDs)
        splits,content_df = get_content_df()
        if check_df(content_df, threshold):
            break
    
    print(f'Done. Took {i} iterations to find a shuffle with threshold of {threshold}')
    
    return splits,content_df
        


# # Main function

# In[54]:

threshold = 1.05

splits,df = get_best_split(threshold)

with open('shuffle_%s.pkl' % str(threshold),'wb') as f:
    pickle.dump((splits,df),f,protocol = pickle.HIGHEST_PROTOCOL)


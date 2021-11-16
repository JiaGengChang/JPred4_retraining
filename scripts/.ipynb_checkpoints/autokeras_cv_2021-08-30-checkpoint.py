import os
import pickle
import numpy as np
import pandas as pd
import autokeras as ak
import tensorflow as tf


hmm_f='/cluster/gjb_lab/2472402/data/retr231/hmm1.pkl'
pssm_f='/cluster/gjb_lab/2472402/data/retr231/pssm1.pkl'
dssp_f='/cluster/gjb_lab/2472402/data/retr231/dssp.pkl'



with open(hmm_f,'rb') as f:
    hmm1=pickle.load(f)


with open(dssp_f,'rb') as f:
    dssp=pickle.load(f)


clf = ak.StructuredDataClassifier(seed=0,max_trials=50)


history= clf.fit(x=hmm1,y=dssp,validation_split=1/7)


with open('historydf.pkl','wb') as f:
    pd.to_csv(pd.DataFrame(history.history),f)
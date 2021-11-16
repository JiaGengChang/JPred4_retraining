import sys
import pickle
import pandas as pd
import autokeras as ak
import tensorflow as tf

assert len(sys.argv)==2

subtype=sys.argv[1] # [0] is program name

assert subtype=='hmm' or subtype=='pssm', 'argument can only be pssm or hmm'

data_f='/cluster/gjb_lab/2472402/data/retr231/%s1.pkl' % subtype
dssp_f='/cluster/gjb_lab/2472402/data/retr231/dssp.pkl'

with open(data_f,'rb') as f:
    data=pickle.load(f)


with open(dssp_f,'rb') as f:
    dssp=pickle.load(f)


clf = ak.StructuredDataClassifier(seed=0,max_trials=50)


history= clf.fit(x=data,y=dssp,validation_split=1/7, epochs=300)

model=clf.export_model()

try:
    model.save("model_autokeras",save_format="tf")
except Exception:
    model.save("model_autokeras.h5")


with open('historydf.pkl','wb') as f:
    pd.to_csv(pd.DataFrame(history.history),f)

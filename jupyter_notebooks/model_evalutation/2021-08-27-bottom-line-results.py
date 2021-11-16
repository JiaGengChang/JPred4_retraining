#!/usr/bin/env python
# coding: utf-8

# ## Calculating numerical accuracies 

# In[1]:


import pandas as pd


# In[2]:


i=1


# In[29]:


# snns 25 Aug and keras 26 Aug are the same
# go and look at the seqIDs for each fold of CV to know
keras_path="/cluster/gjb_lab/2472402/results/keras/26Aug_jpred/cv%d_scores.csv" % i
snns_path="/cluster/gjb_lab/2472402/results/snns/26Aug_jpred/cv%d_scores.csv" % i
snns=pd.read_csv(snns_path).set_index('seqID')
keras=pd.read_csv(keras_path).set_index('seqID')


# In[15]:


keras


# In[30]:


snns.columns = map(lambda x: 'snns_'+x, snns.columns)

keras.columns = map(lambda x: 'keras_'+x, keras.columns)


# In[32]:


df = pd.concat([keras,snns],axis=1)
df


# In[41]:


D
df.drop([x for x in df.columns if x.endswith('sov')],axis=1).mean()


# In[9]:


outfile='/cluster/gjb_lab/2472402/results/16Sep_snns_20Sep_2_keras.csv'

snns_all = []
keras_all = []

with open(outfile, 'w+') as f:
    # write header
    f.write('fold,SNNS_jpred_acc,Keras_jpred_acc,SNNS_HMM_acc,Keras_HMM_acc,SNNS_PSSM_acc,Keras_PSSM_acc\n')
    for i in range(1,8):
        keras_path="/cluster/gjb_lab/2472402/results/keras/20Sep_2/cv%d_scores.csv" % i # <= change here
        snns_path="/cluster/gjb_lab/2472402/results/snns/20Sep/cv%d_scores.csv" % i  # <= change here
        snns=pd.read_csv(snns_path).set_index('seqID')
        keras=pd.read_csv(keras_path).set_index('seqID')
        f.write("%d," % i)
        f.write("%.2f ± %.2f" % (snns.JNET_acc.mean(),snns.JNET_acc.std()) + ',')
        f.write("%.2f ± %.2f" % (keras.JNET_acc.mean(),keras.JNET_acc.std()) + ',')
        f.write("%.2f ± %.2f" % (snns.HMM_acc.mean(),snns.HMM_acc.std()) + ',')
        f.write("%.2f ± %.2f" % (keras.HMM_acc.mean(),keras.HMM_acc.std()) + ',')
        f.write("%.2f ± %.2f" % (snns.PSSM_acc.mean(),snns.PSSM_acc.std()) + ',')
        f.write("%.2f ± %.2f" % (keras.PSSM_acc.mean(),keras.PSSM_acc.std()) + '\n')
        snns_all.append(snns)
        keras_all.append(keras)

# out-of-fold mean and std for all 1348 
snns = pd.concat(snns_all) 
keras = pd.concat(keras_all) 

with open(outfile,'a') as f:
    f.write('combined,')
    f.write("%.2f ± %.2f" % (snns.JNET_acc.mean(),snns.JNET_acc.std()) + ',')
    f.write("%.2f ± %.2f" % (keras.JNET_acc.mean(),keras.JNET_acc.std()) + ',')
    f.write("%.2f ± %.2f" % (snns.HMM_acc.mean(),snns.HMM_acc.std()) + ',')
    f.write("%.2f ± %.2f" % (keras.HMM_acc.mean(),keras.HMM_acc.std()) + ',')
    f.write("%.2f ± %.2f" % (snns.PSSM_acc.mean(),snns.PSSM_acc.std()) + ',')
    f.write("%.2f ± %.2f" % (keras.PSSM_acc.mean(),keras.PSSM_acc.std()) + '\n')


# In[ ]:





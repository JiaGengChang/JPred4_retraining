#!/usr/bin/env python
# coding: utf-8

# ### Copied from CV-plots.ipynb

# # --- Analysis of HMM cross-validation results ---

# Run this cell to import HMM results

# In[49]:


import pickle
import pandas as pd
import matplotlib.pyplot as plt

paths = ['/cluster/gjb_lab/2472402/outputs/keras_train_CV/PSSMb/21Sep/cross-val%d/results.pkl' % i for i in range(1,8)]
# results[i][0][0] <- history of fold i model 1
# results[i][0][0] <- history of fold i model 2
results = [pickle.load(open(f, 'rb'))[0] for f in paths]


# ## 1. Training loss and validation loss

# In[47]:


for fold, (r1,r2) in enumerate(results):
    
    fold += 1 # fold 1 to 7
     
    # drop the 10 epochs as the losses decline sharply
    r1 = pd.DataFrame(r1)[['loss','val_loss']]
    r1.columns = {'train_CCE','valid_CCE'}
    # do this to silent the text output of plot()
    null_pointer = plt.plot(r1[10:])
    plt.title('HMM | cross-val fold %d | sequence-to-structure layer' % fold)
    plt.legend(r1, loc='center right')
    plt.xlabel('epochs')
    plt.ylabel('categorical cross entropy loss')
    plt.show()
    plt.savefig(f'./fold_{fold}_layer_1_losses.png')
    plt.clf()
    
    # repeat for layer 2 results
    r2 = pd.DataFrame(r2)[['loss','val_loss']]
    r2.columns = {'train_CCE','valid_CCE'}
    # do this to silent the text output of plot()
    null_pointer = plt.plot(r2[10:])
    plt.title('HMM | cross-val fold %d | structure-to-structure layer' % fold)
    plt.legend(r2, loc='center right')
    plt.xlabel('epochs')
    plt.ylabel('categorical cross entropy loss')
    plt.show()
    plt.savefig(f'./fold_{fold}_layer_2_losses.png')
    plt.clf()
    
    print('#############################################################')


# In[50]:


for fold, (r1,r2) in enumerate(results):
    
    fold += 1 # fold 1 to 7
     
    # drop the 10 epochs as the losses decline sharply
    r1 = pd.DataFrame(r1)[['accuracy','val_accuracy']]
    r1.columns = {'train_accuracy','valid_accuracy'}
    # do this to silent the text output of plot()
    null_pointer = plt.plot(r1[10:])
    plt.title('HMM | cross-val fold %d | sequence-to-structure layer' % fold)
    plt.legend(r1, loc='center right')
    plt.xlabel('epochs')
    plt.ylabel('Accuracy')
    plt.show()
    plt.savefig(f'./fold_{fold}_layer_1_metrics.png')
    plt.clf()
    
    # repeat for layer 2 results
    r2 = pd.DataFrame(r2)[['accuracy','val_accuracy']]
    r2.columns = {'train_accuracy','valid_accuracy'}
    # do this to silent the text output of plot()
    null_pointer = plt.plot(r2[10:])
    plt.title('HMM | cross-val fold %d | structure-to-structure layer' % fold)
    plt.legend(r2, loc='center right')
    plt.xlabel('epochs')
    plt.ylabel('Accuracy')
    plt.show()
    plt.savefig(f'./fold_{fold}_layer_2_metrics.png')
    plt.clf()
    
    print('#############################################################')


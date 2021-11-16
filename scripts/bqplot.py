#!/usr/bin/env python
# coding: utf-8

# # Plot SNNS vs Keras scatterplot

# This compares joint prediction of snns vs joint prediction of keras. Does not look at hmm and pssm

# In[1]:


import pandas as pd
import bqplot
from bqplot import (
    LinearScale, Scatter, Lines, Figure, Axis, pyplot as plt
)
import ipywidgets
from IPython.display import display


# In[2]:


d_path='/cluster/gjb_lab/2472402/data/dssp_dict.csv'
seq_dict=dict()
with open(d_path,'r') as f:
    rows=f.read().splitlines()
    while (rows):
        row=rows.pop(0)
        domain, seqID = row.split(',')
        seq_dict[int(seqID)]=domain


# In[3]:


d_path='/cluster/gjb_lab/2472402/data/1507_sec.csv'
seq_dict=dict()
with open(d_path,'r') as f:
    rows=f.read().splitlines()
    while (rows):
        row=rows.pop(0)
        seqID, domain, sec = row.split(',')
        seq_dict[int(seqID)]={'dom':domain,'sec':sec}
        


# In[8]:


def plot_scatter(i):
    
    keras_path="/cluster/gjb_lab/2472402/results/keras/21Sep/cv%d_scores.csv" % i # path to accuracy values
    snns_path="/cluster/gjb_lab/2472402/results/keras/20Sep/cv%d_scores.csv" % i
    snns=pd.read_csv(snns_path)
    keras=pd.read_csv(keras_path)
    seqIDs=snns.seqID
    snns=snns.set_index('seqID')
    keras=keras.set_index('seqID')
    keras_path_2="/cluster/gjb_lab/2472402/results/keras/21Sep/cv%d.knet" % i # path to dssp and predictions
    snns_path_2="/cluster/gjb_lab/2472402/results/keras/20Sep/cv%d.knet" % i
    dssp=[]
    snns_pred=[]
    keras_pred=[]
    snns_confs=[]
    keras_confs=[]

    # accumulate the 3 lists above
    with open(keras_path_2) as f:
        rows=f.read().splitlines()
        while (rows):
            row=rows.pop(0)
            if (row.startswith('DSSP')):
                dssp.append(row[12:])
            elif (row.startswith('JNET_pred')):
                keras_pred.append(row[12:])
            elif (row.startswith('JNET_conf')):
                keras_confs.append(row[12:])
            else:
                continue

    with open(snns_path_2) as f:
        rows=f.read().splitlines()
        while (rows):
            row=rows.pop(0)
            if (row.startswith('JNET_pred')):
                snns_pred.append(row[12:])
            elif (row.startswith('JNET_conf')):
                snns_confs.append(row[12:])
            else:
                continue
    
    # dictionary of things to display in Output widget or whatever display option
    dpred=dict()
    for (seqID,dssp_str,snns_jpred,keras_jpred,snns_conf,keras_conf) in zip (seqIDs,dssp,snns_pred,keras_pred,snns_confs,keras_confs):
        dpred[seqID]={'domain':seq_dict[seqID]['dom'],
                      'dssp8_str':seq_dict[seqID]['sec'],
                      'dssp3_str':dssp_str,
                      'snns_jpred':snns_jpred,
                      'snns_conf':snns_conf,
                      'keras_jpred':keras_jpred,
                      'keras_conf':keras_conf,
                     }

    x_data=snns.HMM_acc
    y_data=keras.HMM_acc

    x_sc=bqplot.LinearScale()
    y_sc=bqplot.LinearScale()

    ax_x = Axis(label='SNNS HMM acc', scale=x_sc, tick_format='0.1f')
    ax_y = Axis(label='Keras HMM acc', scale=y_sc, orientation='vertical', tick_format='0.1f')

    # create Output widget
    out=ipywidgets.Output()
    
    # define function to run when I hover over a mark
    def hover_function(_,event):
        out.clear_output()
        out.layout={'max_width':'95%'}
        out.layout={'width':'1500px'}
        with out:
            seqID=event['data']['name']
            val_x=event['data']['x']
            val_y=event['data']['y']
            domain=dpred[seqID]['domain']
            dssp8_str=dpred[seqID]['dssp8_str']
            dssp3_str=dpred[seqID]['dssp3_str']
            snns_jpred=dpred[seqID]['snns_jpred']
            keras_jpred=dpred[seqID]['keras_jpred']
            snns_conf=dpred[seqID]['snns_conf']
            keras_conf=dpred[seqID]['keras_conf']
            
            print('%s %s (seqID,SCOPe)' % (seqID,domain))
            print('%s %s (snns,keras)' % (val_x,val_y))
            print('dssp8:  %s' % dssp8_str)
            print('dssp3:  %s' % dssp3_str)
            print('snns:   %s' % snns_jpred)
            print('conf:   %s' % snns_conf)
            print('keras:  %s' % keras_jpred)
            print('conf:   %s' % keras_conf)
    
    scatter=Scatter(x=x_data,
                    y=y_data,
                    scales={'x': x_sc, 'y': y_sc},
                    names=seqIDs,
                    display_names=False,
                    tooltip=out,
                    opacities=[0.5],
                    interactions={'click':'select','hover':'tooltip'},
                    hovered_style={'opacity':1.0,'fill':'DarkOrange'},
                    unhovered_style={'opacity':0.2,},
                    selected_style={'opacity':1.0,'fill':'DarkOrange'},
                   )

    scatter.on_hover(hover_function)
    
    line=Lines(x=[60,100],y=[60,100],
               scales={'x': x_sc, 'y': y_sc},
               colors=['White'],
               stroke_width=0.5,
               line_style='dashed'
              )

    fig=Figure(title='Cross-validation fold %d accuracies' % i,
           marks=[scatter,line],
           axes=[ax_x,ax_y],
           layout={'height':'900px','width':'900px'},
          )
    
    return fig


# In[9]:


CROSS_VAL_FOLD=5
fig=plot_scatter(CROSS_VAL_FOLD)
display(fig)
fig.save_png(f'scatter_{CROSS_VAL_FOLD}.png')

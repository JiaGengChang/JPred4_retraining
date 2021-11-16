#!/usr/bin/env python
# coding: utf-8

# # Create .csv and .knet files

# Create cv1_score.csv files and cv1.knet files that include jpred predictions based on SNNS cross-validation outputs
# 
# These files are used by notebooks which generate scatterplots
# 
# Compared to 2021-08-27-jury-keras.ipynb, the routine is a lot simpler because joint prediction is already done, only need to read it from the .jnet files

# In[1]:


import os
import subprocess
import pandas as pd


# In[2]:


# function to give SOV and accuracy given sequence, dssp, and predictions
# same code as 2021-08-27-jury-keras.ipynb
def calc(outfolder,seqID,seq,dssp,hmm_pred,pssm_pred,jpred): 
    n=len(seq)
    assert n!=0
    assert all(_==n for _ in [len(dssp),len(hmm_pred),len(pssm_pred)])
    jpred=jpred.replace('-','C')
    hmm_pred=hmm_pred.replace('-','C')
    pssm_pred=pssm_pred.replace('-','C')
    dssp=dssp.replace('-','C')
    # write three sov.in file
    hmm_sov_in=os.path.join(outfolder,'%s.hmm.sov.in' % seqID)
    pssm_sov_in=os.path.join(outfolder,'%s.pssm.sov.in' % seqID)
    jpred_sov_in=os.path.join(outfolder,'%s.jpred.sov.in' % seqID)
    
    with open(hmm_sov_in,'w+') as f_hmm, open(pssm_sov_in,'w+') as f_pssm, open(jpred_sov_in,'w+') as f_jpred:
        f_hmm.write("AA  OSEC PSEC\n")
        f_pssm.write("AA  OSEC PSEC\n")
        f_jpred.write("AA  OSEC PSEC\n")
        for (aa,osec,psec_hmm,psec_pssm,psec_jpred) in zip(seq,dssp,hmm_pred,pssm_pred,jpred): # no commas allowed
            f_hmm.write("%s   %s    %s\n" % (aa,osec,psec_hmm))
            f_pssm.write("%s   %s    %s\n" % (aa,osec,psec_pssm))
            f_jpred.write("%s   %s    %s\n" % (aa,osec,psec_jpred))
    
    hmm_sov_out=os.path.join(outfolder,'%s.hmm.sov.out' % seqID)
    pssm_sov_out=os.path.join(outfolder,'%s.pssm.sov.out' % seqID)
    jpred_sov_out=os.path.join(outfolder,'%s.jpred.sov.out' % seqID)
    
    sov_bin='/cluster/gjb_lab/2472402/scripts/calSOV' # path to calSOV binary
    cmd_hmm="%s -f 1 %s -o %s" % (sov_bin,hmm_sov_in,hmm_sov_out) 
    cmd_pssm="%s -f 1 %s -o %s" % (sov_bin,pssm_sov_in,pssm_sov_out)
    cmd_jpred="%s -f 1 %s -o %s" % (sov_bin,jpred_sov_in,jpred_sov_out)
    proc_hmm=subprocess.run(args=cmd_hmm.split())
    proc_pssm=subprocess.run(args=cmd_pssm.split())
    proc_jpred=subprocess.run(args=cmd_jpred.split())

    assert proc_hmm.returncode==0
    assert proc_pssm.returncode==0
    assert proc_jpred.returncode==0
    assert os.path.exists(hmm_sov_out)
    assert os.path.exists(pssm_sov_out)
    assert os.path.exists(jpred_sov_out)

    with open(hmm_sov_out,'r') as f:
        lines=f.read().splitlines()
        ans=lines[1].split()
        hmm_sov,hmm_acc=ans[1],ans[10]
            
    with open(pssm_sov_out,'r') as f:
        lines=f.read().splitlines()
        ans=lines[1].split()
        pssm_sov,pssm_acc=ans[1],ans[10]
    
    with open(jpred_sov_out,'r') as f:
        lines=f.read().splitlines()
        ans=lines[1].split()
        jpred_sov,jpred_acc=ans[1],ans[10]

    assert(_!="nan" & _!="-nan" for _ in [hmm_sov,hmm_acc,pssm_sov,pssm_acc,jpred_sov,jpred_acc])    
        
    return tuple([float(v) for v in (hmm_acc,pssm_acc,jpred_acc,hmm_sov,pssm_sov,jpred_sov)])


# In[3]:


debug=0
irange=range(1,8)
expt_name='23Sep' # if doing comparison, try to match name of Keras experiment
root_folder="/cluster/gjb_lab/2472402/outputs/snns_cv_23Sep"
data_folder="/cluster/homes/adrozdetskiy/Projects/jpredJnet231ReTrainingSummaryTable/scores/training/" # folder to dssp and fasta files


# In[4]:


assert all([os.path.exists(p) for p in [root_folder,data_folder]])

for i in irange:

    # read SCOPe domain names into a list
    cross_val_folder=os.path.join(root_folder, 'cross-val%d/' % i)
    
    results=[] # accumulator for .csv file
    alignments=[] # accumulator for .knet file
    
    seqIDs=sorted(_[:-5] for _ in os.listdir(cross_val_folder+'/valid') if _[-5:]=='.pssm')
    
    assert seqIDs
    
    for seqID in seqIDs:
        
        jnet_path=os.path.join(cross_val_folder+'/data',seqID+'.jnet')
        assert os.path.exists(jnet_path)
        with open(jnet_path,'r') as f:
            lines=f.read().splitlines()
            jnet_pred=lines[1].replace("jnetpred:","").replace(",","")
            jnet_conf=lines[2].replace("JNETCONF:","").replace(",","")
            # lines 3,4,5 are jnetsol0,5,25
            hmm_pred=lines[6].replace("JNETHMM:","").replace(",","")
            pssm_pred=lines[7].replace("JNETPSSM:","").replace(",","")
            jnet_jury=lines[8].replace("JNETJURY:","").replace(",","").replace("-","")
        
        dssp_file=os.path.join(data_folder,seqID+'.dssp')
        fasta_file=os.path.join(data_folder,seqID+'.fasta')

        assert os.path.exists(dssp_file)
        with open(dssp_file,'r') as f:
            dssp=f.read().rstrip()
        
        assert os.path.exists(fasta_file)
        with open(fasta_file, 'r') as f:
            seq=f.read().splitlines()[1]
        
        # check sanity of input to calc()
        if debug:
            print("Entry for .knet file")
            print("seqID:     %s" % seqID)
            print("seq:       %s" % seq)
            print("DSSP:      %s" % dssp)
            print("HMM pred:  %s" % hmm_pred)
            print("PSSM pred: %s" % pssm_pred)
            print("JNET pred: %s" % jnet_pred)
            print("JNET conf: %s" % jnet_conf)
            print("JNET jury: %s" % jnet_jury)
        
        # create directories to write sov input and output to
        sov_root='/cluster/gjb_lab/2472402/sov/snns/%s' % expt_name
        if not os.path.exists(sov_root):
            os.system("mkdir %s" % sov_root)
        sov_folder=os.path.join(sov_root,'cross-val%d' % i)
        if not os.path.exists(sov_folder):
            os.system("mkdir %s" % sov_folder)
        
        # obtain accuracy and predictions in order of: hmm, pssm, joint
        # calc will write and read from the sov_folder directory
        (hmm_acc,pssm_acc,jnet_acc,hmm_sov,pssm_sov,jnet_sov)=calc(sov_folder,seqID,seq,dssp,hmm_pred,pssm_pred,jnet_pred)

        # check sanity of output of calc()
        if debug:
            print("Entry for .csv file: ")
            print("seqID:     %s" % seqID)
            print("JNET acc:  %s" % jnet_acc)
            print("HMM acc:   %s" % hmm_acc)
            print("PSSM acc:  %s" % pssm_acc)
            print("JNET SOV:  %s" % jnet_sov)
            print("HMM SOV:   %s" % hmm_sov)
            print("PSSM SOV:  %s" % pssm_sov)

        #store results
        results.append((seqID,jnet_acc,hmm_acc,pssm_acc,jnet_sov,hmm_sov,pssm_sov))
        alignments.append((seqID,seq,dssp,jnet_pred,hmm_pred,pssm_pred,jnet_conf,jnet_jury))


    # output results to csv file
    out_folder="/cluster/gjb_lab/2472402/results/snns/%s" % expt_name
    if not os.path.exists(out_folder):
        os.system("mkdir %s" % out_folder)
    out_csv="cv%i_scores.csv" % i
    with open(os.path.join(out_folder,out_csv),'w+') as f:
        f.write("seqID,JNET_acc,HMM_acc,PSSM_acc,JNET_sov,HMM_sov,PSSM_sov\n")
        for (seqID,jnet_acc,hmm_acc,pssm_acc,jnet_sov,hmm_sov,pssm_sov) in results:
            line="%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n" % (seqID,jnet_acc,hmm_acc,pssm_acc,jnet_sov,hmm_sov,pssm_sov)
            f.write(line)

    # write alignments to kerasnet file
    out_knet="cv%i.knet" % i
    with open(os.path.join(out_folder,out_knet),'w+') as f:
        for (seqID,seq,dssp,jnet_pred,hmm_pred,pssm_pred,jnet_conf,jnet_jury) in alignments:
            f.write("seqID     : %s\n" % seqID)
            f.write("sequence  : %s\n" % seq)
            f.write("DSSP      : %s\n" % dssp)
            f.write("JNET_pred : %s\n" % jnet_pred)
            f.write("JNET_conf : %s\n" % jnet_conf) # here jnet_conf is already a string.
            f.write("HMM_pred  : %s\n" % hmm_pred)
            f.write("PSSM_pred : %s\n" % pssm_pred)
            f.write("JNET_jury : %s\n" % jnet_jury)


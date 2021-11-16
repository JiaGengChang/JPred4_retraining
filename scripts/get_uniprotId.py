# script to find uniprot ID for a given set of pdbIds using guess and check method for the pdb entity number (an integer) which I don't know

import requests
import pandas as pd
import json
import os

os.chdir('/cluster/gjb_lab/2472402/.')

df = pd.read_csv('data/dictionaries/1497_pdbId.csv')

for i,row in df.iterrows():
    pdbId = row.pdbId
    found = False
    entity = 1
    while(not found): # don't want to exceed 10
        if entity>10:
            break
        url = 'https://www.ebi.ac.uk/pdbe/graph-api/pdbe_pages/uniprot_mapping/%s/%d' % (pdbId,entity)
        print('Requesting url: ',url)
        r = requests.get(url)
        if r.status_code==200:
            found = True
            pdb_dict=json.loads(r.text)
            uniprotId = pdb_dict[pdbId]['data'][0]['accession']
            sequence = pdb_dict[pdbId]['sequence']            
            df.loc[i,'entity']=entity
            df.loc[i,'uniprotId']=uniprotId
            df.loc[i,'sequence']=sequence
        else:
            entity += 1

df.to_csv('1497_uniprotId.csv',index=False)
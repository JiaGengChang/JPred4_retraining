#!/cluster/gjb_lab/2472402/envs/dssp/bin/python
#$ -wd /cluster/gjb_lab/2472402/
#$ -jc long
#$ -pe smp 4 
#$ -mods l_hard mfree 8G

"""

This example client takes a PDB file, sends it to the REST service, which
creates HSSP data. The HSSP data is then output to the console.

Example:
    run from home dir
    python scripts/pdb_to_hssp.py 6G6K.pdb https://www3.cmbi.umcn.nl/xssp/
"""

import argparse
import json
import requests
import time
import glob 
import os
import logging
import traceback

def pdb_to_dssp(pdb_file_path, rest_url):
    
    # read pdb.gz file into a variable
    files = {'file_' : open(pdb_file_path,'rb')}
    
    # Send a request to the server to create hssp data from the pdb file data.
    # If an error occurs, an exception is raised and the program exits. If the
    # request is successful, the id of the job running on the server is
    # returned.
    url_create = '{}api/create/pdb_file/dssp/'.format(rest_url)
    r = requests.post(url_create, files=files)
    r.raise_for_status()

    job_id = json.loads(r.text)['id']
    print ("Job submitted successfully. Id is: '{}'".format(job_id))

    # Loop until the job running on the server has finished, either successfully
    # or due to an error.
    ready = False
    while not ready:
        # Check the status of the running job. If an error occurs an exception
        # is raised and the program exits. If the request is successful, the
        # status is returned.
        url_status = '{}api/status/pdb_file/dssp/{}/'.format(rest_url,
                                                                  job_id)
        r = requests.get(url_status)
        r.raise_for_status()

        status = json.loads(r.text)['status']
        print ("Job status is: '{}'".format(status))

        # If the status equals SUCCESS, exit out of the loop by changing the
        # condition ready. This causes the code to drop into the `else` block
        # below.
        #
        # If the status equals either FAILURE or REVOKED, an exception is raised
        # containing the error message. The program exits.
        #
        # Otherwise, wait for five seconds and start at the beginning of the
        # loop again.
        if status == 'SUCCESS':
            ready = True
        elif status in ['FAILURE', 'REVOKED']:
            raise Exception(json.loads(r.text)['message'])
        else:
            time.sleep(5)
    else:
        # Requests the result of the job. If an error occurs an exception is
        # raised and the program exits. If the request is successful, the result
        # is returned.
        url_result = '{}api/result/pdb_file/dssp/{}/'.format(rest_url,
                                                                  job_id)
        r = requests.get(url_result)
        r.raise_for_status()
        result = json.loads(r.text)['result']

        # Return the result to the caller, which prints it to the screen.
        return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Create DSSP from a directory of pdb.gz files')
    parser.add_argument('dir_pdb_file_path')
    rest_url = 'https://www3.cmbi.umcn.nl/xssp/'
    args = parser.parse_args()
    list_pdb_file_path = [fp for fp in glob.glob(args.dir_pdb_file_path+'/*.pdb') if not os.path.exists(fp.replace('.pdb','.dssp'))]
    assert list_pdb_file_path, "no files ending with .pdb in specified directory"
    print ('running dssp for remaining %d pdb files' % len(list_pdb_file_path))
    for pdb_file_path in list_pdb_file_path:
        print(f'running dssp for {pdb_file_path}')
        outfile = pdb_file_path.replace(".pdb",".dssp")
        
        try:
            result = pdb_to_dssp(pdb_file_path, rest_url)
            with open(outfile, 'w+') as f:
                print(f'writing dssp results to {outfile}')
                f.write(result)
        except Exception as e:
            print(f'failed to run dssp on {pdb_file_path}')

    print('script execution completed!')


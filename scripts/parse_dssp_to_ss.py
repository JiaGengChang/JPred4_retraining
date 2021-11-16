#!/cluster/gjb_lab/2472402/envs/dssp/bin/python
#$ -pe smp 4 
#$ -jc long
#$ -mods l_hard mfree 8G
#$ -m ea
#$ -M 2472402@dundee.ac.uk 
#$ -cwd

# script to parse dssp output into a pandas dataframe
# hacked from dms_tools2 from bloom laboratory
# jia geng

"""
===========
dssp
===========
Process output from `dssp <http://swift.cmbi.ru.nl/gv/dssp/>`_.

`dssp <http://swift.cmbi.ru.nl/gv/dssp/>`_ can be used to calculate
secondary structure and solvent accessibility information from a
PDB structure. This module can process that output.
"""

import logging
import traceback
import os
import re
import pandas
import Bio.PDB
import argparse
import pickle
import glob


#: max accessible surface area (square angstroms) for amino acids, from
#: `Tien et al (2013) <https://doi.org/10.1371/journal.pone.0080635>`_.
#: `MAX_ASA_TIEN[a]` is the max surface area for amino acid `a`.
MAX_ASA_TIEN = {'A':129.0, 'R':274.0, 'N':195.0, 'D':193.0, 'C':167.0,
                'E':223.0, 'Q':225.0, 'G':104.0, 'H':224.0, 'I':197.0,
                'L':201.0, 'K':236.0, 'M':224.0, 'F':240.0, 'P':159.0,
                'S':155.0, 'T':172.0, 'W':285.0, 'Y':263.0, 'V':174.0}


def processDSSP(dsspfile, chain=None, max_asa=MAX_ASA_TIEN):
    """Get secondary structure and solvent accessibility from ``dssp``.

    `dssp <http://swift.cmbi.ru.nl/gv/dssp/>`_ is a program
    that calculates secondary structure and absolute solvent
    accessibility from a PDB file.

    This function processes the text output provided by the
    `dssp webserver <http://swift.cmbi.ru.nl/gv/dssp/>`_, at
    least given the format of that output as of Sept-4-2017.

    It returns a `pandas.DataFrame` that gives the secondary
    structure and solvent accessibility for each residue in the
    ``dssp`` output.

    Args:
        `dsspfile` (str)
            Name of text file containing ``dssp`` output.

        `chain` (str or `None`)
            If the PDB file analyzed by ``dssp`` to create `dsspfile`
            has more than one chain, specify the letter code for one
            of those chains with this argument.

        `max_asa` (dict)
            Max surface area for each amino acid in square angstroms.

    Returns:
        A `pandas.DataFrame` with the following columns:

            - `site`: residue number for all sites in `dsspfile`.

            - `amino_acid`: amino acid identity of site in `dsspfile`.

            - `ASA`: absolute solvent accessibility of the residue.

            - `RSA`: relative solvent accessibility of the residue.

            - `SS`: ``dssp`` secondary structure code, one of:

                - *G*: 3-10 helix

                - *H*: alpha helix

                - *I*: pi helix

                - *B*: beta bridge

                - *E*: beta bulge

                - *T*: turn

                - *S*: high curvature

                - *-*: loop

            - `SS_class`: broader secondary structure class:

                - *helix*: `SS` value of *G*, *H*, or *I*

                - *strand*: `SS` value of *B* or *E*

                - *loop*: any of the other `SS` values.
    """
    dssp_cys = re.compile('[a-z]')
    d_dssp = Bio.PDB.make_dssp_dict(dsspfile)[0]
    chains = set([chainid for (chainid, r) in d_dssp.keys()])
    if chain is None:
        assert len(chains) == 1, "chain is None, but multiple chains"
        chain = list(chains)[0]
    elif chain not in chains:
        raise ValueError("Invalid chain {0}".format(chain))
    d_df = {'site':[],
            'amino_acid':[],
            'ASA':[],
            'RSA':[],
            'SS':[],
            'SS_class':[],
            }
    for ((chainid, r), tup) in d_dssp.items():
        if chainid == chain:
            (tmp_aa, ss, acc) = tup[ : 3]
            if dssp_cys.match(tmp_aa):
                aa = 'C'
            else:
                aa = tmp_aa
            if r[2] and not r[2].isspace():
                # site has letter suffix
                d_df['site'].append(str(r[1]) + r[2].strip())
            else:
                d_df['site'].append(r[1])
            d_df['amino_acid'].append(aa)
            d_df['ASA'].append(acc)
            d_df['RSA'].append(acc / float(max_asa[aa]))
            d_df['SS'].append(ss)
            if ss in ['G', 'H', 'I']:
                d_df['SS_class'].append('helix')
            elif ss in ['B', 'E']:
                d_df['SS_class'].append('strand')
            elif ss in ['T', 'S', '-']:
                d_df['SS_class'].append('loop')
            else:
                raise ValueError("invalid SS of {0}".format(ss))
    return pandas.DataFrame(d_df)



if __name__ == '__main__':
    
    parser = argparse.ArgumentParser(description='Parse output from DSSP into a pandas dataframe')
    parser.add_argument('dssp_dir') # directory containing dssp files 
    parser.add_argument('pkl_dir') # directory for output .pkl files 
    args = parser.parse_args()
    
    print(f'Reading .dssp files from directory {args.dssp_dir}')
    
    # obtain list of dssp files
    abs_dssp_dir = os.path.abspath(args.dssp_dir)
    dssp_dir_file_list = glob.glob(abs_dssp_dir+'/*.dssp')
    assert dssp_dir_file_list, 'no .dssp files found in the directory "' + abs_dssp_dir + '"'
    
    outdir = os.path.abspath(args.pkl_dir)
    print(f'will write any pickle files to {outdir}')
     
    # get basenames by removing .dssp file extension 
    dssp_dir_name_list = [file[:-5] for file in dssp_dir_file_list]
    
    # predicate to identify files which do not have .pkl output created
    def not_seen_before(filename):
        return not os.path.exists(filename+'.pkl')
    
    dssp_dir_name_list_filtered_it = filter(not_seen_before, dssp_dir_name_list)
    
    dssp_dir_name_list_filtered = list(dssp_dir_name_list_filtered_it)
    
    print(f'Beginning dssp parsing for {len(dssp_dir_name_list_filtered)} dssp files')
    
    n_errors = 0
    
    for filename in dssp_dir_name_list_filtered: 
        inpfile = filename + '.dssp'
        #outfile = os.path.join(filename + '.pkl')
        root = filename.split('/')[-1]
        
        outfile = os.path.join(outdir, root + '.pkl')
        print(f'outfile: {outfile}')
        try:
            outdf = processDSSP(inpfile)
            with open(outfile,'wb') as f:
                pickle.dump(outdf,f)
        except Exception as e:
            # log error e.g. no chain specified
            logging.error(traceback.format_exc())
            n_errors += 1
    
    print(f'execution completed with {n_errors} errors!')
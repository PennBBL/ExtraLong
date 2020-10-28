### This script submits qsub jobs calling the singularity container for freeqc,
### and creates the output directory structure for freeqc on PMACS.
###
### Ellyn Butler
### October 27, 2020

import os
import shutil
import re
import pandas as pd

indir = '/project/ExtraLong/data/freesurferCrossSectional/fmriprep/'
outdir = '/project/ExtraLong/data/singleSubjectTemplates/antssst/'

# Load csv of subjects and sessions to include in SSTs
dat = pd.read_csv('/project/ExtraLong/data/qualityAssessment/antssstExclude.csv')
dat['bblid'] = dat['bblid'].astype(str)

subjs = ['sub-'+x for x in dat.bblid.unique()]
for subj in subjs:
    #print(subj)
    # Check if the subject has any sessions that should be included
    bblid = subj.split('-')[1]
    bblid_df = dat[dat['bblid'] == bblid]
    if False in bblid_df.antssstExclude.unique():
        if not os.path.exists(outdir+subj):
            os.mkdir(outdir+subj)
        # Get the session labels to include
        include_df = bblid_df[bblid_df['antssstExclude'] == False]
        sessions = ['ses-'+x for x in bblid_df['seslabel']]
        sessions = ' '.join(sessions)
        sub_indir = indir+subj
        sub_outdir = outdir+subj
        cmd = ['singularity', 'exec', '--writable-tmpfs', '--cleanenv',
            '-B', sub_indir+':/data/input', '-B', sub_outdir+':/data/output',
            '/project/ExtraLong/images/antssst_0.0.2.sif', '/scripts/run.sh', sessions]
        antssst_script = sub_outdir+'/antssst_run.sh'
        os.system('echo '+' '.join(cmd)+' > '+antssst_script)
        os.system('chmod +x '+antssst_script)
        os.system('bsub -o '+sub_outdir+'/jobinfo.log '+antssst_script)


# Don't mount home to singularity
# 1. "singularity run as specific user"
# 2. Fake root

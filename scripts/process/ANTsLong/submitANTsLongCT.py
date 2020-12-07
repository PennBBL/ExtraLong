### This script submits antslongct on ssts
###
### Ellyn Butler
### December 3, 2020

import os
import shutil
import re
import pandas as pd

indir = '/project/ExtraLong/data/singleSubjectTemplates/antssst2/'
outdir = '/project/ExtraLong/data/corticalThickness/sstCT/'

subjs = os.listdir(indir)

for subj in subjs:
    if not os.path.exists(outdir+subj):
        os.mkdir(outdir+subj)
    directory_contents = os.listdir(outdir+subj)
    if len(directory_contents) > 1:
        print('Write conditions for already being processed')
    else:
        #print(bblid+' has not previously been run through ANTsLongCT. Running for the first time now.')
        sub_indir = indir+subj
        sub_outdir = outdir+subj
        cmd = ['singularity', 'exec', '--writable-tmpfs', '--cleanenv',
            '-B', sub_indir+'template0.nii.gz:/data/input/template0.nii.gz',
            '-B', sub_outdir+':/data/output', '/project/ExtraLong/images/antslongct_0.0.1.sif',
            '/scripts/run.sh']
        antslongct_script = sub_outdir+'/antslongct_run.sh'
        os.system('echo '+' '.join(cmd)+' > '+antslongct_script)
        os.system('chmod +x '+antslongct_script)
        os.system('bsub -o '+sub_outdir+'/jobinfo.log '+antslongct_script)

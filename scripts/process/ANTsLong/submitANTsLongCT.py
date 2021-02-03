### This script submits antslongct on ssts
###
### Ellyn Butler
### December 3, 2020 - January 29, 2021

import os
import shutil
import re
import pandas as pd

gr_indir = '/project/ExtraLong/data/groupTemplates/versionTen/'
sst_indir = '/project/ExtraLong/data/singleSubjectTemplates/antssst5/'
outdir = '/project/ExtraLong/data/corticalThickness/antslongct/'

subjs = os.listdir(sst_indir)

for subj in subjs:
    if not os.path.exists(outdir+subj):
        os.mkdir(outdir+subj)
    directory_contents = os.listdir(outdir+subj)
    if len(directory_contents) > 1:
        print('Write conditions for already being processed')
    else:
        #print(bblid+' has not previously been run through ANTsLongCT. Running for the first time now.')
        sub_indir = sst_indir+subj
        sub_outdir = outdir+subj
        cmd = ['singularity', 'exec', '--writable-tmpfs', '--cleanenv',
            '-B', sub_indir+':/data/input/'+subj, '-B', gr_indir+':/data/input/versionTen',
            '-B', sub_outdir+':/data/output', '/project/ExtraLong/images/antslongct_0.0.1.sif',
            '/scripts/run.sh']
        antslongct_script = sub_outdir+'/antslongct_run.sh'
        os.system('echo '+' '.join(cmd)+' > '+antslongct_script)
        os.system('chmod +x '+antslongct_script)
        os.system('bsub -R "rusage[mem=12GB]" -o '+sub_outdir+'/jobinfo.log '+antslongct_script)

### This script submits qsub jobs calling the singularity container for freeqc,
### and creates the output directory structure for freeqc on PMACS.
###
### Ellyn Butler
### October 15, 2020

import os
import shutil
import re

indir = '/project/ExtraLong/data/freesurferCrossSectional/freesurfer/'
outdir = '/project/ExtraLong/freesurferCrossSectional/freeqc/'

for subj in os.listdir(indir):
    os.mkdir(outdir+subj)
    for ses in os.listdir(indir+subj):
        os.mkdir(outdir+subj+'/'+ses)
        os.system('echo singularity run --cleanenv -e SUBCOL="bblid" -e SUBNAME='+subj+' -e SESNAME='+ses+' \
            -v '+indir+subj+'/'+ses+':/input/data \
            -v /project/ExtraLong/data/license.txt:/input/license/license.txt \
            -v '+outdir+subj+'/'+ses':/output \
            /project/ExtraLong/images/pennbbl/freeqc:0.0.2 > 'outdir+subj+'/'+ses+'/'+subj+'_'+ses+'_freeqc.sh')
        os.system('qsub '+outdir+subj+'/'+ses+'/'+subj+'_'+ses+'_freeqc.sh')

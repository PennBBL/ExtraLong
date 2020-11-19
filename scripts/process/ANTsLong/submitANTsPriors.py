### This script takes the output of pickSubjsForTemplate_onlytwo.R (subject/sessions
### pairs in a csv) and calls antspriors to create a group template and priors
###
### Ellyn Butler
### November 19, 2020

import os
import shutil
import re
import pandas as pd

freedir = '/project/ExtraLong/data/freesurferCrossSectional/freesurfer/'
sstdir = '/project/ExtraLong/data/singleSubjectTemplates/antssst/'
outdir = '/project/ExtraLong/data/groupTemplates/versionOne/'

# Load csv of subjects and sessions to include in SSTs
dat = pd.read_csv(outdir+'subjsFromN752.csv')

dataToBind = ''
# Create bind call to individual session data
for index, row in dat.iterrows():
    dataToBind = dataToBind + '-B '

# Create bind call to SST data
for bblid in dat['bblid'].unique():
    dataToBind = dataToBind + '-B '

# Create bind call to output directory
dataToBind = dataToBind + '-B /project/ExtraLong/data/groupTemplates/versionOne:/data/output'

cmd = ['SINGULARITYENV_projectName=ExtraLong', 'singularity', 'exec',
        '--writable-tmpfs', '--cleanenv', dataToBind,
        '/project/ExtraLong/images/antspriors_0.0.1.sif', '/scripts/run.sh']
antpriors_script = outdir+'/antspriors_run.sh'
os.system('echo '+' '.join(cmd)+' > '+antspriors_script)
os.system('chmod +x '+antspriors_script)
os.system('bsub -o '+outdir+'/jobinfo.log '+antspriors_script)



  -B /project/ExtraLong/data/singleSubjectTemplates/antssst/sub-100079/ses-motive1/sub-100079_ses-motive1_desc-preproc_T1w0Warp.nii.gz:/data/input/sub-100079_ses-motive1_desc-preproc_T1w0Warp.nii.gz \
  -B /project/ExtraLong/data/singleSubjectTemplates/antssst/sub-100079/ses-PNC2/sub-100079_ses-PNC2_desc-preproc_T1w1Warp.nii.gz:/data/input/sub-100079_ses-PNC2_desc-preproc_T1w1Warp.nii.gz \
  -B /project/ExtraLong/data/freesurferCrossSectional/fmriprep/sub-100079/ses-motive1/anat/sub-100079_ses-motive1_desc-aseg_dseg.nii.gz:/data/input/sub-100079_ses-motive1_desc-aseg_dseg.nii.gz \
  -B /project/ExtraLong/data/freesurferCrossSectional/fmriprep/sub-100079/ses-PNC2/anat/sub-100079_ses-PNC2_desc-aseg_dseg.nii.gz:/data/input/sub-100079_ses-PNC2_desc-aseg_dseg.nii.gz \
  -B /project/ExtraLong/data/singleSubjectTemplates/antssst/sub-100079/sub-100079_template0.nii.gz:/data/input/sub-100079_template0.nii.gz \

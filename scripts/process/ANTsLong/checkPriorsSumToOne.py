### This script check that priors sum to 1 in every voxel that is brain
### (i.e., all voxels should sum to 0 or 1)
###
### Ellyn Butler
### February 3, 2021

import nibabel as nib
import numpy as np
import pandas as pd
import os
from copy import deepcopy
import matplotlib.pyplot as plt

# List the available aseg images
basedir = '/Users/butellyn/Documents/ExtraLong/data/groupTemplates/versionEleven/'

gmcort = nib.load(basedir+'GMCortical_NormalizedtoExtraLongTemplate_averageMask.nii.gz').get_fdata()
wmcort = nib.load(basedir+'WMCortical_NormalizedtoExtraLongTemplate_averageMask.nii.gz').get_fdata()
csf = nib.load(basedir+'CSF_NormalizedtoExtraLongTemplate_averageMask.nii.gz').get_fdata()
gmdeep = nib.load(basedir+'GMDeep_NormalizedtoExtraLongTemplate_averageMask.nii.gz').get_fdata()
bstem = nib.load(basedir+'Brainstem_NormalizedtoExtraLongTemplate_averageMask.nii.gz').get_fdata()
cereb = nib.load(basedir+'Cerebellum_NormalizedtoExtraLongTemplate_averageMask.nii.gz').get_fdata()


sum_priors = gmcort+wmcort+csf+gmdeep+bstem+cereb
len(np.unique(sum_priors))#Oops... Not all zero and 1

# How far off from 0 and 1?
#np.histogram(sum_priors)

np.amax(sum_priors) #87???
np.amin(sum_priors) # 0

plt.hist(sum_priors, bins = [0,20,40,60,80,100])
plt.title("histogram")
plt.show()

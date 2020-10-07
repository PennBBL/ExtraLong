### This script builds priors for use in the ANTsLongitudinal pipeline. It should
### be used as input to the antsx/ants docker image. To be run at the subject level
###
### Ellyn Butler
### September 30, 2020

# List paths for all bblid/seslabel pairs to use in the prior building

# Find N4 bias field corrected images in native space


# Find tissue probabilistic segmentations
gm_prob_seg=
wm_prob_seg=
csf_prob_seg=

####################### Loop over subjects and sessions #######################
OutDir=/home #Bind the directory with SSTs in the subject level, with empty sessions dirs
fmriprepdir=/data
subj=`ls ${InDir}/ | sed 's#.*/##'`
bblid=`echo ${subj} | cut -d '-' -f 2`


for session in $(ls ${OutDir}/${bblid}/ses*); do

  mkdir /data/joy/BBL/studies/grmpy/BIDS/derivatives/antsCtLongPostProc_20181130/${bblid}
  path2=/data/joy/BBL/studies/grmpy/BIDS/derivatives/antsCtLongPostProc_20181130/${bblid}

  #Registration (gives you the affine and the warp need to take things from subject space to grmpyTemplate space)

  echo "antsRegistrationSyN.sh \
   -d 3 \
   -f /data/joy/BBL/studies/grmpy/grmpyTemplate/grmpy_midpointTemplatetemplate0.nii.gz \
   -m $path/$bblid/${bblid}_T1w_SingleSubjectTemplate/T_templateExtractedBrain0N4.nii.gz \
   -o $path2/${bblid}_NormalizedtoGrmpyTemplate
  #ANTs composite transform:ses01 CorticalThickness to grmpyTemplate space
  antsApplyTransforms \
   -d 3 \
   -e 0 \
   -o [$path2/${bblid}_ses-01_T1wCorticalThicknessNormalizedtogrmpyTemplateCompositeWarp.nii.gz, 1] \
   -r /data/joy/BBL/studies/grmpy/grmpyTemplate/grmpy_midpointTemplatetemplate0.nii.gz \
   -t $path2/${bblid}_NormalizedtoGrmpyTemplate1Warp.nii.gz \
   -t $path2/${bblid}_NormalizedtoGrmpyTemplate0GenericAffine.mat \
   -t $path/$bblid/${bblid}_ses-01_T1w_0/${bblid}_ses-01_T1wSubjectToTemplate1Warp.nii.gz \
   -t $path/$bblid/${bblid}_ses-01_T1w_0/${bblid}_ses-01_T1wSubjectToTemplate0GenericAffine.mat
  #ANTs composite transform:ses02 CorticalThickness to grmpyTemplate space
  antsApplyTransforms \
   -d 3 \
   -e 0 \
   -o [$path2/${bblid}_ses-02_T1wCorticalThicknessNormalizedtogrmpyTemplateCompositeWarp.nii.gz, 1] \
   -r /data/joy/BBL/studies/grmpy/grmpyTemplate/grmpy_midpointTemplatetemplate0.nii.gz \
   -t $path2/${bblid}_NormalizedtoGrmpyTemplate1Warp.nii.gz \
   -t $path2/${bblid}_NormalizedtoGrmpyTemplate0GenericAffine.mat \
   -t $path/$bblid/${bblid}_ses-02_T1w_1/sub-080557_ses-02_T1wSubjectToTemplate1Warp.nii.gz \
   -t $path/$bblid/${bblid}_ses-02_T1w_1/sub-080557_ses-02_T1wSubjectToTemplate0GenericAffine.mat
  #Use grmpyTemplateCompositeWarp to get logJacobian (ses_01)
  CreateJacobianDeterminantImage 3 $path2/${bblid}_ses-01_T1wCorticalThicknessNormalizedtogrmpyTemplateCompositeWarp.nii.gz $path2/${bblid}_ses-01_T1wCorticalThicknessNormalizedtogrmpyTemplatelogJacobian.nii.gz 1 0
  #Use grmpyTemplateCompositeWarp to get logJacobian (ses_02)
  CreateJacobianDeterminantImage 3 $path2/${bblid}_ses-02_T1wCorticalThicknessNormalizedtogrmpyTemplateCompositeWarp.nii.gz $path2/${bblid}_ses-02_T1wCorticalThicknessNormalizedtogrmpyTemplatelogJacobian.nii.gz 1 0
  " >> $path1/${bblid}-script.sh

  qsub -m e -M mckar@pennmedicine.upenn.edu -l h_vmem=26G,s_vmem=25G $path1/$bblid-script.sh

done
# Estimate the optimal transformation from the SST to the group template

# Concatenate the transformations from native to SST and SST to group template



# Apply the concatenated transformation to the probabilistic segmentations to
# get them into the group template space

# Average the probabilistic segmentations in template space, within a tissue type

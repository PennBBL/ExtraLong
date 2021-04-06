#!/bin/bash

export LOGS_DIR=/home/kzoner/logs/freesurfer

project=/project/ExtraLong
input_dir=${project}/data/bids_directory
output_dir=${project}/data/FreesurferLong/cross_sectional

mkdir -p ${project}/scripts/jobscripts/fs_jobscripts

imgList=`ls $input_dir/*/*/anat/*.nii.gz`

for img in $imgList; do
	
	subj=`basename $img | cut -d _ -f 1`
	sess=`basename $img | cut -d _ -f 2`
	echo SUBJECT: $subj SESSION: $sess
	
	subDir=$output_dir/$subj
	mkdir -p $subDir

	jobscript=${project}/scripts/jobscripts/fs_jobscripts/${subj}_${sess}.sh
	
	cat <<- EOS > ${jobscript}
		#!/bin/bash
		
		module load freesurfer/7.1.1
		export FREESURFER_HOME=/appl/freesurfer-7.1.1
		source $FREESURFER_HOME/SetUpFreeSurfer.sh
	
		$FREESURFER_HOME/bin/recon-all -i $img -sd $subDir -s $sess -all
	EOS

	chmod +x ${jobscript}
	#bsub -q bbl_normal -m linc1 ${jobscript}
	bsub -e $LOGS_DIR/${subj}.e -o $LOGS_DIR/${subj}.o -q bbl_normal -m linc1 ${jobscript}
done



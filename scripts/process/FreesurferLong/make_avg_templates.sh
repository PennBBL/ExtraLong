#!/bin/bash

export LOGS_DIR=/home/kzoner/logs/ExtraLong/fs-base

project=/project/ExtraLong
input_dir=${project}/data/bids_directory
output_dir=${project}/data/freesurferLongitudinal/fs-base

mkdir -p ${project}/scripts/jobscripts/fs-base

subjList=`ls -d ${project}/data/bids_directory/sub-* | cut -d / -f 6`

for subject in $subjList; do
	sessList=`ls -d ${project}/data/bids_directory/${subject}/ses-* | cut -d / -f 7`
    
    	tpArgs=""
    	for session in $sessList; do 
        	tpArgs="${tpArgs} -tp ${session}"; 
    	done

    	jobscript=${project}/scripts/jobscripts/fs-base/${subject}.sh
	
	cat <<- EOS > ${jobscript}
		#!/bin/bash
		
		module load freesurfer/7.1.1
		export FREESURFER_HOME=/appl/freesurfer-7.1.1
		source ${FREESURFER_HOME}/SetUpFreeSurfer.sh
		SURFER_FRONTDOOR=1 ${FREESURFER_HOME}/bin/recon-all -base ${subject} ${tpArgs} -all
	EOS
	break
	chmod +x ${jobscript}
	#bsub -e $LOGS_DIR/${subj}_${sess}.e -o $LOGS_DIR/${subj}_${sess}.o ${jobscript}
done

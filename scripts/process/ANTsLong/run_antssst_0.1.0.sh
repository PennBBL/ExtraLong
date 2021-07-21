#!/bin/bash

export LOGS_DIR=/home/kzoner/logs/ants/antssst-0.1.0
mkdir -p ${LOGS_DIR}

jsDir=~/ants_pipelines/data/scripts/jobscripts/antssst-0.1.0
mkdir -p ${jsDir}

fmriprep_dir=/project/ExtraLong/data/freesurferCrossSectional/fmriprep
antssst_dir=~/ants_pipelines/data/singleSubjectTemplates/antssst-0.1.0
atlas_dir=~/ants_pipelines/data/mindboggleVsBrainCOLOR_Atlases

gt_subs_csv=~/ants_pipelines/subjects_for_gt.csv
exclude_csv=/project/ExtraLong/data/qualityAssessment/antssstExclude.csv

subjList=`cat ${gt_subs_csv} | cut --d - -f 2`
#subjList=`cat ${exclude_csv} | grep FALSE | cut -d , -f 1 | uniq`

for subject in $subList; do

        echo SUBJECT: $subject
	sessions=`cat ${exclude_csv} | grep ${subject} | grep FALSE | cut -d , -f 2 | cut -d \" -f 2`
        echo SESSIONS: $sessions

        out_dir=${antssst_dir}/${subject}
        mkdir -p ${out_dir}

        jobscript=${jsDir}/${subject}.sh

        cat <<- JOBSCRIPT > ${jobscript}
                #!/bin/bash

                singularity run --writable-tmpfs --cleanenv --containall \\
		-B ${fmriprep_dir}/${subject}:/data/input/fmriprep \\
		-B ${out_dir}:/data/output \\
		-B ${atlas_dir}:/data/input/atlases \\
		~/ants_pipelines/images/antssst_0.1.0.sif --seed 1 --jlf ${sessions}

        JOBSCRIPT

        chmod +x ${jobscript}

        #bsub -e $LOGS_DIR/${subject}.e -o $LOGS_DIR/${subject}.o ${jobscript}

done
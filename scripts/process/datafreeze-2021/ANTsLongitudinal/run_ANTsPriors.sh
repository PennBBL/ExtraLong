#!/bin/bash

export LOGS_DIR=/home/kzoner/logs/ExtraLong_2021/ANTsPriors-0.1.0
mkdir -p ${LOGS_DIR}

scripts="/project/ExtraLong/scripts/process/datafreeze-2021/ANTsLongitudinal/"
jsDir=${scripts}/jobscripts/ANTsPriors-0.1.0
mkdir -p ${jsDir}

data="/project/ExtraLong/data/datafreeze-2021"
fmriprep_dir=${data}/fmriprep
antslong_dir=${data}/ANTsLongitudinal

gt_subs_csv=${data}/QC/group_template_subjects.csv
subList=$(cat ${gt_subs_csv} | cut -d , -f 1 | uniq)

echo "ANTsPriors will build a group template using the following $(echo $subList | wc -w) subjects:"
for sub in $subList;do 
	echo "sub-${sub}"
done

jobscript=${jsDir}/antspriors${VER}.sh

fmriprep_bindings=""
for sub in ${subList}; do
  fmriprep_bindings+="-B ${fmriprep_dir}/sub-${sub}/:/data/input/fmriprep/sub-${sub} \\\\\\\\\n"
done

cat <<- JOBSCRIPT > ${jobscript}
	#!/bin/bash 
	
	singularity run --writable-tmpfs --cleanenv \\
		${fmriprep_bindings}      
		-B ${atlas_dir}:/data/input/atlases \\
		-B ${antslong_dir}:/data/output \\
		/project/ExtraLong/images/antspriors_0.1.0.sif --project ExtraLong --seed 1 --jlf

JOBSCRIPT

chmod +x ${jobscript}
bsub -e $LOGS_DIR/antspriors${VER}.e -o $LOGS_DIR/antspriors.o ${jobscript}
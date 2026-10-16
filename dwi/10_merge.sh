#!/usr/bin/env bash

# Set Up
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
code_root=$(cd -- "${script_dir}/.." && pwd)

source "${code_root}/config/project.env"
source "${code_root}/config/dwi.sh"

script_name=$(basename "${BASH_SOURCE[0]}")
script_stem="${script_name%.sh}"

jobscript_path="${JOBSCRIPT_DIR}/${script_stem}/jobscript.sh"

mkdir -p \
    "${STATS_DIR}" \
    "${JOBSCRIPT_DIR}/${script_stem}" \
    "${LOG_DIR}/${script_stem}"

# Create Subjects File
find "${DWI_DIR}" \
    -mindepth 4 \
    -maxdepth 4 \
    -type f \
    -path "${DWI_DIR}/sub-*/ses-*/dwi/sub-*_ses-*_diffeo.nii.gz" \
    ! -name "*_aff_diffeo*" \
    -print |
sort > "${STATS_DIR}/subs.txt"

# Create Jobscript
cat > "${jobscript_path}" <<EOF
#!/bin/bash

#BSUB -J ${script_stem}
#BSUB -o ${LOG_DIR}/${script_stem}/%J.o
#BSUB -e ${LOG_DIR}/${script_stem}/%J.e

module load dtitk/2.3.1
module load fsl/6.0.7

TVMean -in ${STATS_DIR}/subs.txt -out ${STATS_DIR}/mean_tensor.nii.gz
TVtool -in ${STATS_DIR}/mean_tensor.nii.gz -fa
mv ${STATS_DIR}/mean_tensor_fa.nii.gz ${STATS_DIR}/mean_FA.nii.gz

mapfile -t tensor_images < "${STATS_DIR}/subs.txt"

for metric in "AD" "FA" "MD" "RD"; do
    metric_lower="\${metric,,}"
    metric_images=()

    for image in "\${tensor_images[@]}"; do
        metric_image="\${image%.nii.gz}_\${metric_lower}.nii.gz"

        if [[ ! -f "\${metric_image}" ]]; then
            echo "Missing metric image: \${metric_image}" >&2
            exit 1
        fi

        metric_images+=("\${metric_image}")
    done

    fslmerge -t "${STATS_DIR}/all_\${metric}.nii.gz" "\${metric_images[@]}"
done
EOF

#Submit Job
bsub < "${jobscript_path}"

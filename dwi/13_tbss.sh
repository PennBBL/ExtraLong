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

# Write Jobscript
cat > "${jobscript_path}" <<EOF
#!/bin/bash

#BSUB -J ${script_stem}
#BSUB -o ${LOG_DIR}/${script_stem}/%J.o
#BSUB -e ${LOG_DIR}/${script_stem}/%J.e

set -euo pipefail

module load fsl/6.0.7

cd "${STATS_DIR}"

bet "mean_FA.nii.gz" "mean_FA_brain.nii.gz" -m
mv "mean_FA_brain_mask.nii.gz" "mean_FA_mask.nii.gz"

tbss_skeleton -i "mean_FA.nii.gz" -o "mean_FA_skeleton.nii.gz"

tbss_4_prestats "${THRESHOLD}"

for metric in AD MD RD; do
    tbss_skeleton \\
    -i "mean_FA.nii.gz" \\
    -o "mean_\${metric}_skeleton.nii.gz" \\
    -p "${THRESHOLD}" \\
    "mean_FA_skeleton_mask_dst.nii.gz" \\
    "mean_FA.nii.gz" \\
    "all_\${metric}.nii.gz" \\
    "all_\${metric}_skeletonised.nii.gz"
done
EOF

# Submit Job
bsub < "${jobscript_path}"

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

module load dtitk/2.3.1
module load fsl/6.0.7

cd "${DWI_DIR}"

tbss_skeleton \\
    -i "${DWI_DIR}/stats/mean_FA.nii.gz" \\
    -o "${DWI_DIR}/stats/mean_FA_skeleton.nii.gz"

tbss_4_prestats "${THRESHOLD}"

for metric in AD MD RD; do
    tbss_skeleton \\
    -i "${DWI_DIR}/stats/mean_FA.nii.gz" \\
    -o "${DWI_DIR}/stats/mean_\${metric}_skeleton.nii.gz" \\
    -p "${THRESHOLD}" \\
    "${DWI_DIR}/stats/mean_FA_skeleton_mask_dst.nii.gz" \\
    "${DWI_DIR}/stats/mean_FA.nii.gz" \\
    "${DWI_DIR}/stats/all_\${metric}.nii.gz" \\
    "${DWI_DIR}/stats/all_\${metric}_skeletonised.nii.gz"
done
EOF

# Submit Job
bsub < "${jobscript_path}"

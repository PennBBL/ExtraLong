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

images_build="${TEMPLATE_DIR}/images_build.csv"

mkdir -p \
    "${JOBSCRIPT_DIR}/${script_stem}" \
    "${LOG_DIR}/${script_stem}" \
    "${BUILD_DIR}" \

# Move Necessary Images to build_dir/
csvcut -c dtitk_path "${images_build}" |
tail -n +2 |
sort -u |
while read -r image_dtitk; do
    cp "${image_dtitk}" "${BUILD_DIR}"
done

for file in "${SELECT_DIR}"/*/FA/best.msf; do

    best=$(<"${file}")
    if [[ "${best}" =~ (sub-[0-9]{6})_(ses-[0-9]{5}) ]]; then
        sub="${BASH_REMATCH[1]}"
        ses="${BASH_REMATCH[2]}"
    else
        continue
    fi

    image_dtitk="${DATA_DIR}/${sub}/${ses}/dwi/${sub}_${ses}.nii.gz"

    cp "${image_dtitk}" "${BUILD_DIR}"
done

# Write Subjects File
find "${BUILD_DIR}" \
    -maxdepth 1 \
    -type f \
    -name 'sub-*_ses-*.nii.gz' \
    -printf '%f\n' |
    sort > "${SUBS_FILE}"

# Copy Initial Template
cp "${INITIAL_TEMPLATE}" "${BUILD_DIR}/initial_template.nii.gz"

# Write Jobscript
cat > "${jobscript_path}" <<EOF
#!/usr/bin/env bash

#BSUB -J ${script_stem}
#BSUB -o ${LOG_DIR}/${script_stem}/%J.o
#BSUB -e ${LOG_DIR}/${script_stem}/%J.e

set -euo pipefail

module load dtitk/2.3.1
module load fsl/6.0.7

cd "${BUILD_DIR}"

# MAKE THE TEMPLATE
TVResample -in "initial_template.nii.gz" -align center -size 80 98 85 -vsize 2 2 2
"${PAD_EXECUTABLE}" "initial_template.nii.gz" "initial_template.nii.gz" ${PAD_TEMPLATE}
TVAdjustVoxelspace -in "initial_template.nii.gz" -origin 0 0 0
dti_template_bootstrap "initial_template.nii.gz" "$(basename "${SUBS_FILE}")"
mv "mean_initial.nii.gz" "template.nii.gz"

# MAKE THE TEMPLATE MASK
bet "template.nii.gz" "template_brain.nii.gz" -f 0.3 -m
fslmaths "template_brain_mask.nii.gz" -Tmax -bin "template_mask.nii.gz" -odt char

mv "template.nii.gz" "${TEMPLATE_DIR}"
mv "template_mask.nii.gz" "${TEMPLATE_DIR}"
EOF

# Submit Job
bsub < "${jobscript_path}"

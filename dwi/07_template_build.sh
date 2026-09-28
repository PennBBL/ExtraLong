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

subjs="${BUILD_DIR}/subjs.txt"
images_build="${TEMPLATE_DIR}/images_build.csv"

i_rigid=3
i_affine=3

mkdir -p \
    "${JOBSCRIPT_DIR}/${script_stem}" \
    "${LOG_DIR}/${script_stem}" \
    "${BUILD_DIR}"

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

    image_dtitk="${DWI_DIR}/${sub}/${ses}/dwi/${sub}_${ses}.nii.gz"

    cp "${image_dtitk}" "${BUILD_DIR}"
done

# Write Subjects File
find "${BUILD_DIR}" \
    -maxdepth 1 \
    -type f \
    -name 'sub-*_ses-*.nii.gz' \
    -printf '%f\n' |
    sort > "${subjs}"

# jobscript
cat > "${jobscript_path}" <<EOF
#!/usr/bin/env bash

#BSUB -J ${script_stem}
#BSUB -o ${LOG_DIR}/${script_stem}/%J.o
#BSUB -e ${LOG_DIR}/${script_stem}/%J.e

set -euo pipefail

module load dtitk/2.3.1
module load fsl/6.0.7

cd "${BUILD_DIR}"

# Preprocess Existing Tensor Template
cp "${INITIAL_TEMPLATE}" "initial_template.nii.gz"
TVResample -in "initial_template.nii.gz" -align center -size 80 98 85 -vsize 2 2 2
"${PAD_EXECUTABLE}" "initial_template.nii.gz" "initial_template.nii.gz" ${PAD_TEMPLATE}
TVAdjustVoxelspace -in "initial_template.nii.gz" -origin 0 0 0

# Bootstrap Initial Template
dti_template_bootstrap "initial_template.nii.gz" "${subjs##*/}"

# Rigid and Affine Registration
dti_rigid_population "mean_initial.nii.gz" "${subjs##*/}" EDS ${i_rigid}
dti_affine_population "mean_rigid${i_rigid}.nii.gz" "${subjs##*/}" EDS ${i_affine}

# Create Mask of Affine Template
TVtool -in "mean_affine${i_affine}.nii.gz" -tr
BinaryThresholdImageFilter "mean_affine${i_affine}_tr.nii.gz" "mask.nii.gz" 0.01 100 1 0

# Diffeomorphic Registration
dti_diffeomorphic_population "mean_affine${i_affine}.nii.gz" "subjs_aff.txt" "mask.nii.gz" 0.002
EOF

# Submit Job
bsub < "${jobscript_path}"

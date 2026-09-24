#!/usr/bin/env bash

# Set Up
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
code_root=$(cd -- "${script_dir}/.." && pwd)

source "${code_root}/config/project.env"
source "${code_root}/config/dwi.sh"

script_name=$(basename "${BASH_SOURCE[0]}")
script_stem="${script_name%.sh}"

manifest="${JOBSCRIPT_DIR}/${script_stem}/manifest.txt"
jobscript_path="${JOBSCRIPT_DIR}/${script_stem}/array.sh"

mkdir -p \
    "${JOBSCRIPT_DIR}/${script_stem}" \
    "${LOG_DIR}/${script_stem}"

# Create Manifest
find "${DWI_DIR}" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -name "sub-*" \
    -printf '%f\n' |
while read -r sub; do

    if [[ -n $(find "/project/ExtraLong/derivatives/dwi/${sub}/log" \
        -mindepth 2 \
        -maxdepth 2 \
        -type f \
        -name "crash*.txt" \
        -print \
        -quit) ]]; then
        continue
    fi

    find "${DWI_DIR}/${sub}" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -name "ses-*" \
        -printf '%f\n' |
    while read -r ses; do

        path="${DWI_DIR}/${sub}/${ses}/dwi"

        dwi_qsi="${path}/${sub}_${ses}_space-ACPC_desc-preproc_dwi.nii.gz"
        mask_qsi="${path}/${sub}_${ses}_space-ACPC_desc-brain_mask.nii.gz"

        [[ -f "${dwi_qsi}" && -f "${mask_qsi}" ]] || continue

        printf '%s\t%s\n' "${sub}" "${ses}"

    done
done |
sort > "${manifest}"

n_jobs=$(wc -l < "${manifest}")

if (( n_jobs == 0 )); then
    echo "No participants with DWI data found"
    exit 0
fi

# Create Array Worker
cat > "${jobscript_path}" <<EOF
#!/usr/bin/env bash

#BSUB -o ${LOG_DIR}/${script_stem}/%J_%I.o
#BSUB -e ${LOG_DIR}/${script_stem}/%J_%I.e

set -euo pipefail

manifest="${manifest}"

IFS=\$'\t' read -r sub ses < <(
    sed -n "\${LSB_JOBINDEX}p" "\${manifest}"
)

if [[ -z "\${sub}" || -z "\${ses}" ]]; then
    echo "No manifest entry for array index \${LSB_JOBINDEX}" >&2
    exit 1
fi

module load afni_openmp/20.1
module load fsl/6.0.7

ses_path="${DWI_DIR}/\${sub}/\${ses}/dwi"

dwi_qsi="\${ses_path}/\${sub}_\${ses}_space-ACPC_desc-preproc_dwi.nii.gz"
dwi_rpi="\${ses_path}/\${sub}_\${ses}_space-ACPC_desc-rpi_dwi.nii.gz"
dwi_pad="\${ses_path}/\${sub}_\${ses}_space-ACPC_desc-pad_dwi.nii.gz"
mask_qsi="\${ses_path}/\${sub}_\${ses}_space-ACPC_desc-brain_mask.nii.gz"
mask_rpi="\${ses_path}/\${sub}_\${ses}_space-ACPC_desc-rpi_mask.nii.gz"
mask_pad="\${ses_path}/\${sub}_\${ses}_space-ACPC_desc-pad_mask.nii.gz"

# RPI Flip
${RPI_EXECUTABLE} \\
    \${dwi_qsi} \\
    \${dwi_rpi}

${RPI_EXECUTABLE} \\
    \${mask_qsi} \\
    \${mask_rpi}

# Padding
${PAD_EXECUTABLE} \\
    \${dwi_rpi} \\
    \${dwi_pad} \\
    ${PAD_4D}

${PAD_EXECUTABLE} \\
    \${mask_rpi} \\
    \${mask_pad} \\
    ${PAD_3D}
EOF

# Submit Job
max_array_size=$(bparams -a | awk '/MAX_JOB_ARRAY_SIZE/ {print $NF}')

if [[ ! "${max_array_size}" =~ ^[0-9]+$ ]]; then
    echo "Could not determine MAX_JOB_ARRAY_SIZE" >&2
    exit 1
fi

for (( start=1; start<=n_jobs; start+=max_array_size )); do
    end=$(( start + max_array_size - 1 ))

    if (( end > n_jobs )); then
        end="${n_jobs}"
    fi

    bsub -J "${script_stem}[${start}-${end}]" < "${jobscript_path}"
done

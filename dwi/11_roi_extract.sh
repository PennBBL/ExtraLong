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

mkdir -p "${JOBSCRIPT_DIR}/${script_stem}" "${LOG_DIR}/${script_stem}" "${STATS_DIR}/roi"

# Write Manifest
find "${DWI_DIR}" -mindepth 1 -maxdepth 1 -type d -name "sub-*" -printf '%f\n' |
while read -r sub; do

    find "${DWI_DIR}/${sub}" -mindepth 1 -maxdepth 1 -type d -name "ses-*" -printf '%f\n' |
    while read -r ses; do

        printf '%s\t%s\n' "${sub}" "${ses}"

    done
done |
sort > "${manifest}"

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

module load fsl/6.0.7

output="${STATS_DIR}/roi/\${sub}_\${ses}.csv"
echo "sub,ses,metric,atlas,region,value" > "\${output}"

for metric in ad fa md rd; do

    target_image="${DWI_DIR}/\${sub}/\${ses}/dwi/\${sub}_\${ses}_diffeo_\${metric}.nii.gz"
    [[ -f "\${target_image}" ]] || continue

    for roi in "${ROI_DIR}"/roi*.nii.gz; do

        [[ "\${roi}" =~ roi_([a-z]+)_([0-9]+)\.nii\.gz$ ]]
        atlas="\${BASH_REMATCH[1]}"
        region="\${BASH_REMATCH[2]}"

        value=\$(fslstats "\${target_image}" -k "\${roi}" -M)
        echo "\${sub},\${ses},\${metric},\${atlas},\${region},\${value}" >> "\${output}"
    done
done
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

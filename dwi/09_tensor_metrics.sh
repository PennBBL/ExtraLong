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

mkdir -p "${JOBSCRIPT_DIR}/${script_stem}" "${LOG_DIR}/${script_stem}"

# Create Manifest
find "${DWI_DIR}" -mindepth 4 -maxdepth 4 -type f -name "sub-*_ses-*_FA.nii.gz" -printf '%f\n' |
while read -r image; do

    [[ "${image}" =~ (sub-[0-9]{6})_(ses-[0-9]{5}) ]] || continue

    sub="${BASH_REMATCH[1]}"
    ses="${BASH_REMATCH[2]}"

    printf '%s\t%s\n' "${sub}" "${ses}"

done |
sort > "${manifest}"

n_jobs=$(wc -l < "${manifest}")

if (( n_jobs == 0 )); then
    echo "No jobs found"
    exit 0
fi

# Create Array Worker
cat > "${jobscript_path}" <<EOF
#!/usr/bin/env bash

#BSUB -o ${LOG_DIR}/${script_stem}/%I_%J.o
#BSUB -e ${LOG_DIR}/${script_stem}/%I_%J.e

set -euo pipefail

manifest="${manifest}"

IFS=\$'\t' read -r sub ses < <(
    sed -n "\${LSB_JOBINDEX}p" "\${manifest}"
)

if [[ -z "\${sub}" || -z "\${ses}" ]]; then
    echo "No manifest entry for array index \${LSB_JOBINDEX}" >&2
    exit 1
fi

module load dtitk/2.3.1
module load fsl/6.0.7

path="${DWI_DIR}/\${sub}/\${ses}/dwi"

TVtool -in \${path}/\${sub}_\${ses}_diffeo.nii.gz -fa
TVtool -in \${path}/\${sub}_\${ses}_diffeo.nii.gz -eigs
fslmaths \${path}/\${sub}_\${ses}_diffeo_lambda2.nii.gz -add \${path}/\${sub}_\${ses}_diffeo_lambda3.nii.gz -div 2 \${path}/\${sub}_\${ses}_diffeo_rd.nii.gz
fslmaths \${path}/\${sub}_\${ses}_diffeo_lambda1.nii.gz -add \${path}/\${sub}_\${ses}_diffeo_lambda2.nii.gz -add \${path}/\${sub}_\${ses}_diffeo_lambda3.nii.gz -div 3 \${path}/\${sub}_\${ses}_diffeo_md.nii.gz
cp \${path}/\${sub}_\${ses}_diffeo_lambda1.nii.gz \${path}/\${sub}_\${ses}_diffeo_ad.nii.gz
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

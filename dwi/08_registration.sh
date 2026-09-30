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
find "${DWI_DIR}" -mindepth 1 -maxdepth 1 -type d -name "sub-*" -printf '%f\n' |
while read -r sub; do

    find "${DWI_DIR}/${sub}" -mindepth 1 -maxdepth 1 -type d -name "ses-*" -printf '%f\n' |
    while read -r ses; do

		path="${DWI_DIR}/${sub}/${ses}/dwi"

		[[ -f "${path}/${sub}_${ses}_FA.nii.gz" ]] || continue

		printf '%s\t%s\n' "${sub}" "${ses}"

	done
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

path="${DWI_DIR}/\${sub}/\${ses}/dwi"

dti_rigid_reg ${DWI_DIR}/template/template.nii.gz \${path}/\${sub}_\${ses}.nii.gz EDS 4 4 4 0.01
dti_affine_reg ${DWI_DIR}/template/template.nii.gz \${path}/\${sub}_\${ses}.nii.gz EDS 4 4 4 0.01 1
dti_diffeomorphic_reg ${DWI_DIR}/template/template.nii.gz \${path}/\${sub}_\${ses}_aff.nii.gz ${DWI_DIR}/template/template_mask.nii.gz 1 6 0.002
dti_warp_to_template \${path}/\${sub}_\${ses}.nii.gz ${DWI_DIR}/template/template.nii.gz 2 2 2
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

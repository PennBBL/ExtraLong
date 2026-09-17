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
find "${DWI_DIR}" -mindepth 4 -maxdepth 4 -type f -name "sub-*_ses-*_space-ACPC_desc-pad_dwi.nii.gz" |
while read -r dwi; do

    ses=$(basename "$(dirname "$(dirname "${dwi}")")")
    sub=$(basename "$(dirname "$(dirname "$(dirname "${dwi}")")")")

    mask="${dwi/desc-pad_dwi.nii.gz/desc-pad_mask.nii.gz}"
    bvals="${dwi/desc-pad_dwi.nii.gz/desc-preproc_dwi.bval}"
    bvecs="${dwi/desc-pad_dwi.nii.gz/desc-preproc_dwi.bvec}"

    [[ -f "${mask}" && -f "${bvals}" && -f "${bvecs}" ]] || continue

    printf '%s\t%s\n' "${sub}" "${ses}"

done |
sort > "${manifest}"

n_jobs=$(wc -l < "${manifest}")

if (( n_jobs == 0 )); then
    echo "No subject-session pairs with complete DWI inputs found"
    exit 0
fi

# Create Array Worker
cat <<-EOF > "${jobscript_path}"
	#!/usr/bin/env bash

	#BSUB -J ${script_stem}[1-${n_jobs}]
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

	ses_path="${DWI_DIR}/\${sub}/\${ses}/dwi"

	dwi="\${ses_path}/\${sub}_\${ses}_space-ACPC_desc-pad_dwi.nii.gz"
	mask="\${ses_path}/\${sub}_\${ses}_space-ACPC_desc-pad_mask.nii.gz"
	bvals="\${ses_path}/\${sub}_\${ses}_space-ACPC_desc-preproc_dwi.bval"
	bvecs="\${ses_path}/\${sub}_\${ses}_space-ACPC_desc-preproc_dwi.bvec"
	out="\${ses_path}/\${sub}_\${ses}"

	dtifit \\
	    --data=\${dwi} \\
	    --out=\${out} \\
	    --mask=\${mask} \\
	    --bvecs=\${bvecs} \\
	    --bvals=\${bvals}
EOF

chmod 775 "${jobscript_path}"

# Submit Job
bsub < "${jobscript_path}"

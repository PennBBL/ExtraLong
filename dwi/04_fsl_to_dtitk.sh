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
find "${DWI_DIR}" -mindepth 4 -maxdepth 4 -type f -name "sub-*_ses-*_FA.nii.gz" |
while read -r fa; do

    ses=$(basename "$(dirname "$(dirname "${fa}")")")
    sub=$(basename "$(dirname "$(dirname "$(dirname "${fa}")")")")

    printf '%s\t%s\n' "${sub}" "${ses}"

done |
sort > "${manifest}"

n_jobs=$(wc -l < "${manifest}")

if (( n_jobs == 0 )); then
    echo "No subject-session pairs with completed dtifit outputs found"
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

	module load dtitk/2.3.1

	ses_path="${DWI_DIR}/\${sub}/\${ses}/dwi"
	input="\${ses_path}/\${sub}_\${ses}"
	output="\${ses_path}/\${sub}_\${ses}.nii.gz"

	TVFromEigenSystem -basename "\${input}" -type FSL -out "\${output}"
	TVtool -in "\${output}" -scale ${FACTOR} -out "\${output}"
	TVtool -in "\${output}" -spd -out "\${output}"
	TVAdjustVoxelspace -in "\${output}" -origin 0 0 0
EOF

chmod 775 "${jobscript_path}"

# Submit Job
bsub < "${jobscript_path}"

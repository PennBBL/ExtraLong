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

images_select="${TEMPLATE_DIR}/images_select.csv"
images_build="${TEMPLATE_DIR}/images_build.csv"

mkdir -p \
    "${JOBSCRIPT_DIR}/${script_stem}" \
    "${LOG_DIR}/${script_stem}" \
    "${TEMPLATE_DIR}" \
    "${SELECT_DIR}"

# Determine Images-to-Bin Mapping
"${SELECT_EXECUTABLE}" \
    --images_build "${images_build}" \
    --images_select "${images_select}"

# Create Manifest
csvcut -c bin "${images_select}" |
tail -n +2 |
sort -u |
while read -r bin; do

    mapfile -t select_images < <(
        csvgrep -c bin -m "${bin}" "${images_select}" |
        csvcut -c fa_path |
        tail -n +2
    )

    if  [[ ${#select_images[@]} -lt 3 ]]; then
        echo "Bin too small, at least 3 images are required per bin"
        continue
    fi

    bin_dir="${SELECT_DIR}/${bin}"
    rm -rf "${bin_dir}"
    mkdir -p "${bin_dir}"

    for select_image in "${select_images[@]}"; do
        new_basename="$(basename "${select_image}" _FA.nii.gz).nii.gz"
        cp "${select_image}" "${bin_dir}/${new_basename}"
    done

    printf '%s\n' "${bin}"
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

#BSUB -J ${script_stem}[1-${n_jobs}]
#BSUB -o ${LOG_DIR}/${script_stem}/%J_%I.o
#BSUB -e ${LOG_DIR}/${script_stem}/%J_%I.e

set -euo pipefail

manifest="${manifest}"

bin=\$(sed -n "\${LSB_JOBINDEX}p" "\${manifest}")

if [[ -z "\${bin}" ]]; then
    echo "No manifest entry for array index \${LSB_JOBINDEX}" >&2
    exit 1
fi

module load fsl/6.0.7

bin_dir="${SELECT_DIR}/\${bin}"
cd "\${bin_dir}"

tbss_1_preproc *.nii.gz
tbss_2_reg -n
tbss_3_postreg -S
EOF

# Submit Job
bsub < "${jobscript_path}"

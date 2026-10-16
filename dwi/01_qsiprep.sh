#!/usr/bin/env bash

# Set up
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
    "${DWI_DIR}" \
    "${TEMPLATEFLOW_HOME}" \
    "${JOBSCRIPT_DIR}/${script_stem}" \
    "${LOG_DIR}/${script_stem}"

# Create manifest of participants with dwi data
find "${PROJECT_DIR}/dwi" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -name "sub-*" \
    -printf '%f\n' |
sort |
while read -r sub; do

    dwi_dir=$(
        find "${PROJECT_DIR}/dwi/${sub}" \
            -mindepth 3 \
            -maxdepth 3 \
            -type f \
            -name "*_dwi.nii.gz" \
            -print \
            -quit
    )

    [[ -n "${dwi_dir}" ]] || continue

    printf '%s\n' "${sub}"

done > "${manifest}"

n_jobs=$(wc -l < "${manifest}")

if (( n_jobs == 0 )); then
    echo "No participants with DWI data found"
    exit 0
fi

# Create array worker
cat > "${jobscript_path}" <<EOF
#!/usr/bin/env bash

#BSUB -n ${NTHREADS}
#BSUB -R "span[hosts=1]"
#BSUB -o ${LOG_DIR}/${script_stem}/%I_%J.o
#BSUB -e ${LOG_DIR}/${script_stem}/%I_%J.e

set -euo pipefail

manifest="${manifest}"

sub=\$(sed -n "\${LSB_JOBINDEX}p" "\${manifest}")

if [[ -z "\${sub}" ]]; then
    echo "No manifest entry for array index \${LSB_JOBINDEX}" >&2
    exit 1
fi

scratch="/scratch/\$USER/\${LSB_JOBID}_\${LSB_JOBINDEX}"

mkdir -p "\${scratch}"
trap 'echo "Cleaning \${scratch}"; rm -rf "\${scratch}"' EXIT

module load apptainer

apptainer run --containall \\
    --bind "${PROJECT_DIR}/dwi:/input:ro" \\
    --bind "${DWI_DIR}:/output" \\
    --bind "\${scratch}:/scratch" \\
    --bind "${LICENSE}:/license.txt:ro" \\
    --bind "${TEMPLATEFLOW_HOME}:/templateflow" \\
    --env TEMPLATEFLOW_HOME="/templateflow" \\
    "${CONTAINER}" \\
    /input /output participant \\
    --participant-label "\${sub}" \\
    --output-resolution ${OUTPUT_RESOLUTION} \\
    --work-dir /scratch \\
    --dwi-only \\
    --stop-on-first-crash \\
    --fs-license-file /license.txt \\
    --skip-bids-validation \\
    --nthreads ${NTHREADS} \\
    --omp-nthreads ${OMP_NTHREADS}
EOF

# submit the job
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

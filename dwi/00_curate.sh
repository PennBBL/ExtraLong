find "/project/ExtraLong/dwi" -mindepth 3 -maxdepth 3 -type d -name "dwi" |
while read -r dwi_dir; do

    mapfile -t scans < <(
        find "${dwi_dir}" -mindepth 1 -maxdepth 1 -type f -name "*_dwi.nii.gz"
    )

    (( ${#scans[@]} == 1 )) || continue

    scan="${scans[0]}"

    [[ ${scan} =~ sub-[0-9]+_ses-[0-9]+_run-[0-9]+ ]] || continue

    mv "${scan}" "${scan/_run-*_dwi.nii.gz/_dwi.nii.gz}"
    mv "${scan/.nii.gz/.bval}" "${scan/_run-*_dwi.nii.gz/_dwi.bval}"
    mv "${scan/.nii.gz/.bvec}" "${scan/_run-*_dwi.nii.gz/_dwi.bvec}"
    mv "${scan/.nii.gz/.json}" "${scan/_run-*_dwi.nii.gz/_dwi.json}"

done
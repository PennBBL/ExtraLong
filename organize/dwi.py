#!/usr/bin/env python3

from pathlib import Path

import numpy as np
import pandas as pd

# Paths
dir_fsl = Path("/") / "appl" / "fsl-6.0.7"
dir_dwi = Path("/") / "project" / "ExtraLong" / "derivatives" / "dwi"

path_labels_xml = dir_fsl / "data" / "atlases" / "JHU-labels.xml"
path_tracts_xml = dir_fsl / "data" / "atlases" / "JHU-tracts.xml"

dir_roi = dir_dwi / "stats" / "roi"

path_qc_volume = dir_dwi / "qc" / "volumes.csv"
path_qc_tsnr_b0 = dir_dwi / "qc" / "tsnr_b0.csv"
path_qc_proj_dist = dir_dwi / "qc" / "proj_dist.csv"

dir_out = dir_dwi / "dataset"

# Atlas Mapping
atlas_tracts = (
    pd.read_xml(path_tracts_xml, xpath=".//data/*")
    .assign(
        index=lambda x: x["index"] + 1,
        laterality=lambda x: np.select(
            [x["label"].str.contains(r"\sL\s*$"), x["label"].str.contains(r"\sR\s*$")],
            ["left", "right"],
            default="bilateral",
        ),
        region=lambda x: (
            x["label"]
            .str.strip()
            .str.lower()
            .str.replace(
                {r"\(|\)": "", r"[^a-z0-9]+": "_", r"_[lr]$": "", r"_part$": ""},
                regex=True,
            )
        ),
        atlas="tracts",
    )
    .loc[:, ["index", "laterality", "region", "atlas"]]
)

atlas_labels = (
    pd.read_xml(path_labels_xml, xpath=".//data/*")
    .assign(
        laterality=lambda x: np.select(
            [x["label"].str.contains(r"\sL\s*$"), x["label"].str.contains(r"\sR\s*$")],
            ["left", "right"],
            default="bilateral",
        ),
        region=lambda x: (
            x["label"]
            .str.strip()
            .str.lower()
            .str.replace(
                {
                    r"\(|\)": "",
                    r"[^a-z0-9]+": "_",
                    r"_[lr]$": "",
                    "_a_part_of_mcp": "",
                    "_of_fornix": "",
                    "_include_optic_radiation": "",
                    "_include_inferior_longitidinal_fasciculus_and_inferior_fronto_occipital_fasciculus": "",
                    "_can_not_be_resolved_with_current_resolution": "",
                    "_could_be_a_part_of_anterior_internal_capsule": "",
                },
                regex=True,
            )
        ),
        atlas="labels",
    )
    .loc[
        lambda x: x["region"].ne("unclassified"),
        ["index", "laterality", "region", "atlas"],
    ]
)

atlas = (
    pd.concat([atlas_tracts, atlas_labels])
    .sort_values(["atlas", "index"])
    .reset_index(drop=True)
)

assert not atlas.duplicated(["atlas", "index"]).any()

# Data
data = (
    pd.concat(
        [pd.read_csv(path) for path in dir_roi.glob("sub-*_ses-*.csv")],
        ignore_index=True
    )
    .rename(columns={"sub": "bblid", "ses": "scanid", "region": "index"})
    .assign(
        bblid=lambda x: x["bblid"].str.extract(r"sub-(\d+)", expand=False),
        scanid=lambda x: x["scanid"].str.extract(r"ses-(\d+)", expand=False),
    )
    .astype(
        {
            "bblid": "Int64",
            "scanid": "Int64",
            "metric": "str",
            "atlas": "str",
            "value": "Float64",
        }
    )
    .merge(atlas, on=["atlas", "index"], how="left", validate="many_to_one")
    .loc[:, ["bblid", "scanid", "metric", "laterality", "region", "atlas", "value"]]
    .sort_values(["bblid", "scanid", "metric", "atlas", "region", "laterality"])
    .reset_index(drop=True)
)

assert data["bblid"].notna().all()
assert data["scanid"].notna().all()
assert data["metric"].notna().all()
assert data["laterality"].notna().all()
assert data["region"].notna().all()
assert data["atlas"].notna().all()
assert not data.duplicated(["bblid", "scanid", "metric", "laterality", "region", "atlas"]).any()

# QC
qc_volume = pd.read_csv(path_qc_volume)
qc_tsnr_b0 = pd.read_csv(path_qc_tsnr_b0)
qc_proj_dist = pd.read_csv(path_qc_proj_dist)

qc = (
    qc_volume.merge(qc_tsnr_b0, on=["participant_id", "session_id"], how="outer", validate="one_to_one")
    .merge(qc_proj_dist, on=["participant_id", "session_id"], how="outer", validate="one_to_one")
    .rename(columns={"participant_id": "bblid", "session_id": "scanid"})
    .assign(
        bblid=lambda x: x["bblid"].str.extract(r"sub-(\d+)", expand=False),
        scanid=lambda x: x["scanid"].str.extract(r"ses-(\d+)", expand=False),
    )
    .astype({"bblid": "Int64", "scanid": "Int64", "volumes": "Int64"})
    .sort_values(["bblid", "scanid"])
    .reset_index(drop=True)
)

assert not qc.duplicated(["bblid", "scanid"]).any()

# Export
dir_out.mkdir(parents=True, exist_ok=True)

data.to_csv(dir_out / "data_dwi.csv", index=False)
qc.to_csv(dir_out / "qc.csv", index=False)

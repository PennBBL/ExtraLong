#!/usr/bin/env python3

import re
from pathlib import Path
import argparse

import pandas as pd

from extralong.config import load_project_paths

# Set Up Argument Parser
parser = argparse.ArgumentParser()

parser.add_argument("--images_build", type=Path, required=True)
parser.add_argument("--images_select", type=Path, required=True)

args = parser.parse_args()

# Define Paths
paths = load_project_paths()
PROJECT_PATH = paths["PROJECT_DIR"]

DERIVATIVES_PATH = PROJECT_PATH / "derivatives"
DWI_DIR = DERIVATIVES_PATH / "dwi"
QC_PATH = DWI_DIR / "qc" / "tsnr_b0.csv"
PARTICIPANTS_PATH = PROJECT_PATH / "participants.tsv"

SUB_PATTERN = re.compile(r"sub-\d{6}")

# Define Function
def select_from_bin(group, bin_label):
    group = group.sort_values("tsnr_b0", ascending=False).copy()
    n = len(group)
    top_n = (n // 2) + (n % 2)
    return group.assign(
        select=[True] * top_n + [False] * (n - top_n) if n >= 5 else [False] * n,
        build=[True] + [False] * (n - 1) if n < 5 else [False] * n,
        bin=bin_label,
    )

# Read Input Data
participants = pd.read_csv(PARTICIPANTS_PATH, sep="\t")

sessions = pd.concat(
    [
        (
            pd.read_csv(session, sep="\t").assign(
                participant_id=SUB_PATTERN.search(session.name).group()
            )
        )
        for session in PROJECT_PATH.glob("sub-*/sub-*_sessions.tsv")
    ],
    ignore_index=True,
).assign(age=lambda df: df["age"] // 12)

qc = pd.read_csv(QC_PATH)

# Create Images Table
images = (
    participants
    .merge(sessions, how="left", on="participant_id")
    .merge(qc, how="left", on=["participant_id", "session_id"])
    .assign(
        bin=lambda df: df["age"].astype("str").str.zfill(2)
        + df["sex"].str.upper().str[0],
        dtitk_path=lambda df: DWI_DIR
        / df["participant_id"]
        / df["session_id"]
        / "dwi"
        / (df["participant_id"] + "_" + df["session_id"] + ".nii.gz"),
        fa_path=lambda df: DWI_DIR
        / df["participant_id"]
        / df["session_id"]
        / "dwi"
        / (df["participant_id"] + "_" + df["session_id"] + "_FA.nii.gz")
    )
    .loc[lambda df: df["dtitk_path"].map(Path.exists), :]
    .groupby("bin", group_keys=False)
    .apply(lambda g: select_from_bin(g, g.name), include_groups=False)
    .loc[:, ["bin", "select", "build", "dtitk_path", "fa_path"]]
    .sort_values(["bin", "dtitk_path"])
    .reset_index(drop=True)
)

# Split Images Table Based on Downstream Processing
images_build = images.loc[images["build"], ["bin", "dtitk_path", "fa_path"]]
images_select = images.loc[images["select"], ["bin", "dtitk_path", "fa_path"]]

# Write to Path
images_build.to_csv(args.images_build, index=False)
images_select.to_csv(args.images_select, index=False)

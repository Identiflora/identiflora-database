"""
Populate plant species info from a local GBIF occurrence dump.

Reads scientific names from assets/labels.txt, merges GBIF occurrence
records with multimedia on gbifID to attach image URLs, and writes a
merged CSV with columns: scientific_name, common_name, genus, img_url.
"""

import os
import csv
import pandas as pd
from typing import Iterator, Optional




# Paths can be overridden via environment variables if needed.
GBIF_OCCURRENCE_PATH = os.getenv("GBIF_OCCURRENCE_PATH", "GBIF_Data/occurrence.txt")
GBIF_MULTIMEDIA_PATH = os.getenv("GBIF_MULTIMEDIA_PATH", "GBIF_Data/multimedia.txt")
INPUT_NAMES_PATH = os.getenv("PLANT_INPUT_PATH", "assets/labels.txt")
OUTPUT_PATH = os.getenv("PLANT_OUTPUT_PATH", "assets/plant_species.csv")

# Optional chunk size (int) for reading the large occurrence file safely.
# CHUNKSIZE_ENV = os.getenv("GBIF_CHUNKSIZE")
# CHUNKSIZE: Optional[int] = int(CHUNKSIZE_ENV) if CHUNKSIZE_ENV else None

# Simple canonicalizer: take first two tokens (genus + species), lowercased.
def make_canonical_name(name: Optional[str]) -> Optional[str]:
    if not isinstance(name, str):
        return None
    tokens = name.strip().split()
    if len(tokens) < 2:
        return None
    return f"{tokens[0].lower()} {tokens[1].lower()}"

def read_labels(path: str = INPUT_NAMES_PATH) -> pd.DataFrame:
    """Load scientific names from labels.txt into a DataFrame."""
    # Use python engine + sep=None so pandas can sniff delimiters; only keep first column.
    labels = pd.read_csv(
        path,
        header=None,
        names=["scientific_name"],
        dtype=str,
        usecols=[0],
    )
    # Normalize whitespace to improve match rate and drop empty rows if present.
    labels["scientific_name"] = labels["scientific_name"].str.strip()
    labels = labels[labels["scientific_name"].notna() & (labels["scientific_name"] != "")]
    labels["canonical_name"] = labels["scientific_name"].apply(make_canonical_name)
    labels = labels[labels["canonical_name"].notna()]

    # print(labels.iloc[0])

    return labels.reset_index(drop=True)


# def _read_multimedia_chunks(path: str, chunksize: int) -> Iterator[pd.DataFrame]:
#     """Yield multimedia chunks with gbifID + identifier for joining."""
#     usecols = ["gbifID", "identifier"]
#     for chunk in pd.read_csv(
#         path,
#         sep="\t",
#         dtype=str,
#         usecols=usecols,
#         chunksize=chunksize,
#         quoting=csv.QUOTE_NONE,
#     ):
#         yield chunk


# def _read_occurrence_chunks(path: str, chunksize: int) -> Iterator[pd.DataFrame]:
#     """Yield occurrence chunks with minimal columns and gbifID for later join."""
#     usecols = ["gbifID", "scientificName", "vernacularName", "genus"]
#     for chunk in pd.read_csv(
#         path,
#         sep="\t",
#         dtype=str,
#         usecols=usecols,
#         chunksize=chunksize,
#         quoting=csv.QUOTE_NONE,  # Avoid parsing errors from stray quotes inside fields.
#     ):
#         yield chunk


def load_multimedia(path: str = GBIF_MULTIMEDIA_PATH) -> pd.DataFrame:
    """Load multimedia data (gbifID + identifier) and deduplicate by gbifID."""
    usecols = ["gbifID", "identifier"]
    mm = pd.read_csv(
        path,
        sep="\t",
        dtype=str,
        usecols=usecols,
        quoting=csv.QUOTE_NONE,
    )
    return mm


def load_occurrence(path: str = GBIF_OCCURRENCE_PATH) -> pd.DataFrame:
    """Load occurrence data and deduplicate by gbifID."""
    usecols = ["gbifID", "scientificName", "vernacularName", "genus"]
    occ = pd.read_csv(
        path,
        sep="\t",
        dtype=str,
        usecols=usecols,
        quoting=csv.QUOTE_NONE,
    )
    # Add canonical name for matching (genus + species, lowercased).
    occ["canonical_name"] = occ["scientificName"].apply(make_canonical_name)
    return occ


def load_instances(
    occurrence_path: str = GBIF_OCCURRENCE_PATH,
    multimedia_path: str = GBIF_MULTIMEDIA_PATH
) -> pd.DataFrame:
    """
    Load occurrence data, merge with multimedia on gbifID to attach img_url,
    and deduplicate on scientificName (first occurrence kept).
    """
    mm = load_multimedia(multimedia_path)
    occ = load_occurrence(occurrence_path)
    merged = occ.merge(mm, on="gbifID", how="left")
    merged = merged.dropna(subset=["identifier"])
    merged = merged.drop_duplicates(subset=["canonical_name"], keep="first")

    return merged


def build_lookup(occ_df: pd.DataFrame) -> pd.DataFrame:
    """
    Standardize column names and reduce to the fields needed for joining.
    """
    rename_map = {
        "scientificName": "scientific_name",
        "vernacularName": "common_name",
        "identifier": "img_url",
    }
    lookup = occ_df.rename(columns=rename_map)
    # Drop gbifID after join; not needed in the final output.
    lookup = lookup.drop(columns=["gbifID"], errors="ignore")
    # ensures order of columns is consistent; keep canonical_name for joining
    lookup = lookup[["canonical_name", "scientific_name", "common_name", "genus", "img_url"]]
    # ensure no columns have null scientific_name
    lookup = lookup[lookup["scientific_name"].notna() & lookup["canonical_name"].notna()]
    return lookup


def enrich_labels(labels: pd.DataFrame, lookup: pd.DataFrame) -> pd.DataFrame:
    """Left-join labels with lookup info."""
    merged = labels.merge(lookup, on="canonical_name", how="left")
    # Drop canonical_name from output to keep requested schema.
    merged = merged.drop(columns=["canonical_name"], errors="ignore")
    return merged


def main() -> None:
    labels = read_labels(INPUT_NAMES_PATH)
    occurrences = load_instances(GBIF_OCCURRENCE_PATH, GBIF_MULTIMEDIA_PATH)
    lookup = build_lookup(occurrences)
    enriched = enrich_labels(labels, lookup)

    output_dir = os.path.dirname(OUTPUT_PATH)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    enriched.to_csv(OUTPUT_PATH, index=False)


if __name__ == "__main__":
    main()

"""
Populate plant_species table via API from plant_species.csv.

Reads the CSV, validates required fields, and POSTs each record to
https://identiflora-api.onrender.com/plant-species.
"""

import os
import sys
from typing import Optional, Tuple

import pandas as pd
import requests


# Configurable paths/endpoints via environment.
CSV_PATH = os.getenv("PLANT_SPECIES_CSV", "assets/plant_species.csv")
API_ENDPOINT = os.getenv(
    "PLANT_SPECIES_ENDPOINT",
    "https://identiflora-api.onrender.com/plant-species",
)
REQUEST_TIMEOUT = float(os.getenv("PLANT_SPECIES_TIMEOUT", "10"))


def load_csv(path: str = CSV_PATH) -> pd.DataFrame:
    """Load the plant_species CSV with expected columns."""
    df = pd.read_csv(path, dtype=str)
    expected = {"scientific_name", "common_name", "genus", "img_url"}
    missing = expected.difference(df.columns)
    if missing:
        raise ValueError(f"Missing expected columns in CSV: {missing}")
    # Normalize whitespace and keep strings; empty strings remain empty.
    for col in expected:
        df[col] = df[col].astype(str).str.strip()
    return df


def valid_row(row: pd.Series) -> bool:
    """Check if the row has the required fields to send (genus may be empty)."""
    return bool(row["scientific_name"]) and bool(row["common_name"]) and bool(row["img_url"])


def build_payload(row: pd.Series) -> dict:
    """Shape the payload for the API."""
    genus_val: Optional[str] = row["genus"] if row["genus"] else None
    return {
        "scientific_name": row["scientific_name"],
        "common_name": row["common_name"],
        "genus": genus_val,
        "img_url": row["img_url"],
    }


def post_species(session: requests.Session, payload: dict) -> Tuple[bool, str]:
    """POST a single species; return success flag and message."""
    try:
        resp = session.post(API_ENDPOINT, json=payload, timeout=REQUEST_TIMEOUT)
        if resp.ok:
            return True, "created"
        return False, f"{resp.status_code}: {resp.text}"
    except requests.RequestException as exc:
        return False, str(exc)


def main() -> None:
    df = load_csv(CSV_PATH)
    session = requests.Session()

    sent = 0
    skipped = 0
    failures = 0

    for _, row in df.iterrows():
        if not valid_row(row):
            skipped += 1
            continue
        payload = build_payload(row)
        ok, msg = post_species(session, payload)
        if ok:
            sent += 1
        else:
            failures += 1
            # Keep a short log to stderr for visibility.
            print(f"Failed to send {payload['scientific_name']}: {msg}", file=sys.stderr)

    print(f"Completed. Sent: {sent}, skipped: {skipped}, failures: {failures}")


if __name__ == "__main__":
    main()

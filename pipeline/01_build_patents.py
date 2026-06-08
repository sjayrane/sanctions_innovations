"""
Step 1 — Build fractional patent panel.

Loads raw PATSTAT fractional-inventor CSV, drops bad country codes, gap-fills
low-patent countries with zeros, and clips to the analysis window.

Output: data/processed/raw_patents_panel_1960_2023.csv
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))

import pandas as pd
from sanctions_innovations.patents import load_and_prepare_patents

_REPO = pathlib.Path(__file__).resolve().parents[1]

def main() -> None:
    patents_df, missing = load_and_prepare_patents(
        str(_REPO / "data/raw/patents/pf_inv_ctry_year_frac.csv"),
        analysis_start=1960,
        analysis_end=2023,
        min_annual_patents=10,
    )

    out = _REPO / "data/processed/raw_patents_panel_1960_2023.csv"
    patents_df.to_csv(out)

    n_countries = patents_df.index.get_level_values("iso3").nunique()
    print(f"[01] Saved {len(patents_df):,} rows, {n_countries} countries → {out.name}")
    if len(missing):
        print(f"     Missing ISO3 codes ({len(missing)}): {list(missing)}")


if __name__ == "__main__":
    main()

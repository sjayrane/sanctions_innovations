"""
Step 3 — Merge sanctions, y02/dirty patents, and country categories into final panel.

Loads the patents+macro panel (step 02), attaches the GSDB binary sanction panel,
World Bank income categories, UN regional categories, and two additional patent
columns (y02 green patents, dirty-innovation patents).

Inputs:  data/processed/patents_panel_1960_2023.csv  (step 02)
         data/raw/sanctions/GSDB_V4_dyadic.dta
         data/raw/sanctions/GSDB_V4.csv
         data/raw/patents/pf_inv_ctry_year_frac_any_y.csv
         data/raw/patents/pf_inv_ctry_year_frac_dirty_innovation.csv
         data/raw/reference/UNSD — Methodology.csv

Output:  data/processed/final_panel_with_y_02_patents_sanctions_final.csv
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))

import numpy as np
import pandas as pd
import pycountry
import requests
from sanctions_innovations import (
    SENDERS_ISO3,
    SENDERS,
    load_gsdb_data,
    make_sanction_panel,
    compute_li_li_index,
)

_REPO = pathlib.Path(__file__).resolve().parents[1]


def _iso2_to_iso3(code: str):
    try:
        return pycountry.countries.get(alpha_2=code).alpha_3
    except Exception:
        return None


def main() -> None:
    # ── Load macro+patent panel (step 02) ─────────────────────────────────────
    panel = pd.read_csv(
        _REPO / "data/processed/patents_panel_1960_2023.csv",
        index_col=["iso3", "year"],
    )

    # ── Load GSDB, build binary sanction panel ─────────────────────────────────
    sanctions_df, gsdb_cases = load_gsdb_data(
        str(_REPO / "data/raw/sanctions/GSDB_V4_dyadic.dta"),
        str(_REPO / "data/raw/sanctions/GSDB_V4.csv"),
    )
    sanctions_og = sanctions_df.copy()
    sanctions_panel = make_sanction_panel(sanctions_df, senders=SENDERS).sort_index()
    sanctions_panel.index.names = ["iso3", "year"]

    # Li & Li index
    S = compute_li_li_index(gsdb_cases)

    # ── Join sanctions onto panel ─────────────────────────────────────────────
    panel = panel.join(sanctions_panel.sort_index(), how="left").assign(
        sanction_index=S.sum(axis=1)
    )
    panel = panel[panel.index.get_level_values("year") >= 1960]

    # Fill GSDB zero-sanction years (GSDB covers 1950–2023; outside that window keep NaN)
    fill_mask = (
        (panel.index.get_level_values("year") >= 1950)
        & (panel.index.get_level_values("year") <= 2023)
    )
    for col in sanctions_panel.columns:
        panel[col] = panel[col].fillna(0).where(fill_mask)

    # ── World Bank income categories ──────────────────────────────────────────
    r = requests.get("https://api.worldbank.org/v2/country?format=json&per_page=2000")
    wb_cats = pd.DataFrame.from_dict(
        {i["id"]: (i["region"]["value"], i["incomeLevel"]["value"]) for i in r.json()[1]},
        orient="index",
        columns=["region", "income_level"],
    )
    wb_cats = wb_cats[wb_cats["region"] != "Aggregates"]

    # ── UN regional/development categories ───────────────────────────────────
    un_cats = pd.read_csv(
        str(_REPO / "data/raw/reference/UNSD — Methodology.csv"),
        delimiter=";",
    ).drop(
        ["Global Code", "Global Name", "Intermediate Region Code",
         "Intermediate Region Name", "M49 Code", "ISO-alpha2 Code"],
        axis=1,
    ).set_axis(
        ["region_code", "region_name", "sub_region_code", "sub_region_name",
         "country", "iso3", "ldc", "lldc", "sids"],
        axis=1,
    )
    for c in ["ldc", "lldc", "sids"]:
        un_cats[c] = un_cats[c].replace("x", True).fillna(False)
    un_cats = un_cats.set_index("iso3")[un_cats["country"] != "Antarctica"]
    for s in SENDERS_ISO3:
        un_cats.loc[list(SENDERS_ISO3[s]), f"in_{s}"] = True
    un_cats.fillna(False, inplace=True)
    un_cats["income_level"] = wb_cats["income_level"]

    panel.index.rename(["iso3", "year"], inplace=True)
    panel = panel.join(un_cats, on="iso3")

    # ── y02 green patents ─────────────────────────────────────────────────────
    y02 = pd.read_csv(str(_REPO / "data/raw/patents/pf_inv_ctry_year_frac_any_y.csv"))
    y02["sum_y02_patents"] = y02["frac_y02_any"]
    y02["iso3"] = y02["ctry_code"].apply(_iso2_to_iso3)
    y02 = y02.dropna(subset=["iso3"]).set_index(["iso3", "priority_year"])
    y02.index.names = ["iso3", "year"]
    panel = panel.join(y02[["frac_y04s", "sum_y02_patents"]], how="left")

    # Fill rows that have classical patents but missing green patents with 0
    mask = panel["frac_classical_inv"].notna() & panel["sum_y02_patents"].isna()
    panel.loc[mask, "sum_y02_patents"] = 0

    # ── Dirty-innovation patents ──────────────────────────────────────────────
    dirty = pd.read_csv(str(_REPO / "data/raw/patents/pf_inv_ctry_year_frac_dirty_innovation.csv"))
    dirty["iso3"] = dirty["ctry_code"].apply(_iso2_to_iso3)
    dirty = dirty.rename(columns={"priority_year": "year"}).set_index(["iso3", "year"])
    panel = panel.join(dirty[["frac_dirty_innovation"]], how="left")

    # ── Save ──────────────────────────────────────────────────────────────────
    out = _REPO / "data/processed/final_panel_with_y_02_patents_sanctions_final.csv"
    panel.to_csv(out)
    n_countries = panel.index.get_level_values("iso3").nunique()
    print(f"[03] Saved {len(panel):,} rows, {n_countries} countries → {out.name}")


if __name__ == "__main__":
    main()

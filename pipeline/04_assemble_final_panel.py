"""
Step 4 — Compute all sanction intensity indices and assemble the analysis panel.

Loads the final panel from step 03, loads IMF Direction of Trade Statistics,
builds bilateral trade tables, then computes all eleven sanction intensity index
variants (rolling pre-period and episode-onset).

Inputs:  data/processed/final_panel_with_y_02_patents_sanctions_final.csv  (step 03)
         data/raw/sanctions/GSDB_V4_dyadic.dta
         data/raw/sanctions/GSDB_V4.csv
         data/raw/trade/IMF_DOT_TXG_FOB_USD.csv
         data/raw/reference/country.csv

Output:  data/processed/final_panel.csv
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))

import pandas as pd
from sanctions_innovations import (
    load_gsdb_data,
    make_sanction_panel,
    SENDERS,
    wb_iso3_map,
    clean_imf_dot,
    build_bilateral,
    build_bilateral_eu_one,
    build_sanction_indicators,
    compute_trade_share_weighted,
    compute_trade_share_weighted_eu_one,
    compute_multi_window,
    compute_directional,
    compute_gdp_normalised,
    compute_gdp_normalised_lag1,
    compute_gdp_normalised_nominal,
    compute_gdp_normalised_gdp5,
    compute_combined_dir_total,
    compute_combined_dir_total_full_only,
    compute_episode_trade_share_eu_one,
    compute_episode_combined_dir_total_eu_one,
)

_REPO = pathlib.Path(__file__).resolve().parents[1]


def main() -> None:
    # ── Load final panel (step 03) ────────────────────────────────────────────
    panel = pd.read_csv(
        _REPO / "data/processed/final_panel_with_y_02_patents_sanctions_final.csv",
        index_col=["iso3", "year"],
    )

    # ── Reload GSDB for dyadic sanctions (needed for index computation) ────────
    sanctions_df, _ = load_gsdb_data(
        str(_REPO / "data/raw/sanctions/GSDB_V4_dyadic.dta"),
        str(_REPO / "data/raw/sanctions/GSDB_V4.csv"),
    )
    sanctions_og = make_sanction_panel.__module__  # just a reference check
    sanctions_og = sanctions_df.copy()

    # Raw dyadic rows (before aggregation) filtered to valid ISO3 senders
    dyadic_sanctions_og = sanctions_og[
        sanctions_og["sanctioning_state_iso3"].notna()
        & (sanctions_og["sanctioning_state_iso3"] != "")
    ].copy()

    # ── Load and clean IMF DOT ────────────────────────────────────────────────
    print("[04] Loading IMF DOT (~580 MB) …")
    imf_dot_df = pd.read_csv(str(_REPO / "data/raw/trade/IMF_DOT_TXG_FOB_USD.csv"))

    name_to_iso3 = wb_iso3_map()
    code_to_iso3 = pd.read_csv(
        str(_REPO / "data/raw/reference/country.csv")
    ).set_index("WEO")["ISO"].to_dict()
    code_to_iso3 |= {726: "SOM", 546: "MAC", 314: "ABW", 836: "NRU"}

    imf_dot_df_red = clean_imf_dot(
        imf_dot_df,
        name_to_iso3=name_to_iso3,
        code_to_iso3=code_to_iso3,
        skip_countries=["EMU", "WLD", "EUU", "AFR", "SSF"],
    )

    # ── Build bilateral trade tables ──────────────────────────────────────────
    print("[04] Building bilateral trade tables …")
    bilateral       = build_bilateral(imf_dot_df_red)
    bilateral_eu_one = build_bilateral_eu_one(bilateral)

    # ── Build sanction indicators ─────────────────────────────────────────────
    (sanction_indicator,
     sanction_indicator_eu_one,
     import_sanction_indicator,
     export_sanction_indicator) = build_sanction_indicators(dyadic_sanctions_og)

    lw = 10

    # ── Compute indices ───────────────────────────────────────────────────────
    print("[04] Computing sanction intensity indices …")

    panel = compute_trade_share_weighted(
        panel, bilateral, sanction_indicator, window=lw)

    panel = compute_trade_share_weighted_eu_one(
        panel, bilateral_eu_one, sanction_indicator_eu_one, window=lw)

    panel = compute_multi_window(
        panel, bilateral, bilateral_eu_one,
        sanction_indicator, sanction_indicator_eu_one,
        windows=(5, 15, 20))

    panel = compute_episode_trade_share_eu_one(
        panel, bilateral_eu_one, dyadic_sanctions_og)

    panel = compute_gdp_normalised(
        panel, bilateral, import_sanction_indicator, export_sanction_indicator, window=lw)

    panel = compute_gdp_normalised_nominal(
        panel, bilateral, import_sanction_indicator, export_sanction_indicator, window=lw)

    panel = compute_gdp_normalised_lag1(
        panel, bilateral, import_sanction_indicator, export_sanction_indicator, window=lw)

    panel = compute_gdp_normalised_gdp5(
        panel, bilateral, import_sanction_indicator, export_sanction_indicator, window=lw)

    panel = compute_directional(
        panel, bilateral, bilateral_eu_one,
        import_sanction_indicator, export_sanction_indicator,
        dyadic_sanctions_og, window=lw)

    panel = compute_combined_dir_total(
        panel, bilateral, bilateral_eu_one,
        import_sanction_indicator, export_sanction_indicator,
        dyadic_sanctions_og, window=lw)

    panel = compute_combined_dir_total_full_only(
        panel, bilateral, bilateral_eu_one,
        dyadic_sanctions_og, window=lw)

    panel = compute_episode_combined_dir_total_eu_one(
        panel, bilateral_eu_one, dyadic_sanctions_og)

    # ── Drop defunct / non-sovereign ISO3 codes ───────────────────────────────
    drop_iso3 = {"CSK", "YUG", "SVU", "VDR", "DDR", "PSE", "TWN", "SSD", "GNB", "RHO"}
    panel_cleaned = panel[
        ~panel.index.get_level_values("iso3").isin(drop_iso3)
    ]

    # ── Save ──────────────────────────────────────────────────────────────────
    out = _REPO / "data/processed/final_panel.csv"
    panel_cleaned.reset_index().to_csv(out, index=False)
    n_countries = panel_cleaned.index.get_level_values("iso3").nunique()
    print(f"[04] Saved {len(panel_cleaned):,} rows, {n_countries} countries → {out.name}")


if __name__ == "__main__":
    main()

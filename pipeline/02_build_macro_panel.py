"""
Step 2 — Fetch WDI macro panel and merge with patent data.

Pulls twelve World Bank WDI indicators via WorldBankSource (cached as Parquet),
filters to the ISO3 codes that appear in the patent panel, then merges and saves.

Inputs:  data/processed/raw_patents_panel_1960_2023.csv   (step 01)
Output:  data/processed/patents_panel_1960_2023.csv
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))

import numpy as np
import pandas as pd
import requests
from sanctions_innovations import FeatureSpec, WorldBankSource, PanelBuilder

_REPO = pathlib.Path(__file__).resolve().parents[1]


def main() -> None:
    # ── Load patent panel (step 01 output) ────────────────────────────────────
    patents_df = pd.read_csv(
        _REPO / "data/processed/raw_patents_panel_1960_2023.csv",
        index_col=["iso3", "priority_year"],
    )

    # ── Fetch WDI features ────────────────────────────────────────────────────
    features = [
        FeatureSpec(name="gdp_pc_current_usd",    source_key="wb", series_code="NY.GDP.PCAP.CD"),
        FeatureSpec(name="gdp_pc_const_2015_usd", source_key="wb", series_code="NY.GDP.PCAP.KD"),
        FeatureSpec(name="trade_pct_gdp",          source_key="wb", series_code="NE.TRD.GNFS.ZS"),
        FeatureSpec(name="fdi_net_inflow_pct_gdp", source_key="wb", series_code="BX.KLT.DINV.WD.GD.ZS"),
        FeatureSpec(name="gdp_const_2015_usd",     source_key="wb", series_code="NY.GDP.MKTP.KD"),
        FeatureSpec(name="gdp_tot_nominal",        source_key="wb", series_code="NY.GDP.MKTP.CD"),
        FeatureSpec(name="population",             source_key="wb", series_code="SP.POP.TOTL"),
        FeatureSpec(name="energy_intensity",       source_key="wb", series_code="EG.EGY.PRIM.PP.KD"),
        FeatureSpec(name="oil_rents_pct_gdp",      source_key="wb", series_code="NY.GDP.PETR.RT.ZS"),
        FeatureSpec(name="gas_rents_pct_gdp",      source_key="wb", series_code="NY.GDP.NGAS.RT.ZS"),
        FeatureSpec(
            name="gdp_const_2015_usd_log",
            source_key="wb",
            series_code="NY.GDP.MKTP.KD",
            transform=lambda v: np.log(pd.to_numeric(v, errors="coerce")),
        ),
        FeatureSpec(
            name="log_gdp_pc_const_2015",
            source_key="wb",
            series_code="NY.GDP.PCAP.KD",
            transform=lambda v: np.log(pd.to_numeric(v, errors="coerce")),
        ),
    ]

    pb = PanelBuilder({"wb": WorldBankSource()}, cache_dir=str(_REPO / ".panel_cache"))
    panel = pb.build_panel(features, use_cache=True)
    panel = panel.set_index(["iso3", "year"]).sort_index()

    # ── Cross-filter: keep only patent ISO3s present in panel ─────────────────
    patent_iso3s = patents_df.index.get_level_values("iso3").unique()
    panel_iso3s  = panel.index.get_level_values("iso3").unique()
    dropped_from_patents = [c for c in patent_iso3s if c not in panel_iso3s]
    if dropped_from_patents:
        dropped_frac = patents_df.loc[
            patents_df.index.get_level_values("iso3").isin(dropped_from_patents),
            "frac_classical_inv",
        ].sum()
        print(f"[02] Dropping {len(dropped_from_patents)} patent ISO3s absent from WDI "
              f"({dropped_frac:.1f} fractional patents lost)")

    reduced_patents = patents_df.loc[
        patents_df.index.get_level_values("iso3").isin(panel_iso3s)
    ].rename_axis(index=["iso3", "year"])

    panel = panel.loc[
        panel.index.get_level_values("iso3").isin(reduced_patents.index.get_level_values("iso3"))
    ]

    # ── Merge ─────────────────────────────────────────────────────────────────
    panel_with_patents = pd.concat(
        [panel, reduced_patents[["frac_classical_inv"]]],
        axis=1,
    )

    out = _REPO / "data/processed/patents_panel_1960_2023.csv"
    panel_with_patents.to_csv(out)
    print(f"[02] Saved {len(panel_with_patents):,} rows, "
          f"{panel_with_patents.index.get_level_values('iso3').nunique()} countries → {out.name}")


if __name__ == "__main__":
    main()

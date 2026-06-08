# Sanctions and Innovation

Replication repository for a master thesis examining the impact of international economic sanctions on total, fossil fuel, and green patent output. The pipeline merges sanctions data (GSDB v4), patent data (PATSTAT), and macroeconomic indicators (World Bank WDI, IMF Direction of Trade Statistics) into a balanced (country × year) panel dataset for econometric analysis.

## Research question

Do international sanctions have an impact on innovation in targeted countries, and does the effect differ by technology type (green vs. fossil-fuel patents)?

## Repository layout

```
sanctions_innovations/
├── sql/
│   ├── patstat/                 # PATSTAT extraction scripts (run in order)
│   │   ├── 01_impute_missing_countries.sql
│   │   ├── 02_frac_patent_panel.sql
│   │   ├── 02b_add_iso3_columns.sql
│   │   ├── 03_green_patents_y02_y04.sql
│   │   └── 04_dirty_innovation_patents.sql
│   └── exploration/             # Ad-hoc diagnostic queries
├── pipeline/
│   ├── 01_build_patents.py      # Build fractional patent panel
│   ├── 02_build_macro_panel.py  # Fetch WDI macro indicators
│   ├── 03_build_sanctions.py    # Attach GSDB sanctions + categories
│   └── 04_assemble_final_panel.py # Compute sanction intensity indices
├── src/sanctions_innovations/   # Python library
│   ├── patents.py               # Patent loading and gap-fill
│   ├── sanctions.py             # GSDB loading, sanction intensity indices
│   ├── trade.py                 # IMF DOT cleaning, bilateral trade tables
│   ├── panel_tools.py           # PanelBuilder, FeatureSpec, WB/OWID sources
│   └── geo.py                   # ISO2→ISO3, country-group helpers
├── notebooks/
│   ├── build_panel_data.ipynb   # Interactive panel assembly
│   ├── build_panel_indexes.ipynb # Sanction intensity index exploration
│   └── imputation_analysis.ipynb # Patent country imputation analysis
├── stata/                       # Estimation scripts (ppmlhdfe)
└── data/                        # Not committed — see Data access below
    ├── raw/patents/             # PATSTAT CSV exports
    ├── raw/sanctions/           # GSDB v4 .dta + .csv
    ├── raw/trade/               # IMF DOT (~580 MB)
    ├── raw/reference/           # UNSD methodology, country codes
    └── processed/               # Pipeline outputs
```

## Data pipeline

The pipeline runs in four stages. Each script reads from `data/` and writes back to `data/processed/`.

```bash
python pipeline/01_build_patents.py         # → raw_patents_panel_1960_2023.csv
python pipeline/02_build_macro_panel.py     # → patents_panel_1960_2023.csv
python pipeline/03_build_sanctions.py       # → final_panel_with_y_02_patents_sanctions_final.csv
python pipeline/04_assemble_final_panel.py  # → final_panel.csv  (final analysis panel)
```

The patent CSV inputs (`data/raw/patents/`) are produced by running the scripts in `sql/patstat/` against the PATSTAT database in order.

## Setup

```bash
python -m venv .venv && source .venv/bin/activate
pip install -e src/
```

Requires Python ≥ 3.10. Macro indicators are fetched from the World Bank API and cached in `.panel_cache/` on first run.

## Estimation

Regression scripts are in `stata/`. All specifications use `ppmlhdfe` (Poisson PML with high-dimensional fixed effects) with standard errors clustered at the country level. See `stata/README.md` for details.

## Data access

Raw data files are not committed (licensed, large, or both). To reproduce the pipeline, obtain:

| File(s) | Source |
|---|---|
| `GSDB_V4_dyadic.dta`, `GSDB_V4.csv` | [Global Sanctions Database](https://www.globalsanctionsdatabase.com/) |
| `IMF_DOT_TXG_FOB_USD.csv` | [IMF Direction of Trade Statistics](https://data.imf.org/) |
| `pf_inv_ctry_year_frac*.csv` | PATSTAT — run `sql/patstat/` scripts |
| `UNSD — Methodology.csv` | [UN Statistics Division](https://unstats.un.org/unsd/methodology/m49/) |

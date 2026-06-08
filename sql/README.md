# SQL — PATSTAT Patent Extraction

PostgreSQL queries run against the PATSTAT database to produce the three raw patent CSV files consumed by `pipeline/01_build_patents.py` and `pipeline/03_build_sanctions.py`.

## Execution order (`patstat/`)

Run these in sequence. All tables are created in the current schema unless otherwise noted.

| Script | Creates | Output file |
|---|---|---|
| `01_impute_missing_countries.sql` | `pf_inv_pers_ctry_all` | — (intermediate) |
| `02_frac_patent_panel.sql` | `pf_inv_ctry_year_frac` | `data/raw/patents/pf_inv_ctry_year_frac.csv` |
| `02b_add_iso3_columns.sql` | enriches `pf_inv_ctry_year_frac` with `iso3` / `country_name` | — |
| `03_green_patents_y02_y04.sql` | `pf_inv_ctry_year_frac_any_y` | `data/raw/patents/pf_inv_ctry_year_frac_any_y.csv` |
| `04_dirty_innovation_patents.sql` | `pf_inv_ctry_year_frac_dirty_innovation` | `data/raw/patents/pf_inv_ctry_year_frac_dirty_innovation.csv` |

**`01_impute_missing_countries.sql`** implements the de Rassenfosse et al. (2013) algorithm to impute missing inventor country codes from equivalent/subsequent filings. This is the foundation for all downstream tables.

**`03_green_patents_y02_y04.sql`** flags applications with CPC codes `Y02*` (climate-change mitigation technologies) and `Y04S` (smart grid), producing fractional counts per subgroup.

**`04_dirty_innovation_patents.sql`** (Brown et al. approach) flags fossil-fuel supply patents via CPC codes `E21B`, `C10G/J/K`, `F17D`, `B63B` — the dirty flag is defined inline against `patstat.tls224_appln_cpc`.


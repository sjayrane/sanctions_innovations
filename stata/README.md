# Stata Do Files

Estimation scripts for the sanctions-on-innovation analysis. All scripts use `ppmlhdfe` (Poisson PML with high-dimensional fixed effects) and cluster standard errors at the country level. The main sanction intensity index is `si_dir_tot_trade_normalized` at a 2-year lag unless otherwise noted.

Before running, replace the `"path"` placeholder in the `import delimited` call with the path to `final_panel.csv` (output of `pipeline/04_assemble_final_panel.py`).

## Files

| File | Description |
|---|---|
| `main_specification_ppmlhdfe.do` | Baseline results: total, green, and fossil-fuel patents (cols 4–6) |
| `Baseline_country_exclusion_analysis.do` | Robustness dropping influential countries one at a time, PPML |
| `Robustness_alternative_Sanction_Indices.do` | Replicates main spec across all sanction intensity index variants |
| `Robustness_alternative_lag_structures_ppml.do` | Compares contemporaneous, 1-year, and 2-year lag structures |
| `Robustness_alternative_sample_periods_ppml.do` | Splits and restricts the sample period |
| `Robustness_alternative_control_definitions.do` | Logged vs. level controls sensitivity check |
| `heterogeneity_sanction_types_senders_main_results.do` | Heterogeneity by sanction type and sender (9 binary indicators) |
| `heterogeneity_supplementary_military_arms.do` | Heterogeneity for military and arms sanctions specifically |
| `Heterogeneity_Hydrocarbon_Dependence_Baseline.do` | Interaction of sanction intensity with oil & gas rents |
| `fractional_outcomes_ppml_specification_ladder_main_results.do` | PPML specification ladder for fractional outcomes (green share, fossil share, directional ratios) across two sample thresholds |
| `fractions_logit_baseline.do` | Fractional logit (`fracreg logit`) specification ladder with average marginal effects for the same directional-share outcomes |
| `fractions_frac_logit_country_exclusion.do` | Fractional logit with country exclusion robustness (full, −CHN, −RUS, −SAU) and true AMEs |

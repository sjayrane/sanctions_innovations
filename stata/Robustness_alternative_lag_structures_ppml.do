/* =========================================================
   CONTROLS LAG COMPARISON — PPMLHDFE
   Focus: si_dir_tot_trade_normalized
   Three specifications:
     Spec A — SI contemporaneous + controls contemporaneous
     Spec B — SI 2-year lag      + controls contemporaneous
     Spec C — SI 2-year lag      + controls 2-year lag
   Controls: ln_gdp_pc, ln_population, fdi_net_inflow_pct_gdp, trade_pct_gdp 
   All specifications: Country FE + Year FE
   ========================================================= */


/* =========================================================
   1. LOAD AND PREP DATA
   ========================================================= */

import delimited "data path", ///
    clear varnames(1) bindquote(strict)

encode iso3, gen(id)
xtset id year
keep if year >= 1960 & year <= 2023

/* Log transforms */
gen ln_gdp_pc     = ln(gdp_pc_const_2015_usd)
gen ln_population = ln(population)

/* 2-year lag: sanction index */
gen L2_si_dir_tot = L2.si_dir_tot_trade_normalized

/* 2-year lags: controls */
gen L2_ln_gdp_pc      = L2.ln_gdp_pc
gen L2_ln_population  = L2.ln_population
gen L2_fdi_net_inflow = L2.fdi_net_inflow_pct_gdp
gen L2_trade_pct_gdp  = L2.trade_pct_gdp

log using "...log_files_stata/PPML/Controls Robustness/controls_lag_comparisons.log", replace text


/* =========================================================
   SI contemporaneous + controls contemporaneous
   ========================================================= */

di _newline(2) "===================================================="
di "SPEC A: SI contemporaneous, controls contemporaneous"
di "===================================================="

ppmlhdfe total_patents si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_A

ppmlhdfe y02_patents si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store y02_A

ppmlhdfe fossil_fuel_patents si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_A


/* =========================================================
   3. SI 2-year lag + controls contemporaneous
   ========================================================= */

di _newline(2) "===================================================="
di "SPEC B: SI 2-year lag, controls contemporaneous"
di "===================================================="

ppmlhdfe total_patents L2_si_dir_tot ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_B

ppmlhdfe y02_patents L2_si_dir_tot ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store y02_B

ppmlhdfe fossil_fuel_patents L2_si_dir_tot ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_B


/* =========================================================
   4. SI 2-year lag + controls 2-year lag
   ========================================================= */

di _newline(2) "===================================================="
di "SPEC C: SI 2-year lag, controls 2-year lag"
di "===================================================="

ppmlhdfe total_patents L2_si_dir_tot ///
    L2_ln_gdp_pc L2_ln_population L2_fdi_net_inflow L2_trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_C

ppmlhdfe y02_patents L2_si_dir_tot ///
    L2_ln_gdp_pc L2_ln_population L2_fdi_net_inflow L2_trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store y02_C

ppmlhdfe fossil_fuel_patents L2_si_dir_tot ///
    L2_ln_gdp_pc L2_ln_population L2_fdi_net_inflow L2_trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_C


log close

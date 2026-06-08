/* =========================================================
   Robustness — PPMLHDFE
   Robustness of logged and non-logged controls
   Covariate: si_dir_tot_trade_normalized, 2-year lag only
   ========================================================= */


/* =========================================================
   1. LOAD AND PREP DATA
   ========================================================= */

import delimited "...", ///
    clear varnames(1) bindquote(strict)

encode iso3, gen(id)
xtset id year
keep if year >= 1960 & year <= 2023

gen ln_gdp_pc     = ln(gdp_pc_const_2015_usd)
gen ln_population = ln(population)

gen L2_si_dir_tot = L2.si_dir_tot_trade_normalized

log using "log_files_stata/controls_log_comparisons.log", replace text


/* =========================================================
   2. REGRESSIONS — 2-year lag SI, four logging variants
   =========================================================
   Variant A (gdp_only) : ln GDP p.c.  + raw population
   Variant B (both)     : ln GDP p.c.  + ln population
   Variant C (pop_only) : raw GDP p.c. + ln population
   Variant D (none)     : raw GDP p.c. + raw population
   All variants include FDI net inflows and trade openness.
   ========================================================= */


/* ---------------------------------------------------------
   VARIANT A: ln GDP p.c. + raw population
   --------------------------------------------------------- */

di _newline(2) "===================================================="
di "VARIANT A: ln GDP p.c. + raw population | SI lag2"
di "===================================================="

ppmlhdfe total_patents L2_si_dir_tot ///
    ln_gdp_pc population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_gdp_only_lag2_c3

ppmlhdfe y02_patents L2_si_dir_tot ///
    ln_gdp_pc population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store y02_gdp_only_lag2_c3

ppmlhdfe fossil_fuel_patents L2_si_dir_tot ///
    ln_gdp_pc population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_gdp_only_lag2_c3


/* ---------------------------------------------------------
   VARIANT B: ln GDP p.c. + ln population (baseline logging)
   --------------------------------------------------------- */

di _newline(2) "===================================================="
di "VARIANT B: ln GDP p.c. + ln population | SI lag2"
di "===================================================="

ppmlhdfe total_patents L2_si_dir_tot ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_both_lag2_c3

ppmlhdfe y02_patents L2_si_dir_tot ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store y02_both_lag2_c3

ppmlhdfe fossil_fuel_patents L2_si_dir_tot ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_both_lag2_c3


/* ---------------------------------------------------------
   VARIANT C: raw GDP p.c. + ln population
   --------------------------------------------------------- */

di _newline(2) "===================================================="
di "VARIANT C: raw GDP p.c. + ln population | SI lag2"
di "===================================================="

ppmlhdfe total_patents L2_si_dir_tot ///
    gdp_pc_const_2015_usd ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_pop_only_lag2_c3

ppmlhdfe y02_patents L2_si_dir_tot ///
    gdp_pc_const_2015_usd ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store y02_pop_only_lag2_c3

ppmlhdfe fossil_fuel_patents L2_si_dir_tot ///
    gdp_pc_const_2015_usd ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_pop_only_lag2_c3


/* ---------------------------------------------------------
   VARIANT D: raw GDP p.c. + raw population
   --------------------------------------------------------- */

di _newline(2) "===================================================="
di "VARIANT D: raw GDP p.c. + raw population | SI lag2"
di "===================================================="

ppmlhdfe total_patents L2_si_dir_tot ///
    gdp_pc_const_2015_usd population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_none_lag2_c3

ppmlhdfe y02_patents L2_si_dir_tot ///
    gdp_pc_const_2015_usd population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store y02_none_lag2_c3

ppmlhdfe fossil_fuel_patents L2_si_dir_tot ///
    gdp_pc_const_2015_usd population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_none_lag2_c3


log close

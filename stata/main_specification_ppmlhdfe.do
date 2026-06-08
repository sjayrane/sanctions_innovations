/* =========================================================
   MAIN SPECIFICATION — PPMLHDFE
   Index: si_dir_tot_trade_normalized (2-year lag only)

   OUTCOMES:
     total_patents         — all patents
     y02_patents           — green patents
     fossil_fuel_patents   — fossil fuel patents

   SPECIFICATIONS (2-year lag):
     Col 4 — Year FE only
     Col 5 — Country FE + Year FE
     Col 6 — Country FE + Year FE + controls

   CONTROLS (Col 6 only):
     ln_gdp_pc
     ln_population
     fdi_net_inflow_pct_gdp
     trade_pct_gdp

   Standard errors clustered at the country level (iso3) throughout.
   ========================================================= */


/* =========================================================
   1. LOAD DATA
   ========================================================= */

import delimited "path", ///
    clear varnames(1) bindquote(strict)

encode iso3, gen(id)

xtset id year

keep if year >= 1960 & year <= 2023

gen ln_population = ln(population)
gen ln_gdp_pc     = ln(gdp_pc_const_2015_usd)

gen L2_si_dir_tot_trade_normalized = L2.si_dir_tot_trade_normalized
label var L2_si_dir_tot_trade_normalized "2-year lag: si_dir_tot_trade_normalized"

log using "....log", replace text


/* ---------------------------------------------------------
   INDEX: si_dir_tot_trade_normalized  [2-year lag]
   --------------------------------------------------------- */
di _newline(2) "===== INDEX: si_dir_tot_trade_normalized  [2-year lag] ====="

* --- Total patents ---
ppmlhdfe total_patents L2_si_dir_tot_trade_normalized, absorb(year) vce(cluster id)
estimates store tot_dirTot_c4

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized, absorb(id year) vce(cluster id)
estimates store tot_dirTot_c5

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, absorb(id year) vce(cluster id)
estimates store tot_dirTot_c6

* --- Green patents ---
ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized, absorb(year) vce(cluster id)
estimates store grn_dirTot_c4

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized, absorb(id year) vce(cluster id)
estimates store grn_dirTot_c5

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, absorb(id year) vce(cluster id)
estimates store grn_dirTot_c6

* --- Fossil fuel patents ---
ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized, absorb(year) vce(cluster id)
estimates store fos_dirTot_c4

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized, absorb(id year) vce(cluster id)
estimates store fos_dirTot_c5

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, absorb(id year) vce(cluster id)
estimates store fos_dirTot_c6


/* =========================================================
   SUMMARY TABLE
   ========================================================= */

di _newline(3) "========================================================="
di              "  SUMMARY OF RESULTS"
di              "  2-year lag: Col4=Year FE  Col5=+Country FE  Col6=+Controls"
di              "========================================================="

di _newline "INDEX: si_dir_tot_trade_normalized"
di "  Outcome   Col4 b (SE)           Col5 b (SE)           Col6 b (SE)"
foreach s in tot grn fos {
    estimates restore `s'_dirTot_c4
    local b4=_b[L2_si_dir_tot_trade_normalized]
    local se4=_se[L2_si_dir_tot_trade_normalized]
    estimates restore `s'_dirTot_c5
    local b5=_b[L2_si_dir_tot_trade_normalized]
    local se5=_se[L2_si_dir_tot_trade_normalized]
    estimates restore `s'_dirTot_c6
    local b6=_b[L2_si_dir_tot_trade_normalized]
    local se6=_se[L2_si_dir_tot_trade_normalized]
    di "  `s'   " %7.4f `b4' " (" %6.4f `se4' ")   " %7.4f `b5' " (" %6.4f `se5' ")   " %7.4f `b6' " (" %6.4f `se6' ")"
}

log close


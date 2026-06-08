/* =========================================================
   ROBUSTNESS: ADDED V-DEM CONTROL — PPMLHDFE
   Estimator : ppmlhdfe

   For si_dir_tot_trade_normalized, runs 4 regressions per outcome
   using the 2-year lag of the sanction index:
     Col 1 — Year FE only
     Col 2 — Country FE + Year FE
     Col 3 — Country FE + Year FE + controls (excl. V-Dem LDI)
     Col 4 — Country FE + Year FE + controls + V-Dem LDI

   OUTCOMES:
     total_patents         — all patents
     y02_patents           — green/clean patents (Y02 CPC class)
     fossil_fuel_patents   — fossil fuel patents

   CONTROLS (Col 3 and Col 4):
     ln_gdp_pc                — log GDP per capita (constant 2015 USD)
     ln_population            — log total population
     fdi_net_inflow_pct_gdp   — FDI net inflows (% of GDP)
     trade_pct_gdp            — trade openness (% of GDP)
   ADDITIONAL CONTROL (Col 4 only):
     libdem_vdem              — V-Dem Liberal Democracy Index

   Standard errors clustered at the country level throughout.
   ========================================================= */


/* =========================================================
   1. LOAD DATA
   ========================================================= */

import delimited "data path", ///
    clear varnames(1) bindquote(strict)

encode iso3, gen(id)
xtset id year
keep if year >= 1960 & year <= 2023

gen ln_population = ln(population)
gen ln_gdp_pc     = ln(gdp_pc_const_2015_usd)

gen L2_si_dir_tot_trade_normalized = L2.si_dir_tot_trade_normalized
label var L2_si_dir_tot_trade_normalized "2-year lag: si_dir_tot_trade_normalized"

log using "log", replace text


/* =========================================================
   2. REGRESSIONS — si_dir_tot_trade_normalized, 2-year lag
   ========================================================= */

di _newline(2) "===== si_dir_tot_trade_normalized [2-year lag] ====="


/* --- Total patents --- */

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized, ///
    absorb(year) vce(cluster id)
estimates store tot_c1

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized, ///
    absorb(id year) vce(cluster id)
estimates store tot_c2

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_c3

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp libdem_vdem, ///
    absorb(id year) vce(cluster id)
estimates store tot_c4


/* --- Green patents --- */

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized, ///
    absorb(year) vce(cluster id)
estimates store grn_c1

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized, ///
    absorb(id year) vce(cluster id)
estimates store grn_c2

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_c3

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp libdem_vdem, ///
    absorb(id year) vce(cluster id)
estimates store grn_c4


/* --- Fossil fuel patents --- */

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized, ///
    absorb(year) vce(cluster id)
estimates store fos_c1

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized, ///
    absorb(id year) vce(cluster id)
estimates store fos_c2

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_c3

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp libdem_vdem, ///
    absorb(id year) vce(cluster id)
estimates store fos_c4


/* =========================================================
   3. SUMMARY TABLE
   ========================================================= */

di _newline(3) "========================================================="
di              "  SUMMARY OF RESULTS"
di              "  Col1=Year FE  Col2=+Country FE  Col3=+Controls  Col4=+V-Dem"
di              "========================================================="

di "  Outcome   Col1 b (SE)           Col2 b (SE)           Col3 b (SE)           Col4 b (SE)"
foreach s in tot grn fos {
    estimates restore `s'_c1
    local b1  = _b[L2_si_dir_tot_trade_normalized]
    local se1 = _se[L2_si_dir_tot_trade_normalized]
    estimates restore `s'_c2
    local b2  = _b[L2_si_dir_tot_trade_normalized]
    local se2 = _se[L2_si_dir_tot_trade_normalized]
    estimates restore `s'_c3
    local b3  = _b[L2_si_dir_tot_trade_normalized]
    local se3 = _se[L2_si_dir_tot_trade_normalized]
    estimates restore `s'_c4
    local b4  = _b[L2_si_dir_tot_trade_normalized]
    local se4 = _se[L2_si_dir_tot_trade_normalized]
    di "  `s'   " %7.4f `b1' " (" %6.4f `se1' ")   " ///
                  %7.4f `b2' " (" %6.4f `se2' ")   " ///
                  %7.4f `b3' " (" %6.4f `se3' ")   " ///
                  %7.4f `b4' " (" %6.4f `se4' ")"
}

log close

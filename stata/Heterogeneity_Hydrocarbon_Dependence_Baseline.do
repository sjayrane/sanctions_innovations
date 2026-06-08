/* =========================================================
   BASELINE PPML — INTERACTION WITH OIL & GAS RENTS
   Estimator : ppmlhdfe (Poisson PML with high-dimensional FE)

   Runs the baseline specification for the 2-year lag
   of si_dir_tot_trade_normalized, adding an interaction term
   between the sanction index and oil_gas_rents_pct_gdp.

   For each outcome, runs 3 regressions:
     Col 1 — Year FE only
     Col 2 — Country FE + Year FE
     Col 3 — Country FE + Year FE + controls

   All three columns include:
     L2_si_dir_tot              — 2-year lag of sanction index
     L2_oil_gas_rents           — 2-year lag of oil & gas rents (% GDP)
     L2_si_X_oilgas             — interaction: L2 sanction × L2 oil & gas rents

   OUTCOMES:
     total_patents        — all patents
     y02_patents          — green/clean patents (Y02 CPC class)
     fossil_fuel_patents  — fossil fuel patents

   CONTROLS (Col 3 only):
     ln_gdp_pc              — log GDP per capita (constant 2015 USD)
     ln_population          — log total population
     fdi_net_inflow_pct_gdp — FDI net inflows (% of GDP)
     trade_pct_gdp          — trade openness (% of GDP)

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

/* 2-year lags */
gen L2_si_dir_tot    = L2.si_dir_tot_trade_normalized
gen L2_oil_gas_rents = L2.oil_gas_rents_pct_gdp

/* Interaction term: lagged sanction index × lagged oil & gas rents */
gen L2_si_X_oilgas   = L2_si_dir_tot * L2_oil_gas_rents

label var L2_si_dir_tot    "2-year lag: si_dir_tot_trade_normalized"
label var L2_oil_gas_rents "2-year lag: oil_gas_rents_pct_gdp"
label var L2_si_X_oilgas   "2-year lag: SI^dir × oil_gas_rents_pct_gdp"

log using "log", replace text


/* =========================================================
   2. REGRESSIONS
   =========================================================
   3 columns × 3 outcomes = 9 regressions.
   Estimate naming: {outcome}_c{1|2|3}
   ========================================================= */

local interact  L2_si_dir_tot L2_oil_gas_rents L2_si_X_oilgas
local controls  ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp


/* ---------------------------------------------------------
   OUTCOME 1: total_patents
   --------------------------------------------------------- */
di _newline(2) "===== OUTCOME: total_patents ====="

ppmlhdfe total_patents `interact', ///
    absorb(year) vce(cluster id)
estimates store tot_c1

ppmlhdfe total_patents `interact', ///
    absorb(id year) vce(cluster id)
estimates store tot_c2

ppmlhdfe total_patents `interact' `controls', ///
    absorb(id year) vce(cluster id)
estimates store tot_c3


/* ---------------------------------------------------------
   OUTCOME 2: y02_patents
   --------------------------------------------------------- */
di _newline(2) "===== OUTCOME: y02_patents ====="

ppmlhdfe y02_patents `interact', ///
    absorb(year) vce(cluster id)
estimates store grn_c1

ppmlhdfe y02_patents `interact', ///
    absorb(id year) vce(cluster id)
estimates store grn_c2

ppmlhdfe y02_patents `interact' `controls', ///
    absorb(id year) vce(cluster id)
estimates store grn_c3


/* ---------------------------------------------------------
   OUTCOME 3: fossil_fuel_patents
   --------------------------------------------------------- */
di _newline(2) "===== OUTCOME: fossil_fuel_patents ====="

ppmlhdfe fossil_fuel_patents `interact', ///
    absorb(year) vce(cluster id)
estimates store fos_c1

ppmlhdfe fossil_fuel_patents `interact', ///
    absorb(id year) vce(cluster id)
estimates store fos_c2

ppmlhdfe fossil_fuel_patents `interact' `controls', ///
    absorb(id year) vce(cluster id)
estimates store fos_c3


/* =========================================================
   3. SUMMARY TABLE
   =========================================================
   Prints coefficient and SE for L2_si_dir_tot, L2_oil_gas_rents,
   and L2_si_X_oilgas across all 3 columns, for each outcome.
   ========================================================= */

di _newline(3) "========================================================="
di              "  SUMMARY OF RESULTS"
di              "  2-year lag: SI^dir × oil_gas_rents interaction"
di              "  Col1=Year FE  Col2=+Country FE  Col3=+Controls"
di              "========================================================="

foreach s in tot grn fos {

    if "`s'" == "tot" local label "total_patents"
    if "`s'" == "grn" local label "y02_patents"
    if "`s'" == "fos" local label "fossil_fuel_patents"

    di _newline(1) "OUTCOME: `label'"
    di "  Variable            Col1 b (SE)           Col2 b (SE)           Col3 b (SE)"

    foreach v in L2_si_dir_tot L2_oil_gas_rents L2_si_X_oilgas {
        forvalues c = 1/3 {
            estimates restore `s'_c`c'
            local b`c'  = _b[`v']
            local se`c' = _se[`v']
        }
        di "  `v'" ///
           "  " %7.4f `b1' " (" %6.4f `se1' ")" ///
           "   " %7.4f `b2' " (" %6.4f `se2' ")" ///
           "   " %7.4f `b3' " (" %6.4f `se3' ")"
    }
}

log close

/* =========================================================
   MAIN SPECIFICATION + ROBUSTNESS (TIME WINDOWS) — PPMLHDFE
   Estimator : ppmlhdfe 
   Index     : si_dir_tot_trade_normalized

   STRUCTURE:
   -------------------------------------------------------
   SECTION 2  — Main spec (1960–2023), full controls only
   SECTION 3  — Robustness: time-window sensitivity
     Four windows:
       R1 : 1991–2023
       R2 : 1995–2023
       R3 : 1960–2020
       R4 : 1995–2020

   OUTCOMES (all sections):
     total_patents         — all patents
     y02_patents           — green patents (Y02 CPC class)
     fossil_fuel_patents   — fossil fuel patents

   CONTROLS (all specifications):
     ln_gdp_pc                — log GDP per capita (constant 2015 USD)
     ln_population            — log total population
     fdi_net_inflow_pct_gdp   — FDI net inflows (% of GDP)
     trade_pct_gdp            — trade openness (% of GDP)

   Standard errors clustered at the country (id) level throughout.
   ========================================================= */


/* =========================================================
   1. LOAD DATA
   ========================================================= */

import delimited "/Users/jayranenobari/Code_01/output/110526df.csv", ///
    clear varnames(1) bindquote(strict)

/* iso3 is a string — encode it to a numeric id for xtset and FE absorption */
encode iso3, gen(id)

/* Declare panel structure */
xtset id year

/* Keep full sample: 1960–2023 */
keep if year >= 1960 & year <= 2023

/* Log transforms (standard in cross-country regressions) */
gen ln_population = ln(population)
gen ln_gdp_pc     = ln(gdp_pc_const_2015_usd)

/* Pre-generate 2-year lag */
gen L2_si_dir_tot_trade_normalized = L2.si_dir_tot_trade_normalized
label var L2_si_dir_tot_trade_normalized "2-year lag: si_dir_tot_trade_normalized"

log using "/Users/jayranenobari/log_files_stata/ppml_time_windows_robustness_dirTot.log", replace text


/* =========================================================
   2. MAIN SPECIFICATION  (1960–2023)
   =========================================================
   Full controls + Country FE + Year FE only.
   c6 = 2-year lag
   ========================================================= */

di _newline(3) "========================================================="
di              "  SECTION 2: MAIN SPECIFICATION  (1960–2023)"
di              "  Index: si_dir_tot_trade_normalized"
di              "========================================================="

di _newline(2) "--- 2-year lag [main] ---"

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_dirTot_c6

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_dirTot_c6

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_dirTot_c6


/* =========================================================
   3. ROBUSTNESS: TIME-WINDOW SENSITIVITY
   =========================================================
   For each window, runs only the full-controls specification
   (Country FE + Year FE + controls) for the 2-year lag —
   equivalent to Col 6 of the main spec but restricted to
   the sub-period.

   Estimate naming convention:
     {outcome}_dirTot_{window}_l
       window : r91_23 | r95_23 | r60_20 | r95_20
       l      : 2-year lag
   ========================================================= */

di _newline(3) "========================================================="
di              "  SECTION 3: ROBUSTNESS — TIME-WINDOW SENSITIVITY"
di              "  Index: si_dir_tot_trade_normalized"
di              "  Spec:  Country FE + Year FE + full controls"
di              "========================================================="


/* ---------------------------------------------------------
   ROBUSTNESS WINDOW R1: 1991–2023 (post-Cold War)
   --------------------------------------------------------- */
di _newline(2) "===== WINDOW R1: 1991–2023 (post-Cold War) ====="

preserve
keep if year >= 1991 & year <= 2023

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_dirTot_r91_23_l

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_dirTot_r91_23_l

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_dirTot_r91_23_l

restore


/* ---------------------------------------------------------
   ROBUSTNESS WINDOW R2: 1995–2023
   --------------------------------------------------------- */
di _newline(2) "===== WINDOW R2: 1995–2023 ====="

preserve
keep if year >= 1995 & year <= 2023

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_dirTot_r95_23_l

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_dirTot_r95_23_l

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_dirTot_r95_23_l

restore


/* ---------------------------------------------------------
   ROBUSTNESS WINDOW R3: 1960–2020
   --------------------------------------------------------- */
di _newline(2) "===== WINDOW R3: 1960–2020 ====="

preserve
keep if year >= 1960 & year <= 2020

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_dirTot_r60_20_l

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_dirTot_r60_20_l

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_dirTot_r60_20_l

restore


/* ---------------------------------------------------------
   ROBUSTNESS WINDOW R4: 1995–2020
   --------------------------------------------------------- */
di _newline(2) "===== WINDOW R4: 1995–2020 ====="

preserve
keep if year >= 1995 & year <= 2020

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_dirTot_r95_20_l

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_dirTot_r95_20_l

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_dirTot_r95_20_l

restore


/* =========================================================
   4. SUMMARY TABLE
   =========================================================
   Columns: Main(1960-23) | R1(1991-23) | R2(1995-23) | R3(1960-20) | R4(1995-20)
   ========================================================= */

di _newline(3) "========================================================="
di              "  SECTION 4: ROBUSTNESS — 2-YEAR LAG"
di              "  Spec: Country FE + Year FE + full controls"
di              "  Columns: Main(1960-23) | R1(1991-23) | R2(1995-23) | R3(1960-20) | R4(1995-20)"
di              "========================================================="

di "  Outcome   Main             R1:1991-23       R2:1995-23       R3:1960-20       R4:1995-20"
foreach s in tot grn fos {
    estimates restore `s'_dirTot_c6
    local bm  = _b[L2_si_dir_tot_trade_normalized]
    local sem = _se[L2_si_dir_tot_trade_normalized]
    estimates restore `s'_dirTot_r91_23_l
    local b1  = _b[L2_si_dir_tot_trade_normalized]
    local se1 = _se[L2_si_dir_tot_trade_normalized]
    estimates restore `s'_dirTot_r95_23_l
    local b2  = _b[L2_si_dir_tot_trade_normalized]
    local se2 = _se[L2_si_dir_tot_trade_normalized]
    estimates restore `s'_dirTot_r60_20_l
    local b3  = _b[L2_si_dir_tot_trade_normalized]
    local se3 = _se[L2_si_dir_tot_trade_normalized]
    estimates restore `s'_dirTot_r95_20_l
    local b4  = _b[L2_si_dir_tot_trade_normalized]
    local se4 = _se[L2_si_dir_tot_trade_normalized]
    di "  `s'   " %7.4f `bm' "(" %6.4f `sem' ")  " %7.4f `b1' "(" %6.4f `se1' ")  " %7.4f `b2' "(" %6.4f `se2' ")  " %7.4f `b3' "(" %6.4f `se3' ")  " %7.4f `b4' "(" %6.4f `se4' ")"
}

log close

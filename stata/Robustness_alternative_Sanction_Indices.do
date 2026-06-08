/* =========================================================
   ALL SANCTION INDICES — PPMLHDFE
   Estimator : ppmlhdfe
   
   OUTCOMES (one per regression):
     total_patents         — all patents
     y02_patents           — green/clean patents (Y02 CPC class)
     fossil_fuel_patents   — fossil fuel patents

   SANCTION INDICES:
     si_dir_tot_trade_normalized  — trade-weighted directional total
     si_tot_w5                    — total index, 5-year window weight
     si_tot_w10                   — total index, 10-year window weight
     si_gdp_nominal               — GDP-based intensity index 
     si_mdis                      — import disruption index
     si_xdis                      — export disruption index

   CONTROLS:
     ln_gdp_pc              — log GDP per capita (constant 2015 USD)
     ln_population          — log total population
     fdi_net_inflow_pct_gdp — FDI net inflows (% of GDP)
     trade_pct_gdp          — trade openness (% of GDP)
                              [EXCLUDED for si_gdp]

   Standard errors clustered at the country (id) level throughout.
   ========================================================= */


/* =========================================================
   1. LOAD DATA
   ========================================================= */

import delimited "data path", ///
    clear varnames(1) bindquote(strict)

/* iso3 is a string — encode to numeric id for xtset and FE absorption */
encode iso3, gen(id)

/* Declare panel structure */
xtset id year

/* Keep 1960–2023 */
keep if year >= 1960 & year <= 2023

/* Log transforms */
gen ln_population = ln(population)
gen ln_gdp_pc     = ln(gdp_pc_const_2015_usd)

/* Pre-generate 2-year lags as named variables */
gen L2_si_dir_tot_trade_normalized = L2.si_dir_tot_trade_normalized
gen L2_si_tot_w5                   = L2.si_tot_w5
gen L2_si_tot_w10                  = L2.si_tot_w10
gen L2_si_gdp_nominal              = L2.si_gdp_nominal
gen L2_si_mdis                     = L2.si_mdis
gen L2_si_xdis                     = L2.si_xdis

label var L2_si_dir_tot_trade_normalized "2-year lag: si_dir_tot_trade_normalized"
label var L2_si_tot_w5                   "2-year lag: si_tot_w5"
label var L2_si_tot_w10                  "2-year lag: si_tot_w10"
label var L2_si_gdp_nominal              "2-year lag: si_gdp_nominal"
label var L2_si_mdis                     "2-year lag: si_mdis"
label var L2_si_xdis                     "2-year lag: si_xdis"

log using "....log", replace text


/* ---------------------------------------------------------
   INDEX 1 (Baseline) : si_dir_tot_trade_normalized
   Controls: ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp
   --------------------------------------------------------- */
di _newline(2) "===== INDEX 1: si_dir_tot_trade_normalized ====="

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_dirTot_l

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_dirTot_l

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_dirTot_l


/* ---------------------------------------------------------
   INDEX 2: si_tot_w5
   Controls: ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp
   --------------------------------------------------------- */
di _newline(2) "===== INDEX 2: si_tot_w5 ====="

ppmlhdfe total_patents L2_si_tot_w5 ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_w5_l

ppmlhdfe y02_patents L2_si_tot_w5 ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_w5_l

ppmlhdfe fossil_fuel_patents L2_si_tot_w5 ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_w5_l


/* ---------------------------------------------------------
   INDEX 3: si_tot_w10
   Controls: ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp
   --------------------------------------------------------- */
di _newline(2) "===== INDEX 3: si_tot_w10 ====="

ppmlhdfe total_patents L2_si_tot_w10 ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_w10_l

ppmlhdfe y02_patents L2_si_tot_w10 ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_w10_l

ppmlhdfe fossil_fuel_patents L2_si_tot_w10 ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_w10_l


/* ---------------------------------------------------------
   INDEX 4: si_gdp_nominal
   Controls: ln_gdp_pc ln_population fdi_net_inflow_pct_gdp
   NOTE: trade_pct_gdp is EXCLUDED — it appears in the
   denominator of si_gdp, creating a mechanical relationship.
   --------------------------------------------------------- */
di _newline(2) "===== INDEX 4: si_gdp  [trade_pct_gdp excluded from controls] ====="

ppmlhdfe total_patents L2_si_gdp_nominal ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_gdp_l

ppmlhdfe y02_patents L2_si_gdp_nominal ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_gdp_l

ppmlhdfe fossil_fuel_patents L2_si_gdp_nominal ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_gdp_l


/* ---------------------------------------------------------
   INDEX 5: si_mdis
   Controls: ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp
   --------------------------------------------------------- */
di _newline(2) "===== INDEX 5: si_mdis ====="

ppmlhdfe total_patents L2_si_mdis ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_mdis_l

ppmlhdfe y02_patents L2_si_mdis ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_mdis_l

ppmlhdfe fossil_fuel_patents L2_si_mdis ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_mdis_l


/* ---------------------------------------------------------
   INDEX 6: si_xdis
   Controls: ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp
   --------------------------------------------------------- */
di _newline(2) "===== INDEX 6: si_xdis ====="

ppmlhdfe total_patents L2_si_xdis ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_xdis_l

ppmlhdfe y02_patents L2_si_xdis ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_xdis_l

ppmlhdfe fossil_fuel_patents L2_si_xdis ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_xdis_l


log close

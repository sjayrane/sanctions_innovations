/* =========================================================
   COUNTRY EXCLUSION ROBUSTNESS — PPMLHDFE
   Index     : si_dir_tot_trade_normalized (SI_dir) (2-year lag)
   Outcomes  : total_patents, y02_patents, fossil_fuel_patents
   Spec      : Country FE + Year FE + controls
   Countries excluded one at a time:
               Full sample, IRN, VEN, CHN, RUS, USA, SAU, ISR
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
   2. FULL SAMPLE
   ========================================================= */

di _newline(2) "===== Full sample ====="

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store tot_full

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store grn_full

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp, ///
    absorb(id year) vce(cluster id)
estimates store fos_full


/* =========================================================
   3. EXCLUDING IRAN (IRN)
   ========================================================= */

di _newline(2) "===== Excluding Iran (IRN) ====="

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "IRN", absorb(id year) vce(cluster id)
estimates store tot_IRN

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "IRN", absorb(id year) vce(cluster id)
estimates store grn_IRN

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "IRN", absorb(id year) vce(cluster id)
estimates store fos_IRN


/* =========================================================
   4. EXCLUDING VENEZUELA (VEN)
   ========================================================= */

di _newline(2) "===== Excluding Venezuela (VEN) ====="

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "VEN", absorb(id year) vce(cluster id)
estimates store tot_VEN

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "VEN", absorb(id year) vce(cluster id)
estimates store grn_VEN

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "VEN", absorb(id year) vce(cluster id)
estimates store fos_VEN


/* =========================================================
   5. EXCLUDING CHINA (CHN)
   ========================================================= */

di _newline(2) "===== Excluding China (CHN) ====="

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "CHN", absorb(id year) vce(cluster id)
estimates store tot_CHN

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "CHN", absorb(id year) vce(cluster id)
estimates store grn_CHN

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "CHN", absorb(id year) vce(cluster id)
estimates store fos_CHN


/* =========================================================
   6. EXCLUDING RUSSIA (RUS)
   ========================================================= */

di _newline(2) "===== Excluding Russia (RUS) ====="

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "RUS", absorb(id year) vce(cluster id)
estimates store tot_RUS

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "RUS", absorb(id year) vce(cluster id)
estimates store grn_RUS

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "RUS", absorb(id year) vce(cluster id)
estimates store fos_RUS


/* =========================================================
   7. EXCLUDING UNITED STATES (USA)
   ========================================================= */

di _newline(2) "===== Excluding United States (USA) ====="

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "USA", absorb(id year) vce(cluster id)
estimates store tot_USA

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "USA", absorb(id year) vce(cluster id)
estimates store grn_USA

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "USA", absorb(id year) vce(cluster id)
estimates store fos_USA


/* =========================================================
   8. EXCLUDING SAUDI ARABIA (SAU)
   ========================================================= */

di _newline(2) "===== Excluding Saudi Arabia (SAU) ====="

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "SAU", absorb(id year) vce(cluster id)
estimates store tot_SAU

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "SAU", absorb(id year) vce(cluster id)
estimates store grn_SAU

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "SAU", absorb(id year) vce(cluster id)
estimates store fos_SAU


/* =========================================================
   9. EXCLUDING ISRAEL (ISR)
   ========================================================= */

di _newline(2) "===== Excluding Israel (ISR) ====="

ppmlhdfe total_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "ISR", absorb(id year) vce(cluster id)
estimates store tot_ISR

ppmlhdfe y02_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "ISR", absorb(id year) vce(cluster id)
estimates store grn_ISR

ppmlhdfe fossil_fuel_patents L2_si_dir_tot_trade_normalized ///
    ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp ///
    if iso3 != "ISR", absorb(id year) vce(cluster id)
estimates store fos_ISR


/* =========================================================
   10. SUMMARY TABLE
   ========================================================= */

di _newline(3) "========================================================="
di              "  COUNTRY EXCLUSION RESULTS: si_dir_tot_trade_normalized [L2]"
di              "  Specification: Country FE + Year FE + Controls"
di              "========================================================="

local samples full IRN VEN CHN RUS USA SAU ISR

foreach out in tot grn fos {

    if "`out'" == "tot" local outlabel "Total patents"
    if "`out'" == "grn" local outlabel "Green patents"
    if "`out'" == "fos" local outlabel "Fossil fuel patents"

    di _newline "--- `outlabel' ---"
    di "  Sample                        b (SE)"

    foreach smp of local samples {

        if "`smp'" == "full" local smplabel "Full sample"
        if "`smp'" == "IRN"  local smplabel "Excl. Iran (IRN)"
        if "`smp'" == "VEN"  local smplabel "Excl. Venezuela (VEN)"
        if "`smp'" == "CHN"  local smplabel "Excl. China (CHN)"
        if "`smp'" == "RUS"  local smplabel "Excl. Russia (RUS)"
        if "`smp'" == "USA"  local smplabel "Excl. United States (USA)"
        if "`smp'" == "SAU"  local smplabel "Excl. Saudi Arabia (SAU)"
        if "`smp'" == "ISR"  local smplabel "Excl. Israel (ISR)"

        estimates restore `out'_`smp'
        local b  = _b[L2_si_dir_tot_trade_normalized]
        local se = _se[L2_si_dir_tot_trade_normalized]
        local z  = `b' / `se'
        local p  = 2 * (1 - normal(abs(`z')))

        local stars ""
        if `p' < 0.01      local stars "***"
        else if `p' < 0.05 local stars "**"
        else if `p' < 0.10 local stars "*"

        di "  `smplabel'   " %8.4f `b' " (" %6.4f `se' ") `stars'"
    }
}

di _newline "  Significance: * p<0.10  ** p<0.05  *** p<0.01"

log close

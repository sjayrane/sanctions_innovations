/* =========================================================
   BINARY SANCTION INDICATORS — PPMLHDFE
   Estimator : ppmlhdfe (Poisson PML with high-dimensional FE)

   INDICATORS (9 total, separate regressions):
   -------------------------------------------------------
   Sender aggregates:
     sanctioned_by_us    sanctioned_by_un    sanctioned_by_eu
   Sender × Type:
     us_trade            eu_trade            un_trade
     us_financial        eu_financial        un_financial

   OUTCOMES:
     total_patents        — all patents
     y02_patents          — green/clean patents (Y02 CPC class)
     fossil_fuel_patents  — fossil fuel patents

   CONTROLS (all specifications):
     ln_gdp_pc              — log GDP per capita (constant 2015 USD)
     ln_population          — log total population
     fdi_net_inflow_pct_gdp — FDI net inflows (% of GDP)
     trade_pct_gdp          — trade openness (% of GDP)

   Standard errors clustered at the country level throughout, 
   country and year fixed effects throughout.
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

/* Pre-generate 2-year lags for all 9 binary indicators */
foreach var in sanctioned_by_us sanctioned_by_un sanctioned_by_eu ///
               us_trade eu_trade un_trade ///
               us_financial eu_financial un_financial {
    gen L2_`var' = L2.`var'
    label var L2_`var' "2-year lag: `var'"
}

log using "....log", replace text


/* =========================================================
   2. REGRESSIONS
   =========================================================
   Structure: one block per indicator.
   Within each block:
     - 3 2-year lag regressions (tot / grn / fos)
   Estimate naming: {outcome}_{indicator}_l
   ========================================================= */

local controls ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp


/* ---------------------------------------------------------
   BLOCK 1: sanctioned_by_us
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: sanctioned_by_us ====="

ppmlhdfe total_patents L2_sanctioned_by_us `controls', absorb(id year) vce(cluster id)
estimates store tot_us_l

ppmlhdfe y02_patents L2_sanctioned_by_us `controls', absorb(id year) vce(cluster id)
estimates store grn_us_l

ppmlhdfe fossil_fuel_patents L2_sanctioned_by_us `controls', absorb(id year) vce(cluster id)
estimates store fos_us_l


/* ---------------------------------------------------------
   BLOCK 2: sanctioned_by_un
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: sanctioned_by_un ====="

ppmlhdfe total_patents L2_sanctioned_by_un `controls', absorb(id year) vce(cluster id)
estimates store tot_un_l

ppmlhdfe y02_patents L2_sanctioned_by_un `controls', absorb(id year) vce(cluster id)
estimates store grn_un_l

ppmlhdfe fossil_fuel_patents L2_sanctioned_by_un `controls', absorb(id year) vce(cluster id)
estimates store fos_un_l


/* ---------------------------------------------------------
   BLOCK 3: sanctioned_by_eu
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: sanctioned_by_eu ====="

ppmlhdfe total_patents L2_sanctioned_by_eu `controls', absorb(id year) vce(cluster id)
estimates store tot_eu_l

ppmlhdfe y02_patents L2_sanctioned_by_eu `controls', absorb(id year) vce(cluster id)
estimates store grn_eu_l

ppmlhdfe fossil_fuel_patents L2_sanctioned_by_eu `controls', absorb(id year) vce(cluster id)
estimates store fos_eu_l


/* ---------------------------------------------------------
   BLOCK 4: us_trade
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: us_trade ====="

ppmlhdfe total_patents L2_us_trade `controls', absorb(id year) vce(cluster id)
estimates store tot_ustr_l

ppmlhdfe y02_patents L2_us_trade `controls', absorb(id year) vce(cluster id)
estimates store grn_ustr_l

ppmlhdfe fossil_fuel_patents L2_us_trade `controls', absorb(id year) vce(cluster id)
estimates store fos_ustr_l


/* ---------------------------------------------------------
   BLOCK 5: eu_trade
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: eu_trade ====="

ppmlhdfe total_patents L2_eu_trade `controls', absorb(id year) vce(cluster id)
estimates store tot_eutr_l

ppmlhdfe y02_patents L2_eu_trade `controls', absorb(id year) vce(cluster id)
estimates store grn_eutr_l

ppmlhdfe fossil_fuel_patents L2_eu_trade `controls', absorb(id year) vce(cluster id)
estimates store fos_eutr_l


/* ---------------------------------------------------------
   BLOCK 6: un_trade
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: un_trade ====="

ppmlhdfe total_patents L2_un_trade `controls', absorb(id year) vce(cluster id)
estimates store tot_untr_l

ppmlhdfe y02_patents L2_un_trade `controls', absorb(id year) vce(cluster id)
estimates store grn_untr_l

ppmlhdfe fossil_fuel_patents L2_un_trade `controls', absorb(id year) vce(cluster id)
estimates store fos_untr_l


/* ---------------------------------------------------------
   BLOCK 7: us_financial
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: us_financial ====="

ppmlhdfe total_patents L2_us_financial `controls', absorb(id year) vce(cluster id)
estimates store tot_usfin_l

ppmlhdfe y02_patents L2_us_financial `controls', absorb(id year) vce(cluster id)
estimates store grn_usfin_l

ppmlhdfe fossil_fuel_patents L2_us_financial `controls', absorb(id year) vce(cluster id)
estimates store fos_usfin_l


/* ---------------------------------------------------------
   BLOCK 8: eu_financial
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: eu_financial ====="

ppmlhdfe total_patents L2_eu_financial `controls', absorb(id year) vce(cluster id)
estimates store tot_eufin_l

ppmlhdfe y02_patents L2_eu_financial `controls', absorb(id year) vce(cluster id)
estimates store grn_eufin_l

ppmlhdfe fossil_fuel_patents L2_eu_financial `controls', absorb(id year) vce(cluster id)
estimates store fos_eufin_l


/* ---------------------------------------------------------
   BLOCK 9: un_financial
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: un_financial ====="

ppmlhdfe total_patents L2_un_financial `controls', absorb(id year) vce(cluster id)
estimates store tot_unfin_l

ppmlhdfe y02_patents L2_un_financial `controls', absorb(id year) vce(cluster id)
estimates store grn_unfin_l

ppmlhdfe fossil_fuel_patents L2_un_financial `controls', absorb(id year) vce(cluster id)
estimates store fos_unfin_l


/* =========================================================
   3. SUMMARY TABLE
   ========================================================= */

di _newline(3) "========================================================="
di              "  SUMMARY — BINARY INDICATORS"
di              "  Spec: Country FE + Year FE + full controls  (1960–2023)"
di              "  Col order: total_patents | y02_patents | fossil_fuel_patents"
di              "========================================================="
di              "  Indicator            timing    tot (SE)         grn (SE)         fos (SE)"
di              "  --------------------------------------------------------------------------"

local inds    us      un      eu      ustr    eutr    untr    usfin   eufin   unfin
local cvars   sanctioned_by_us sanctioned_by_un sanctioned_by_eu us_trade eu_trade un_trade us_financial eu_financial un_financial
local labels  "sanctioned_by_us" "sanctioned_by_un" "sanctioned_by_eu" "us_trade" "eu_trade" "un_trade" "us_financial" "eu_financial" "un_financial"

local n : word count `inds'
forvalues i = 1/`n' {
    local ind   : word `i' of `inds'
    local cvar  : word `i' of `cvars'
    local lvar  L2_`cvar'
    local lab   : word `i' of `labels'

    foreach pre in tot grn fos {
        estimates restore `pre'_`ind'_l
        local b_`pre'_l  = _b[`lvar']
        local se_`pre'_l = _se[`lvar']
    }
    di "  `lab'" _col(25) "[2yr lag]" ///
       "  " %7.4f `b_tot_l' " (" %6.4f `se_tot_l' ")" ///
       "   " %7.4f `b_grn_l' " (" %6.4f `se_grn_l' ")" ///
       "   " %7.4f `b_fos_l' " (" %6.4f `se_fos_l' ")"
    di "  --------------------------------------------------------------------------"
}

log close

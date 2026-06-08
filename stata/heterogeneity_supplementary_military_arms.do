/* =========================================================
   BINARY SANCTION INDICATORS — PPMLHDFE
   MILITARY & ARMS ONLY
   Estimator : ppmlhdfe (Poisson PML with high-dimensional FE)

   INDICATORS (6 total, separate regressions):
   -------------------------------------------------------
   Sender × Type:
     us_military         eu_military         un_military
     us_arms             eu_arms             un_arms

   OUTCOMES:
     total_patents        — all patents
     y02_patents          — green/clean patents (Y02 CPC class)
     fossil_fuel_patents  — fossil fuel patents

   CONTROLS (all specifications):
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

/* Pre-generate 2-year lags for military and arms indicators */
foreach var in us_military eu_military un_military ///
               us_arms eu_arms un_arms {
    gen L2_`var' = L2.`var'
    label var L2_`var' "2-year lag: `var'"
}

log using "log", replace text


/* =========================================================
   2. REGRESSIONS
   =========================================================
   Structure: one block per indicator.
   Within each block:
     - 3 2-year lag regressions (tot / grn / fos)
   Estimate naming: {outcome}_{indicator}_l
   ========================================================= */

local controls ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp
estimates clear


/* ---------------------------------------------------------
   BLOCK 1: us_military
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: us_military ====="

ppmlhdfe total_patents L2_us_military `controls', absorb(id year) vce(cluster id)
estimates store tot_usmil_l

ppmlhdfe y02_patents L2_us_military `controls', absorb(id year) vce(cluster id)
estimates store grn_usmil_l

ppmlhdfe fossil_fuel_patents L2_us_military `controls', absorb(id year) vce(cluster id)
estimates store fos_usmil_l


/* ---------------------------------------------------------
   BLOCK 2: eu_military
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: eu_military ====="

ppmlhdfe total_patents L2_eu_military `controls', absorb(id year) vce(cluster id)
estimates store tot_eumil_l

ppmlhdfe y02_patents L2_eu_military `controls', absorb(id year) vce(cluster id)
estimates store grn_eumil_l

ppmlhdfe fossil_fuel_patents L2_eu_military `controls', absorb(id year) vce(cluster id)
estimates store fos_eumil_l


/* ---------------------------------------------------------
   BLOCK 3: un_military
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: un_military ====="

ppmlhdfe total_patents L2_un_military `controls', absorb(id year) vce(cluster id)
estimates store tot_unmil_l

ppmlhdfe y02_patents L2_un_military `controls', absorb(id year) vce(cluster id)
estimates store grn_unmil_l

ppmlhdfe fossil_fuel_patents L2_un_military `controls', absorb(id year) vce(cluster id)
estimates store fos_unmil_l


/* ---------------------------------------------------------
   BLOCK 4: us_arms
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: us_arms ====="

ppmlhdfe total_patents L2_us_arms `controls', absorb(id year) vce(cluster id)
estimates store tot_usarm_l

ppmlhdfe y02_patents L2_us_arms `controls', absorb(id year) vce(cluster id)
estimates store grn_usarm_l

ppmlhdfe fossil_fuel_patents L2_us_arms `controls', absorb(id year) vce(cluster id)
estimates store fos_usarm_l


/* ---------------------------------------------------------
   BLOCK 5: eu_arms
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: eu_arms ====="

ppmlhdfe total_patents L2_eu_arms `controls', absorb(id year) vce(cluster id)
estimates store tot_euarm_l

ppmlhdfe y02_patents L2_eu_arms `controls', absorb(id year) vce(cluster id)
estimates store grn_euarm_l

ppmlhdfe fossil_fuel_patents L2_eu_arms `controls', absorb(id year) vce(cluster id)
estimates store fos_euarm_l


/* ---------------------------------------------------------
   BLOCK 6: un_arms
   --------------------------------------------------------- */
di _newline(2) "===== INDICATOR: un_arms ====="

ppmlhdfe total_patents L2_un_arms `controls', absorb(id year) vce(cluster id)
estimates store tot_unarm_l

ppmlhdfe y02_patents L2_un_arms `controls', absorb(id year) vce(cluster id)
estimates store grn_unarm_l

ppmlhdfe fossil_fuel_patents L2_un_arms `controls', absorb(id year) vce(cluster id)
estimates store fos_unarm_l


/* =========================================================
   3. SUMMARY TABLE
   ========================================================= */

di _newline(3) "========================================================="
di              "  SUMMARY — MILITARY & ARMS INDICATORS"
di              "  Spec: Country FE + Year FE + full controls  (1960–2023)"
di              "  Col order: total_patents | y02_patents | fossil_fuel_patents"
di              "========================================================="
di              "  Indicator            timing    tot (SE)         grn (SE)         fos (SE)"
di              "  --------------------------------------------------------------------------"

local inds    usmil   eumil   unmil   usarm   euarm   unarm
local cvars   us_military eu_military un_military us_arms eu_arms un_arms
local labels  "us_military" "eu_military" "un_military" "us_arms" "eu_arms" "un_arms"

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

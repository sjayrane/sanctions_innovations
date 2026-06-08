/* =========================================================
   ROBUSTNESS — ppmlhdfe only
   Index     : si_dir_tot_trade_normalized (2-year lag)
   Outcomes  : frac_green, frac_fossil,
               green_of_direction (= y02 / (y02 + fossil)),
               fossil_of_direction (= fossil / (y02 + fossil))
   Samples   : A — total_patents > 0
               B — total_patents > 10
   Countries : Full | -CHN | -RUS | -SAU
   Spec      : Country FE + Year FE + controls
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

gen L2_si_dir = L2.si_dir_tot_trade_normalized
label var L2_si_dir "2-year lag: si_dir_tot_trade_normalized"

gen green_of_direction  = y02_patents         / (y02_patents + fossil_fuel_patents)
gen fossil_of_direction = fossil_fuel_patents / (y02_patents + fossil_fuel_patents)
label var green_of_direction  "Green share of directional patents (y02 / (y02+fossil))"
label var fossil_of_direction "Fossil share of directional patents (fossil / (y02+fossil))"

set varabbrev off

cap log close
log using "log", replace text


/* =========================================================
   2. DEFINE LOCALS
   ========================================================= */

local xvar     L2_si_dir
local controls ln_gdp_pc ln_population fdi_net_inflow_pct_gdp trade_pct_gdp

local outcomes  frac_green_a      frac_fossil_a      green_of_direction  fossil_of_direction
local abbrevs   fga               ffa                god                 fod

local cond_pos  "total_patents > 0"
local cond_gt10 "total_patents > 10"

local excl_full ""
local excl_CHN  `"& iso3 != "CHN""'
local excl_RUS  `"& iso3 != "RUS""'
local excl_SAU  `"& iso3 != "SAU""'

local excl_list full CHN RUS SAU


/* =========================================================
   3. PPML REGRESSIONS — quietly to avoid system limit
   ========================================================= */

di _newline(3) "========================================================="
di              "  ESTIMATOR: ppmlhdfe"
di              "  Spec: Country FE + Year FE + controls"
di              "========================================================="

foreach samp in pos gt10 {

    local scond  = cond("`samp'" == "pos", "`cond_pos'", "`cond_gt10'")
    local slabel = cond("`samp'" == "pos", "A (> 0)", "B (> 10)")

    di _newline(2) "----- PPML | Sample `slabel' -----"

    foreach excl of local excl_list {

        local econd "`excl_`excl''"
        di _newline "  -- Country: `excl' --"

        local k = 1
        foreach outcome of local outcomes {
            local abbr : word `k' of `abbrevs'

            di "  ppmlhdfe `outcome' | sample `slabel' | excl `excl'"

            qui ppmlhdfe `outcome' `xvar' `controls' ///
                if `scond' `econd', ///
                absorb(id year) vce(cluster id)

            est store pml_`abbr'_`samp'_`excl'

            local ++k
        }
    }
}


/* =========================================================
   4. SUMMARY TABLE
   ========================================================= */

di _newline(3) "========================================================="
di              "  RESULTS: PPML — Coefficients on L2_si_dir"
di              "  Spec: Country FE + Year FE + controls"
di              "  Columns: Full | -CHN | -RUS | -SAU"
di              "========================================================="

foreach samp in pos gt10 {

    local slabel = cond("`samp'" == "pos", "A (total_patents > 0)", "B (total_patents > 10)")

    di _newline "--- Sample `slabel' ---"
    di "  Outcome                   Full              -CHN              -RUS              -SAU"

    local k = 1
    foreach outcome of local outcomes {
        local abbr : word `k' of `abbrevs'

        /* Retrieve each column separately to avoid nested macro quoting */
        qui estimates restore pml_`abbr'_`samp'_full
        local b_full  = _b[`xvar']
        local se_full = _se[`xvar']
        local p_full  = 2 * (1 - normal(abs(`b_full' / `se_full')))

        qui estimates restore pml_`abbr'_`samp'_CHN
        local b_CHN  = _b[`xvar']
        local se_CHN = _se[`xvar']
        local p_CHN  = 2 * (1 - normal(abs(`b_CHN' / `se_CHN')))

        qui estimates restore pml_`abbr'_`samp'_RUS
        local b_RUS  = _b[`xvar']
        local se_RUS = _se[`xvar']
        local p_RUS  = 2 * (1 - normal(abs(`b_RUS' / `se_RUS')))

        qui estimates restore pml_`abbr'_`samp'_SAU
        local b_SAU  = _b[`xvar']
        local se_SAU = _se[`xvar']
        local p_SAU  = 2 * (1 - normal(abs(`b_SAU' / `se_SAU')))

        di "  `outcome'"
        di "    coef  " %9.4f `b_full'  "   " %9.4f `b_CHN'  ///
                    "   " %9.4f `b_RUS'  "   " %9.4f `b_SAU'
        di "    SE    (" %7.4f `se_full' ")  (" %7.4f `se_CHN' ///
                   ")  (" %7.4f `se_RUS'  ")  (" %7.4f `se_SAU' ")"
        di "    p     " %9.3f `p_full'   "   " %9.3f `p_CHN'  ///
                    "   " %9.3f `p_RUS'   "   " %9.3f `p_SAU'

        local ++k
    }
}

log close

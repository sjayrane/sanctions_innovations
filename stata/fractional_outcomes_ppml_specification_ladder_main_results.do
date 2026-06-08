/* =========================================================
   RESULTS — ppmlhdfe, progressive specification ladder
   Index     : si_dir_tot_trade_normalized (2-year lag)
   Outcomes  : frac_green, frac_fossil,
               green_of_direction (= y02 / (y02 + fossil)),
               fossil_of_direction (= fossil / (y02 + fossil))
   Samples   : A — total_patents > 0
               B — total_patents > 10
   Specs     : (1) Year FE only
               (2) Country FE + Year FE
               (3) Country FE + Year FE + controls
   Full sample (no country exclusions)
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

local outcomes  frac_green      frac_fossil      green_of_direction  fossil_of_direction
local abbrevs   fg             ff                god                 fod

local cond_pos  "total_patents > 0"
local cond_gt10 "total_patents > 10"

/* --- Specifications -------------------------------------- */
local spec_list   yfe cyfe cyfec

local absorb_yfe   "year"
local absorb_cyfe  "id year"
local absorb_cyfec "id year"

local ctrl_yfe   ""
local ctrl_cyfe  ""
local ctrl_cyfec "`controls'"

local label_yfe   "(1) Year FE"
local label_cyfe  "(2) Country+Year FE"
local label_cyfec "(3) +controls"


estimates clear


/* =========================================================
   3. PPML REGRESSIONS 
   ========================================================= */

di _newline(3) "========================================================="
di              "  ESTIMATOR: ppmlhdfe"
di              "  Specs: (1) Year FE | (2) Country+Year FE | (3) +controls"
di              "========================================================="

foreach samp in pos gt10 {

    local scond  = cond("`samp'" == "pos", "`cond_pos'", "`cond_gt10'")
    local slabel = cond("`samp'" == "pos", "A (> 0)", "B (> 10)")

    foreach spec of local spec_list {

        local sabsorb "`absorb_`spec''"
        local sctrl   "`ctrl_`spec''"

        di _newline(2) "----- PPML | Sample `slabel' | Spec `label_`spec'' -----"

        local k = 1
        foreach outcome of local outcomes {
            local abbr : word `k' of `abbrevs'

            di "  ppmlhdfe `outcome' | sample `slabel' | spec `spec'"

            qui ppmlhdfe `outcome' `xvar' `sctrl' ///
                if `scond', ///
                absorb(`sabsorb') vce(cluster id)

            est store pml_`abbr'_`samp'_`spec'

            local ++k
        }
    }
}


/* =========================================================
   4. SUMMARY TABLE  (specs as columns)
   ========================================================= */

di _newline(3) "========================================================="
di              "  RESULTS: PPML — Coefficients on L2_si_dir"
di              "  Columns: (1) Year FE | (2) Country+Year FE | (3) +controls"
di              "========================================================="

foreach samp in pos gt10 {

    local slabel = cond("`samp'" == "pos", "A (total_patents > 0)", "B (total_patents > 10)")

    di _newline(2) "=== Sample `slabel' ==="
    di "  Outcome                  (1) Year FE      (2) Cty+Yr FE      (3) +controls"

    local k = 1
    foreach outcome of local outcomes {
        local abbr : word `k' of `abbrevs'

        qui estimates restore pml_`abbr'_`samp'_yfe
        local b1  = _b[`xvar']
        local se1 = _se[`xvar']
        local p1  = 2 * (1 - normal(abs(`b1' / `se1')))
        local N1  = e(N)

        qui estimates restore pml_`abbr'_`samp'_cyfe
        local b2  = _b[`xvar']
        local se2 = _se[`xvar']
        local p2  = 2 * (1 - normal(abs(`b2' / `se2')))
        local N2  = e(N)

        qui estimates restore pml_`abbr'_`samp'_cyfec
        local b3  = _b[`xvar']
        local se3 = _se[`xvar']
        local p3  = 2 * (1 - normal(abs(`b3' / `se3')))
        local N3  = e(N)

        di "  `outcome'"
        di "    coef  " %12.4f `b1'  "   " %12.4f `b2'  "   " %12.4f `b3'
        di "    SE    (" %10.4f `se1' ")  (" %10.4f `se2' ")  (" %10.4f `se3' ")"
        di "    p     " %12.3f `p1'   "   " %12.3f `p2'   "   " %12.3f `p3'
        di "    N     " %12.0f `N1'   "   " %12.0f `N2'   "   " %12.0f `N3'

        local ++k
    }
}

log close

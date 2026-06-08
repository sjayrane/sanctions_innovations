/* =========================================================
   RESULTS — fractional logit (fracreg logit), spec ladder
   WITH AVERAGE MARGINAL EFFECTS (AMEs)

   Index     : si_dir_tot_trade_normalized (2-year lag)

   Outcomes  :
      frac_green
      frac_fossil
      green_of_direction
      fossil_of_direction

   Samples   :
      A — total_patents > 0
      B — total_patents > 10

   Specs     :
      (1) Year FE only
      (2) Country FE + Year FE
      (3) Country FE + Year FE + controls

   Notes:
   - FE entered as dummies
   - AMEs reported using margins, dydx().
   - Directional-share outcomes restricted to positive denominator.
   ========================================================= */


/* =========================================================
   1. LOAD DATA
   ========================================================= */

import delimited "data path", ///
    clear varnames(1) bindquote(strict)

encode iso3, gen(id)

isid id year
xtset id year

keep if year >= 1960 & year <= 2023

gen ln_population = ln(population)
gen ln_gdp_pc     = ln(gdp_pc_const_2015_usd)

gen L2_si_dir = L2.si_dir_tot_trade_normalized
label var L2_si_dir "2-year lag: si_dir_tot_trade_normalized"

gen directional_total = y02_patents + fossil_fuel_patents

gen green_of_direction  = y02_patents         / directional_total
gen fossil_of_direction = fossil_fuel_patents / directional_total

label var green_of_direction  ///
    "Green share of directional patents (y02 / (y02+fossil))"

label var fossil_of_direction ///
    "Fossil share of directional patents (fossil / (y02+fossil))"

set varabbrev off

cap log close
log using ///
"log", ///
replace text


/* =========================================================
   2. DEFINE LOCALS
   ========================================================= */

local xvar     L2_si_dir
local controls ln_gdp_pc ln_population ///
               fdi_net_inflow_pct_gdp trade_pct_gdp

local outcomes  frac_green ///
                frac_fossil ///
                green_of_direction ///
                fossil_of_direction

local abbrevs   fg ///
                ff ///
                god ///
                fod

/* --- sample restrictions -------------------------------- */

local cond_pos      "total_patents > 0"
local cond_gt10     "total_patents > 10"

local cond_dir_pos  ///
    "total_patents > 0 & directional_total > 0"

local cond_dir_gt10 ///
    "total_patents > 10 & directional_total > 0"

/* --- Specifications ------------------------------------- */

local spec_list yfe cyfe cyfec

local fe_yfe     "i.year"
local fe_cyfe    "i.id i.year"
local fe_cyfec   "i.id i.year"

local ctrl_yfe   ""
local ctrl_cyfe  ""
local ctrl_cyfec "`controls'"

local label_yfe   "(1) Year FE"
local label_cyfe  "(2) Country+Year FE"
local label_cyfec "(3) +controls"

estimates clear


/* =========================================================
   3. FRACTIONAL LOGIT REGRESSIONS + AMEs
   ========================================================= */

di _newline(3) "========================================================="
di              "  ESTIMATOR: fracreg logit"
di              "  Reporting: coefficients + average marginal effects"
di              "========================================================="

foreach samp in pos gt10 {

    local slabel = cond("`samp'" == "pos", ///
        "A (>0)", ///
        "B (>10)")

    foreach spec of local spec_list {

        local sfe   "`fe_`spec''"
        local sctrl "`ctrl_`spec''"

        di _newline(2) ///
        "----- Sample `slabel' | Spec `label_`spec'' -----"

        local k = 1

        foreach outcome of local outcomes {

            local abbr : word `k' of `abbrevs'

            /* ----- choose correct sample restriction ----- */

            if inlist("`outcome'", ///
                "green_of_direction", ///
                "fossil_of_direction") {

                local scond = cond("`samp'" == "pos", ///
                    "`cond_dir_pos'", ///
                    "`cond_dir_gt10'")
            }

            else {

                local scond = cond("`samp'" == "pos", ///
                    "`cond_pos'", ///
                    "`cond_gt10'")
            }

            di "  fracreg logit `outcome'"

            quietly fracreg logit ///
                `outcome' ///
                `xvar' ///
                `sctrl' ///
                `sfe' ///
                if `scond', ///
                vce(cluster id)

            estimates store frl_`abbr'_`samp'_`spec'

            /* ----- Average Marginal Effect ----- */

            quietly margins, dydx(`xvar')

            estimates store ame_`abbr'_`samp'_`spec'

            local ++k
        }
    }
}


/* =========================================================
   4. DISPLAY RESULTS
   ========================================================= */

di _newline(3) "========================================================="
di              "  RESULTS: Average Marginal Effects"
di              "========================================================="

foreach samp in pos gt10 {

    local slabel = cond("`samp'" == "pos", ///
        "A (total_patents > 0)", ///
        "B (total_patents > 10)")

    di _newline(2) "=== Sample `slabel' ==="

    local k = 1

    foreach outcome of local outcomes {

        local abbr : word `k' of `abbrevs'

        di _newline(1) "Outcome: `outcome'"
        di "------------------------------------------------------"
        di "                (1)         (2)         (3)"
        di "------------------------------------------------------"

        foreach spec of local spec_list {

            quietly estimates restore ame_`abbr'_`samp'_`spec'

            local b  = _b[`xvar']
            local se = _se[`xvar']

            local p = 2 * ttail(e(df_r), abs(`b'/`se'))

            di ///
            "`label_`spec'' : " ///
            %9.4f `b' ///
            " (" %9.4f `se' ")" ///
            "  p=" %6.3f `p'
        }

        local ++k
    }
}

log close


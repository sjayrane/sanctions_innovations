/* =========================================================
   FRACTIONAL LOGIT — TRUE AMEs
   Index     : si_dir_tot_trade_normalized (2-year lag, L2_si_dir)
   Outcomes  : frac_green, frac_fossil,
               green_of_direction (= y02 / (y02 + fossil)),
               fossil_of_direction (= fossil / (y02 + fossil))
   Samples   : A — total_patents > 0
               B — total_patents > 10
   Countries : Full | -CHN | -RUS | -SAU
   Spec      : Country FE + Year FE + controls
   Note      : margins uses post option so est store saves AMEs
   ========================================================= */


/* =========================================================
   1. LOAD DATA
   ========================================================= */

import delimited ///
"data path", ///
clear varnames(1) bindquote(strict)

encode iso3, gen(id)

isid id year
xtset id year

keep if year >= 1960 & year <= 2023

gen ln_population = ln(population)
gen ln_gdp_pc     = ln(gdp_pc_const_2015_usd)

gen L2_si_dir = L2.si_dir_tot_trade_normalized

label var L2_si_dir ///
    "2-year lag: si_dir_tot_trade_normalized"

/* directional denominator */

gen directional_total = ///
    y02_patents + fossil_fuel_patents

/* directional shares */

gen green_of_direction = ///
    y02_patents / directional_total

gen fossil_of_direction = ///
    fossil_fuel_patents / directional_total

set varabbrev off

cap log close

log using ///
"log", ///
replace text


/* =========================================================
   2. DEFINE LOCALS
   ========================================================= */

local xvar L2_si_dir

local controls ///
    ln_gdp_pc ///
    ln_population ///
    fdi_net_inflow_pct_gdp ///
    trade_pct_gdp

local outcomes ///
    frac_green ///
    frac_fossil ///
    green_of_direction ///
    fossil_of_direction

local abbrevs ///
    fg ///
    ff ///
    god ///
    fod

/* sample restrictions */

local cond_pos ///
    "total_patents > 0"

local cond_gt10 ///
    "total_patents > 10"

local cond_dir_pos ///
    "total_patents > 0 & directional_total > 0"

local cond_dir_gt10 ///
    "total_patents > 10 & directional_total > 0"

estimates clear


/* =========================================================
   3. FRACTIONAL LOGIT + TRUE AMEs
   ========================================================= */

di _newline(3) ///
"========================================================="

di "  TRUE AMEs FROM FRACTIONAL LOGIT"

di ///
"========================================================="

foreach sample in pos gt10 {

    local samp_label = ///
        cond("`sample'" == "pos", ///
        "A (>0)", ///
        "B (>10)")

    di _newline ///
    "=== Sample `samp_label' ==="

    local k = 1

    foreach outcome of local outcomes {

        local abbr : word `k' of `abbrevs'

        /* choose correct sample */

        if inlist("`outcome'", ///
            "green_of_direction", ///
            "fossil_of_direction") {

            local scond = ///
                cond("`sample'" == "pos", ///
                "`cond_dir_pos'", ///
                "`cond_dir_gt10'")
        }

        else {

            local scond = ///
                cond("`sample'" == "pos", ///
                "`cond_pos'", ///
                "`cond_gt10'")
        }

        di _newline ///
        "--- Outcome: `outcome' ---"

        /* estimate fraclogit */

        quietly fracreg logit ///
            `outcome' ///
            `xvar' ///
            `controls' ///
            i.id i.year ///
            if `scond', ///
            vce(cluster id)

        estimates store ///
            coef_`abbr'_`sample'

        /* TRUE average marginal effects */

        quietly margins, dydx(`xvar') post

        estimates store ///
            ame_`abbr'_`sample'

        /* extract AME */

        local b  = _b[`xvar']
        local se = _se[`xvar']

        local p = ///
            2 * ttail(e(df_r), ///
            abs(`b'/`se'))

        di ///
        "AME = " ///
        %9.4f `b' ///
        "   SE = " ///
        %9.4f `se' ///
        "   p = " ///
        %6.3f `p'

        local ++k
    }
}


/* =========================================================
   4. COUNTRY EXCLUSIONS
   ========================================================= */

di _newline(3) ///
"========================================================="

di "  COUNTRY EXCLUSION AMEs"

di ///
"========================================================="

foreach sample in pos gt10 {

    local samp_label = ///
        cond("`sample'" == "pos", ///
        "A (>0)", ///
        "B (>10)")

    di _newline ///
    "=== Sample `samp_label' ==="

    foreach excl in CHN RUS SAU {

        di _newline ///
        "--- Excluding `excl' ---"

        local k = 1

        foreach outcome of local outcomes {

            local abbr : word `k' of `abbrevs'

            /* choose correct sample */

            if inlist("`outcome'", ///
                "green_of_direction", ///
                "fossil_of_direction") {

                local scond = ///
                    cond("`sample'" == "pos", ///
                    "`cond_dir_pos'", ///
                    "`cond_dir_gt10'")
            }

            else {

                local scond = ///
                    cond("`sample'" == "pos", ///
                    "`cond_pos'", ///
                    "`cond_gt10'")
            }

            quietly fracreg logit ///
                `outcome' ///
                `xvar' ///
                `controls' ///
                i.id i.year ///
                if `scond' & iso3 != "`excl'", ///
                vce(cluster id)

            /* TRUE AMEs */

            quietly margins, ///
                dydx(`xvar') post

            estimates store ///
                ame_`abbr'_`sample'_no`excl'

            local ++k
        }
    }
}


/* =========================================================
   5. SUMMARY TABLE
   ========================================================= */

di _newline(3) ///
"========================================================="

di "  SUMMARY: TRUE AMEs"

di ///
"========================================================="

foreach sample in pos gt10 {

    local samp_label = ///
        cond("`sample'" == "pos", ///
        "A (total_patents > 0)", ///
        "B (total_patents > 10)")

    di _newline ///
    "=== Sample `samp_label' ==="

    local k = 1

    foreach outcome of local outcomes {

        local abbr : word `k' of `abbrevs'

        di _newline ///
        "Outcome: `outcome'"

        di ///
"------------------------------------------------------"

        di ///
"             Full        -CHN       -RUS       -SAU"

        di ///
"------------------------------------------------------"

        /* full sample */

        estimates restore ///
            ame_`abbr'_`sample'

        local b_full  = _b[`xvar']
        local se_full = _se[`xvar']

        /* exclusions */

        foreach excl in CHN RUS SAU {

            estimates restore ///
                ame_`abbr'_`sample'_no`excl'

            local b_`excl'  = _b[`xvar']
            local se_`excl' = _se[`xvar']
        }

        di ///
"AME   " ///
%9.4f `b_full' ///
"   " ///
%9.4f `b_CHN' ///
"   " ///
%9.4f `b_RUS' ///
"   " ///
%9.4f `b_SAU'

        di ///
"SE    " ///
%9.4f `se_full' ///
"   " ///
%9.4f `se_CHN' ///
"   " ///
%9.4f `se_RUS' ///
"   " ///
%9.4f `se_SAU'

        local ++k
    }
}

log close

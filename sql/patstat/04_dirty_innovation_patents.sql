CREATE TABLE pf_inv_ctry_year_frac_dirty_innovation AS
WITH base AS (
    SELECT DISTINCT
        appln_id,
        priority_year,
        ctry_code,
        person_id
    FROM pf_inv_pers_ctry_all
    WHERE ctry_code IS NOT NULL
      AND priority_year IS NOT NULL
),

-- total inventors per appln_id x priority_year
inv_tot AS (
    SELECT
        appln_id,
        priority_year,
        COUNT(DISTINCT person_id) AS n_inv
    FROM base
    GROUP BY appln_id, priority_year
),

-- inventors per appln_id x priority_year x country
inv_ctry AS (
    SELECT
        appln_id,
        priority_year,
        ctry_code,
        COUNT(DISTINCT person_id) AS n_inv_ctry
    FROM base
    GROUP BY appln_id, priority_year, ctry_code
),

-- fossil fuel supply ("dirty") CPC flag per application
cpc_dirty_flag AS (
    SELECT
        appln_id,
        MAX(
            CASE
                WHEN cpc_class_symbol LIKE 'E21B%'  -- oil & gas extraction
                  OR cpc_class_symbol LIKE 'C10G%' -- oil refining
                  OR cpc_class_symbol LIKE 'C10J%' -- coal-to-gas / gasification
                  OR cpc_class_symbol LIKE 'C10K%' -- gas conditioning
                  OR cpc_class_symbol LIKE 'F17D%' -- pipelines
                  OR cpc_class_symbol LIKE 'B63B%' -- tanker shipping
                THEN 1 ELSE 0
            END
        ) AS is_dirty
    FROM patstat.tls224_appln_cpc
    GROUP BY appln_id
)

SELECT
    ic.priority_year,
    ic.ctry_code,

    -- classical fractional patent count
    SUM(1.0 * ic.n_inv_ctry / it.n_inv) AS frac_classical_inv,

    -- fractional fossil ("dirty") innovation
    SUM(
        1.0 * ic.n_inv_ctry / it.n_inv
        * COALESCE(cd.is_dirty, 0)
    ) AS frac_dirty_innovation

FROM inv_ctry ic
JOIN inv_tot it
  ON it.appln_id       = ic.appln_id
 AND it.priority_year = ic.priority_year
LEFT JOIN cpc_dirty_flag cd
  ON cd.appln_id = ic.appln_id
GROUP BY
    ic.priority_year,
    ic.ctry_code;

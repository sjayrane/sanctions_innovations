CREATE TABLE pf_inv_ctry_year_frac_any_y AS
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

-- flags per application for each Y02 subgroup (and Y04S)
cpc_y_flags AS (
    SELECT
        appln_id,
        MAX(CASE WHEN cpc_class_symbol LIKE 'Y02%' THEN 1 ELSE 0 END) AS is_y02_any,

        MAX(CASE WHEN cpc_class_symbol LIKE 'Y02A%' THEN 1 ELSE 0 END) AS is_y02a,
        MAX(CASE WHEN cpc_class_symbol LIKE 'Y02B%' THEN 1 ELSE 0 END) AS is_y02b,
        MAX(CASE WHEN cpc_class_symbol LIKE 'Y02C%' THEN 1 ELSE 0 END) AS is_y02c,
        MAX(CASE WHEN cpc_class_symbol LIKE 'Y02D%' THEN 1 ELSE 0 END) AS is_y02d,
        MAX(CASE WHEN cpc_class_symbol LIKE 'Y02E%' THEN 1 ELSE 0 END) AS is_y02e,
        MAX(CASE WHEN cpc_class_symbol LIKE 'Y02P%' THEN 1 ELSE 0 END) AS is_y02p,
        MAX(CASE WHEN cpc_class_symbol LIKE 'Y02T%' THEN 1 ELSE 0 END) AS is_y02t,
        MAX(CASE WHEN cpc_class_symbol LIKE 'Y02W%' THEN 1 ELSE 0 END) AS is_y02w,
        MAX(CASE WHEN cpc_class_symbol LIKE 'Y04S%' THEN 1 ELSE 0 END) AS is_y04s
    FROM patstat.tls224_appln_cpc
    GROUP BY appln_id
)

SELECT
    ic.priority_year,
    ic.ctry_code,

    -- original total fractional patents
    SUM(1.0 * ic.n_inv_ctry / it.n_inv) AS frac_classical_inv,

    -- ANY Y02
    SUM(1.0 * ic.n_inv_ctry / it.n_inv * COALESCE(cf.is_y02_any, 0)) AS frac_y02_any,
    -- fractional sums per Y02 subgroup (and Y04S)
    SUM(1.0 * ic.n_inv_ctry / it.n_inv * COALESCE(cf.is_y02a, 0)) AS frac_y02a,
    SUM(1.0 * ic.n_inv_ctry / it.n_inv * COALESCE(cf.is_y02b, 0)) AS frac_y02b,
    SUM(1.0 * ic.n_inv_ctry / it.n_inv * COALESCE(cf.is_y02c, 0)) AS frac_y02c,
    SUM(1.0 * ic.n_inv_ctry / it.n_inv * COALESCE(cf.is_y02d, 0)) AS frac_y02d,
    SUM(1.0 * ic.n_inv_ctry / it.n_inv * COALESCE(cf.is_y02e, 0)) AS frac_y02e,
    SUM(1.0 * ic.n_inv_ctry / it.n_inv * COALESCE(cf.is_y02p, 0)) AS frac_y02p,
    SUM(1.0 * ic.n_inv_ctry / it.n_inv * COALESCE(cf.is_y02t, 0)) AS frac_y02t,
    SUM(1.0 * ic.n_inv_ctry / it.n_inv * COALESCE(cf.is_y02w, 0)) AS frac_y02w,
    SUM(1.0 * ic.n_inv_ctry / it.n_inv * COALESCE(cf.is_y04s, 0)) AS frac_y04s

FROM inv_ctry ic
JOIN inv_tot it
  ON it.appln_id      = ic.appln_id
 AND it.priority_year = ic.priority_year
LEFT JOIN cpc_y_flags cf
  ON cf.appln_id = ic.appln_id
GROUP BY
    ic.priority_year,
    ic.ctry_code;

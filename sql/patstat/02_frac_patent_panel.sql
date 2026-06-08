CREATE TABLE pf_inv_ctry_year_frac AS
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
inv_tot AS (
  SELECT
    appln_id,
    priority_year,
    COUNT(DISTINCT person_id) AS n_inv
  FROM base
  GROUP BY appln_id, priority_year
),
inv_ctry AS (
  SELECT
    appln_id,
    priority_year,
    ctry_code,
    COUNT(DISTINCT person_id) AS n_inv_ctry
  FROM base
  GROUP BY appln_id, priority_year, ctry_code
)
SELECT
  ic.priority_year,
  ic.ctry_code,
  SUM(1.0 * ic.n_inv_ctry / it.n_inv) AS frac_classical_inv
FROM inv_ctry ic
JOIN inv_tot it
  ON it.appln_id = ic.appln_id
 AND it.priority_year = ic.priority_year
GROUP BY
  ic.priority_year,
  ic.ctry_code;

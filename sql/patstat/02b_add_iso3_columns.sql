-- ALTER TABLE pf_inv_ctry_year_frac
-- ADD COLUMN iso3 CHAR(3),
-- ADD COLUMN country_name VARCHAR(100);

UPDATE pf_inv_ctry_year_frac a
SET
  iso3 = c.iso_alpha3,
  country_name = c.st3_name
FROM patstat.tls801_country c
WHERE a.ctry_code = c.ctry_code;

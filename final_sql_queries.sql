-- BUSN 32120 Final Project SQL Queries
-- Project: Chicago Food Inspection Analysis
-- These queries use the SQLite tables created in the final notebook:
-- inspections: cleaned Chicago Food Inspections records
-- census_zcta: Census ACS ZIP/ZCTA area-context data
-- food_with_census: SQL-joined analysis table created from inspections and census_zcta

-- Join Query 1: Inspection-level Census enrichment.
-- What it does: Joins each inspection record to Census ZIP/ZCTA area context.
-- How it works: Uses a LEFT JOIN from inspections to census_zcta on the standardized ZIP/ZCTA code.
-- Why it matters: This is the core integration step used to create the final analysis dataset.
-- Expected interpretation: Most valid Chicago ZIP codes should match to Census ZCTA context.
SELECT
    i.*,
    c.zcta_name,
    c.total_population,
    c.median_household_income,
    c.poverty_rate,
    c.bachelors_or_higher_rate,
    c.under_18_rate,
    c.age_65_plus_rate
FROM inspections AS i
LEFT JOIN census_zcta AS c
    ON i.zip = c.zip;

-- Join Query 1A: Match rate for the inspection-level Census join.
-- What it does: Counts matched and unmatched inspection rows after joining to Census context.
-- How it works: Performs the same LEFT JOIN as the main integration query and aggregates match flags.
-- Why it matters: ZIP/ZCTA joins are approximate, so the report needs to document join quality.
-- Expected interpretation: A high match rate supports using Census variables as area context.
SELECT
    COUNT(*) AS inspection_rows,
    SUM(CASE WHEN c.total_population IS NOT NULL THEN 1 ELSE 0 END) AS matched_rows,
    SUM(CASE WHEN c.total_population IS NULL THEN 1 ELSE 0 END) AS unmatched_rows,
    AVG(CASE WHEN c.total_population IS NOT NULL THEN 1.0 ELSE 0.0 END) AS match_rate
FROM inspections AS i
LEFT JOIN census_zcta AS c
    ON i.zip = c.zip;

-- Join Query 1B: Most common unmatched inspection ZIP codes.
-- What it does: Lists ZIP codes from inspections that do not match Census ZCTA context.
-- How it works: Uses a LEFT JOIN and keeps rows where the Census ZIP is null.
-- Why it matters: Unmatched ZIPs help explain any missing Census context in the final analysis table.
-- Expected interpretation: The output should be reviewed before interpreting ZIP/ZCTA patterns.
SELECT
    i.zip,
    COUNT(*) AS inspection_count
FROM inspections AS i
LEFT JOIN census_zcta AS c
    ON i.zip = c.zip
WHERE c.zip IS NULL
  AND i.zip IS NOT NULL
GROUP BY i.zip
ORDER BY inspection_count DESC
LIMIT 10;

-- Join Query 2: ZIP/ZCTA inspection summary with Census context.
-- What it does: Summarizes inspection outcomes by ZIP and attaches Census context to each ZIP.
-- How it works: First aggregates inspections by ZIP, then LEFT JOINs the ZIP summary to census_zcta.
-- Why it matters: This supports geographic EDA while keeping ZIP/ZCTA caveats explicit.
-- Expected interpretation: ZIPs with enough inspections can be compared by failure rate and area context.
WITH zip_inspection_summary AS (
    SELECT
        zip,
        COUNT(*) AS inspections,
        AVG(failed) AS fail_rate,
        AVG(violation_count) AS avg_violation_count
    FROM inspections
    WHERE zip IS NOT NULL
    GROUP BY zip
)
SELECT
    z.zip,
    c.zcta_name,
    z.inspections,
    z.fail_rate,
    z.avg_violation_count,
    c.total_population,
    c.median_household_income,
    c.poverty_rate,
    c.bachelors_or_higher_rate
FROM zip_inspection_summary AS z
LEFT JOIN census_zcta AS c
    ON z.zip = c.zip
WHERE z.inspections >= 100
ORDER BY z.fail_rate DESC;

-- Join Query 3: Facility type patterns within ZIP/ZCTA context.
-- What it does: Compares facility-type failure rates within ZIPs and attaches Census context.
-- How it works: Aggregates inspections by ZIP and facility type, then joins to census_zcta.
-- Why it matters: This connects consumer-facing facility categories to the area-context dataset.
-- Expected interpretation: The output highlights facility type and ZIP combinations with high observed failure rates.
WITH facility_zip_summary AS (
    SELECT
        zip,
        facility_type_grouped,
        COUNT(*) AS inspections,
        AVG(failed) AS fail_rate,
        AVG(violation_count) AS avg_violation_count
    FROM inspections
    WHERE zip IS NOT NULL
    GROUP BY zip, facility_type_grouped
)
SELECT
    f.zip,
    c.zcta_name,
    f.facility_type_grouped,
    f.inspections,
    f.fail_rate,
    f.avg_violation_count,
    c.median_household_income,
    c.poverty_rate
FROM facility_zip_summary AS f
LEFT JOIN census_zcta AS c
    ON f.zip = c.zip
WHERE f.inspections >= 30
ORDER BY f.fail_rate DESC;

-- Query 6: Final analysis dataset size and date range.
-- What it does: Checks the row count, distinct inspection count, and date range after SQL integration.
-- How it works: Aggregates the SQL-joined food_with_census table.
-- Why it matters: Confirms the final analysis dataset follows the fixed 2019-01-01 to 2026-04-30 scope.
-- Expected interpretation: The row count should match the fixed Dataset 1 cutoff used in the notebook.
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT inspection_id) AS distinct_inspections,
    MIN(inspection_date) AS first_inspection_date,
    MAX(inspection_date) AS last_inspection_date
FROM food_with_census;

-- Query 7: Inspection results distribution.
-- What it does: Counts inspection outcomes and calculates each outcome's share of all inspections.
-- How it works: Groups by results and uses a window total for the percentage.
-- Why it matters: Establishes the baseline distribution before comparing failure rates.
-- Expected interpretation: Pass is the most common outcome, while fail is a substantial minority.
SELECT
    results,
    COUNT(*) AS inspection_count,
    100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS percentage
FROM food_with_census
GROUP BY results
ORDER BY inspection_count DESC;

-- Query 8: Failure rate by risk level.
-- What it does: Compares inspection count, failure rate, and average violation count by risk category.
-- How it works: Groups the joined table by risk and aggregates failure and violation fields.
-- Why it matters: Risk level is known before inspection and is useful for pre-inspection comparisons.
-- Expected interpretation: Failure rates are similar across standard risk groups, but violation counts differ.
SELECT
    risk,
    COUNT(*) AS inspections,
    100.0 * AVG(failed) AS fail_rate,
    AVG(violation_count) AS avg_violation_count
FROM food_with_census
WHERE risk IS NOT NULL
GROUP BY risk
ORDER BY fail_rate DESC;

-- Query 9: Failure rate by facility type.
-- What it does: Compares observed failure rates across grouped facility types.
-- How it works: Groups by facility_type_grouped and aggregates count, failure rate, and violation count.
-- Why it matters: Facility type is easy for consumers to understand and varies more than broad risk level.
-- Expected interpretation: Some facility categories have higher observed failure rates than restaurants.
SELECT
    facility_type_grouped,
    COUNT(*) AS inspections,
    100.0 * AVG(failed) AS fail_rate,
    AVG(violation_count) AS avg_violation_count
FROM food_with_census
GROUP BY facility_type_grouped
ORDER BY fail_rate DESC;

-- Query 10: Failure rate by inspection type.
-- What it does: Compares failure risk across common inspection types.
-- How it works: Groups by inspection_type and keeps categories with at least 100 inspections.
-- Why it matters: Inspection type is one of the clearest EDA signals in the analysis.
-- Expected interpretation: Complaint-related inspections should have higher observed failure rates.
SELECT
    inspection_type,
    COUNT(*) AS inspections,
    100.0 * AVG(failed) AS fail_rate,
    AVG(violation_count) AS avg_violation_count
FROM food_with_census
GROUP BY inspection_type
HAVING COUNT(*) >= 100
ORDER BY fail_rate DESC;

-- Query 11: Monthly inspection volume and failure rate.
-- What it does: Summarizes inspections and failure rates by month.
-- How it works: Groups by the engineered month_year field from Dataset 1.
-- Why it matters: Shows whether failure risk moves with inspection volume over time.
-- Expected interpretation: Monthly volume and failure rate do not necessarily move together.
SELECT
    month_year,
    COUNT(*) AS inspections,
    100.0 * AVG(failed) AS fail_rate,
    AVG(violation_count) AS avg_violation_count
FROM food_with_census
GROUP BY month_year
ORDER BY month_year;

-- Query 12: Rank ZIP/ZCTA areas by observed failure rate.
-- What it does: Ranks ZIP/ZCTA areas with at least 100 inspections by failure rate.
-- How it works: Groups by ZIP/ZCTA and uses RANK() as a window function over failure rate.
-- Why it matters: Provides a transparent geographic ranking with a minimum sample threshold.
-- Expected interpretation: High-ranked ZIP/ZCTA areas need caveats because ZIP patterns are not causal.
WITH zip_summary AS (
    SELECT
        zip,
        zcta_name,
        COUNT(*) AS inspections,
        100.0 * AVG(failed) AS fail_rate,
        AVG(violation_count) AS avg_violation_count
    FROM food_with_census
    WHERE zip IS NOT NULL
    GROUP BY zip, zcta_name
    HAVING COUNT(*) >= 100
)
SELECT
    zip,
    zcta_name,
    inspections,
    fail_rate,
    avg_violation_count,
    RANK() OVER (ORDER BY fail_rate DESC) AS failure_rate_rank
FROM zip_summary
ORDER BY failure_rate_rank;

-- Query 13: Rank facility types within each inspection type.
-- What it does: Ranks facility categories by failure rate within each inspection type.
-- How it works: Groups by inspection_type and facility_type_grouped, then uses a partitioned RANK().
-- Why it matters: Facility patterns may differ depending on why an inspection occurred.
-- Expected interpretation: The highest-risk facility type can vary across complaint, canvass, and license inspections.
WITH inspection_facility_summary AS (
    SELECT
        inspection_type,
        facility_type_grouped,
        COUNT(*) AS inspections,
        100.0 * AVG(failed) AS fail_rate
    FROM food_with_census
    GROUP BY inspection_type, facility_type_grouped
    HAVING COUNT(*) >= 50
)
SELECT
    inspection_type,
    facility_type_grouped,
    inspections,
    fail_rate,
    RANK() OVER (
        PARTITION BY inspection_type
        ORDER BY fail_rate DESC
    ) AS rank_within_inspection_type
FROM inspection_facility_summary
ORDER BY inspection_type, rank_within_inspection_type;

-- Query 14: ZIP/ZCTA areas above the citywide failure rate.
-- What it does: Lists ZIP/ZCTA areas whose failure rates are above the citywide average.
-- How it works: Uses a scalar subquery to compare each ZIP/ZCTA failure rate with the overall rate.
-- Why it matters: Provides a benchmarked geographic comparison instead of only ranking raw rates.
-- Expected interpretation: Above-average ZIP/ZCTA areas need further explanation and should not be treated causally.
SELECT
    zip,
    zcta_name,
    COUNT(*) AS inspections,
    100.0 * AVG(failed) AS fail_rate
FROM food_with_census
WHERE zip IS NOT NULL
GROUP BY zip, zcta_name
HAVING COUNT(*) >= 100
   AND AVG(failed) > (
        SELECT AVG(failed)
        FROM food_with_census
   )
ORDER BY fail_rate DESC;

-- Query 15: Facility types above the citywide failure rate.
-- What it does: Lists facility type groups with failure rates above the full-dataset average.
-- How it works: Uses a scalar subquery for the citywide failure rate and compares each facility group to it.
-- Why it matters: Identifies facility categories that deserve more attention in the narrative.
-- Expected interpretation: Above-average categories may reflect regulation, facility mix, or inspection context.
SELECT
    facility_type_grouped,
    COUNT(*) AS inspections,
    100.0 * AVG(failed) AS fail_rate
FROM food_with_census
GROUP BY facility_type_grouped
HAVING COUNT(*) >= 100
   AND AVG(failed) > (
        SELECT AVG(failed)
        FROM food_with_census
   )
ORDER BY fail_rate DESC;

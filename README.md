# Chicago Food Inspection Final Project

This repository contains the BUSN 32120 final project analyzing food safety risk patterns in Chicago. The analysis uses Chicago Food Inspections as the anchor dataset and adds Census ACS ZIP/ZCTA context through the Census API.

## Research Question

Which facility types, risk levels, inspection types, and ZIP/ZCTA area contexts are associated with higher food-inspection failure risk in Chicago?

The target audience is Chicago consumers and public health stakeholders who want a clear, practical summary of where inspection risk appears higher and how to interpret those patterns carefully.

## Submission Files

- `final_food_inspection_analysis.ipynb`: Python notebook with data collection, cleaning, feature engineering, SQL integration, EDA, modeling, findings, limitations, and conclusion.
- `final_sql_queries.sql`: separate SQL-only file with commented queries for integration, validation, EDA, joins, window functions, and subqueries.
- `presentation.pdf`: PDF deck used for the in-class presentation.

## Data Sources

- Chicago Food Inspections API from the Chicago Data Portal.
- 2024 ACS 5-year Data Profile variables from the U.S. Census API.

The final analysis uses Chicago inspection records from `2019-01-01` through `2026-04-30`. The live API count for this fixed scope was 129,274 records when the final workflow was prepared.

## Running the Files

The notebook downloads both datasets through APIs and creates a local SQLite database during execution. The SQL file is designed to run after the notebook creates the required SQLite tables.

Recommended order:

1. Keep a local `.env` file in this folder with a Census API key:

```bash
CENSUS_API_KEY=your_key_here
```

2. Run `final_food_inspection_analysis.ipynb` from top to bottom. This creates `food_inspection_analysis.db` and the tables `inspections`, `census_zcta`, and `food_with_census`.

3. Run `final_sql_queries.sql` against the generated SQLite database.
# Sales Analytics SQL Project

Analyze sales data with **JOINs** and **pivot tables** (SQLite; the SQL ports to MySQL/PostgreSQL with minor changes).

## Files
| File | Purpose |
|---|---|
| `schema.sql` | 6 tables: regions, categories, customers, products, orders, order_items (+ indexes) |
| `generate_seed.py` | Creates `seed_data.sql` (40 customers, 12 products, 300 orders, Jan-Sep 2026) |
| `analysis.sql` | `v_sales` view (6-table join) + 9 reports |
| `run_project.py` | Builds `sales.db`, runs every report, prints it and saves `results/Q*.csv` |

## Run
```
python3 run_project.py
```
Or open `sales.db` in any SQLite client and run the queries in `analysis.sql`.

## Reports
- **Q1-Q2** INNER JOIN: revenue by category, top 5 customers
- **Q3-Q4** LEFT JOIN + IS NULL: customers with no orders, products never sold
- **Q5** Pivot: Region x Category revenue (with totals row)
- **Q6** Pivot: Month x Segment revenue
- **Q7** Pivot: Category x Quarter units sold
- **Q8-Q9** Window functions: month-over-month growth, best product per category

## How the pivot works
Most SQL engines have no universal PIVOT keyword, so we use conditional aggregation:
`SUM(CASE WHEN category_name = 'Electronics' THEN net_revenue ELSE 0 END) AS Electronics`
This works in SQLite, MySQL, PostgreSQL and SQL Server. Add a new column per new category value.

## Use your own data
Replace the INSERTs in `seed_data.sql` (or load CSVs into the same tables). Keep the table/column names and every query works unchanged.

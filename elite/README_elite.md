# Sales Analytics - ELITE Edition

Advanced SQL project (SQLite; portable to MySQL/PostgreSQL with minor changes) with a formatted Excel report.

## Run
```
pip install openpyxl
python3 run_elite.py
```
Builds `elite.db`, runs all 16 reports, prints a preview of each, and writes `sales_report_elite.xlsx`.

## What's new vs the basic version
- 9 tables: adds salespeople, monthly targets, returns, product cost; 21 months of data (Jan 2025 - Sep 2026)
- `v_sales` view joins 8 tables and calculates revenue, cost, profit and returned flag; `v_sales_kept` excludes returns
- Constraints (CHECK, UNIQUE, foreign keys) and indexes

## Reports (`analysis_elite.sql`)
| ID | Report | Technique |
|---|---|---|
| E1 | Executive KPIs | CTEs |
| E2 | YoY revenue by month | Pivot (CASE) |
| E3 | Region x Category | Pivot + totals row |
| E4 | Category x Quarter | Pivot, 7 columns |
| E5 | Running total + 3-month moving average | Window frames |
| E6 | Pareto / ABC products | Cumulative window |
| E7 | RFM customer segments | NTILE scoring |
| E8 | Cohort retention | Pivot over cohort age |
| E9 | Products bought together | Self-join |
| E10 | Salesperson vs target | Join of actuals and targets |
| E11 | Top customer per region | ROW_NUMBER |
| E12 | Channel x Year | Pivot + AOV |
| E13 | Returns by category | LEFT JOIN view |
| E14-E15 | Customers with no orders / products never sold | LEFT JOIN + IS NULL |
| E16 | Data-quality checks | UNION ALL audit |

## Excel report
Dashboard sheet with KPI tiles and links to each report, charts (YoY, trend vs moving average, stacked region/category), and heatmaps on the region/category pivot and cohort table.

## Own data
Replace the INSERTs in `seed_elite.sql` or load CSVs into the same tables; keep table and column names.

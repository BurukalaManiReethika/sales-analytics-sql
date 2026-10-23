# Sales Analytics with SQL

Analyze sales data using **JOINs**, **pivot tables** (conditional aggregation) and **window functions**.
Built on SQLite; the SQL ports to MySQL/PostgreSQL with minor changes.

| Folder | What it is |
|---|---|
| [`basic/`](basic) | Starter project: 6 tables, 9 reports (joins, pivots, window functions) |
| [`elite/`](elite) | Advanced edition: 9 tables, 16 reports (YoY, RFM, cohorts, Pareto, market basket, targets, data-quality checks) plus a formatted Excel report with charts |

## Quick start
```bash
git clone <your-repo-url>
cd sales-analytics-sql/elite
pip install openpyxl
python3 run_elite.py        # builds elite.db, prints reports, writes sales_report_elite.xlsx
```
For the starter project: `cd basic && python3 run_project.py`.

## Highlights (elite)
- `v_sales` view joining 8 tables with revenue, cost, profit and returned flag
- Pivots: Region x Category, Category x Quarter, YoY by month, Channel x Year, cohort retention
- Window functions: running totals, moving averages, ROW_NUMBER, NTILE-based RFM
- LEFT JOIN anti-joins, self-join market basket, and a data-quality audit

The sample data is randomly generated (fixed seed), so results demonstrate the queries rather than real business findings. To use your own data, load it into the same tables.

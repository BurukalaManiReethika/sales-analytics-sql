-- Sales Analytics ELITE: views + advanced reports
-- Net revenue = unit_price * quantity * (1 - discount_pct/100); returned items are excluded from "kept" reports.

------------------------------------------------------------------
-- VIEW 1: flat 8-table join (items, orders, customers, regions,
--         salespeople, products, categories, returns)
------------------------------------------------------------------
DROP VIEW IF EXISTS v_sales_kept;
DROP VIEW IF EXISTS v_sales;
CREATE VIEW v_sales AS
SELECT
    oi.order_item_id,
    o.order_id,
    o.order_date,
    strftime('%Y-%m', o.order_date) AS order_month,
    strftime('%Y', o.order_date)    AS yr,
    strftime('%Y', o.order_date) || '-Q' ||
        ((CAST(strftime('%m', o.order_date) AS INT) + 2) / 3) AS quarter_label,
    o.channel,
    c.customer_id,
    c.customer_name,
    c.segment,
    r.region_name,
    sp.sp_id,
    sp.sp_name,
    p.product_name,
    cat.category_name,
    oi.quantity,
    oi.discount_pct,
    ROUND(p.unit_price * oi.quantity * (1 - oi.discount_pct / 100.0), 2) AS net_revenue,
    ROUND(p.unit_cost * oi.quantity, 2) AS cost,
    ROUND(p.unit_price * oi.quantity * (1 - oi.discount_pct / 100.0)
          - p.unit_cost * oi.quantity, 2) AS profit,
    CASE WHEN rt.return_id IS NULL THEN 0 ELSE 1 END AS is_returned
FROM order_items oi
INNER JOIN orders      o   ON o.order_id      = oi.order_id
INNER JOIN customers   c   ON c.customer_id   = o.customer_id
INNER JOIN regions     r   ON r.region_id     = c.region_id
INNER JOIN salespeople sp  ON sp.sp_id        = o.sp_id
INNER JOIN products    p   ON p.product_id    = oi.product_id
INNER JOIN categories  cat ON cat.category_id = p.category_id
LEFT  JOIN returns     rt  ON rt.order_item_id = oi.order_item_id;

CREATE VIEW v_sales_kept AS
SELECT * FROM v_sales WHERE is_returned = 0;

------------------------------------------------------------------
-- E1. Executive KPIs
------------------------------------------------------------------
-- @E1 Executive KPIs
WITH k AS (
    SELECT SUM(net_revenue) AS rev, SUM(profit) AS profit,
           COUNT(DISTINCT order_id) AS orders, COUNT(DISTINCT customer_id) AS customers
    FROM v_sales_kept
), r AS (
    SELECT ROUND(100.0 * SUM(is_returned) / COUNT(*), 2) AS return_rate_pct FROM v_sales
)
SELECT ROUND(rev, 0)            AS net_revenue,
       ROUND(profit, 0)         AS gross_profit,
       ROUND(100.0 * profit / rev, 1) AS margin_pct,
       orders,
       customers                AS active_customers,
       ROUND(rev / orders, 0)   AS avg_order_value,
       return_rate_pct
FROM k, r;

------------------------------------------------------------------
-- E2. PIVOT: year-over-year by month (month rows x year columns)
------------------------------------------------------------------
-- @E2 Pivot: YoY revenue by month
WITH m AS (
    SELECT substr(order_month, 6, 2) AS mon,
           SUM(CASE WHEN yr = '2025' THEN net_revenue ELSE 0 END) AS r25,
           SUM(CASE WHEN yr = '2026' THEN net_revenue ELSE 0 END) AS r26
    FROM v_sales_kept
    GROUP BY mon
)
SELECT mon AS month,
       ROUND(r25, 0) AS rev_2025,
       ROUND(r26, 0) AS rev_2026,
       ROUND(100.0 * (r26 - r25) / r25, 1) AS yoy_pct
FROM m
WHERE mon <= (SELECT MAX(substr(order_month, 6, 2)) FROM v_sales_kept WHERE yr = '2026')
ORDER BY mon;

------------------------------------------------------------------
-- E3. PIVOT: region x category revenue with totals row
------------------------------------------------------------------
-- @E3 Pivot: Region x Category revenue
SELECT region_name,
       ROUND(SUM(CASE WHEN category_name = 'Electronics' THEN net_revenue ELSE 0 END), 0) AS Electronics,
       ROUND(SUM(CASE WHEN category_name = 'Furniture'   THEN net_revenue ELSE 0 END), 0) AS Furniture,
       ROUND(SUM(CASE WHEN category_name = 'Stationery'  THEN net_revenue ELSE 0 END), 0) AS Stationery,
       ROUND(SUM(CASE WHEN category_name = 'Clothing'    THEN net_revenue ELSE 0 END), 0) AS Clothing,
       ROUND(SUM(net_revenue), 0) AS Total
FROM v_sales_kept
GROUP BY region_name
UNION ALL
SELECT 'TOTAL',
       ROUND(SUM(CASE WHEN category_name = 'Electronics' THEN net_revenue ELSE 0 END), 0),
       ROUND(SUM(CASE WHEN category_name = 'Furniture'   THEN net_revenue ELSE 0 END), 0),
       ROUND(SUM(CASE WHEN category_name = 'Stationery'  THEN net_revenue ELSE 0 END), 0),
       ROUND(SUM(CASE WHEN category_name = 'Clothing'    THEN net_revenue ELSE 0 END), 0),
       ROUND(SUM(net_revenue), 0)
FROM v_sales_kept;

------------------------------------------------------------------
-- E4. PIVOT: category x quarter revenue (7 quarters as columns)
------------------------------------------------------------------
-- @E4 Pivot: Category x Quarter revenue
SELECT category_name,
       ROUND(SUM(CASE WHEN quarter_label = '2025-Q1' THEN net_revenue ELSE 0 END), 0) AS Q1_2025,
       ROUND(SUM(CASE WHEN quarter_label = '2025-Q2' THEN net_revenue ELSE 0 END), 0) AS Q2_2025,
       ROUND(SUM(CASE WHEN quarter_label = '2025-Q3' THEN net_revenue ELSE 0 END), 0) AS Q3_2025,
       ROUND(SUM(CASE WHEN quarter_label = '2025-Q4' THEN net_revenue ELSE 0 END), 0) AS Q4_2025,
       ROUND(SUM(CASE WHEN quarter_label = '2026-Q1' THEN net_revenue ELSE 0 END), 0) AS Q1_2026,
       ROUND(SUM(CASE WHEN quarter_label = '2026-Q2' THEN net_revenue ELSE 0 END), 0) AS Q2_2026,
       ROUND(SUM(CASE WHEN quarter_label = '2026-Q3' THEN net_revenue ELSE 0 END), 0) AS Q3_2026,
       ROUND(SUM(net_revenue), 0) AS Total
FROM v_sales_kept
GROUP BY category_name
ORDER BY Total DESC;

------------------------------------------------------------------
-- E5. Window functions: running total + 3-month moving average
------------------------------------------------------------------
-- @E5 Running total and 3-month moving average
WITH monthly AS (
    SELECT order_month, SUM(net_revenue) AS revenue
    FROM v_sales_kept
    GROUP BY order_month
)
SELECT order_month,
       ROUND(revenue, 0) AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY order_month ROWS UNBOUNDED PRECEDING), 0) AS cumulative_revenue,
       ROUND(AVG(revenue) OVER (ORDER BY order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS moving_avg_3m
FROM monthly
ORDER BY order_month;

------------------------------------------------------------------
-- E6. Pareto / ABC analysis of products
------------------------------------------------------------------
-- @E6 Pareto ABC product analysis
WITH p AS (
    SELECT product_name, SUM(net_revenue) AS rev
    FROM v_sales_kept
    GROUP BY product_name
), t AS (
    SELECT product_name, rev,
           SUM(rev) OVER (ORDER BY rev DESC ROWS UNBOUNDED PRECEDING) AS cum,
           SUM(rev) OVER () AS total
    FROM p
)
SELECT product_name,
       ROUND(rev, 0) AS revenue,
       ROUND(100.0 * rev / total, 1) AS share_pct,
       ROUND(100.0 * cum / total, 1) AS cum_share_pct,
       CASE WHEN 100.0 * (cum - rev) / total < 80 THEN 'A'
            WHEN 100.0 * (cum - rev) / total < 95 THEN 'B'
            ELSE 'C' END AS abc_class
FROM t
ORDER BY rev DESC;

------------------------------------------------------------------
-- E7. RFM customer segmentation (as of 2026-09-30)
------------------------------------------------------------------
-- @E7 RFM customer segments
WITH base AS (
    SELECT customer_id,
           CAST(julianday('2026-09-30') - julianday(MAX(order_date)) AS INT) AS recency,
           COUNT(DISTINCT order_id) AS frequency,
           SUM(net_revenue) AS monetary
    FROM v_sales_kept
    GROUP BY customer_id
), scored AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY recency DESC) AS r,
           NTILE(4) OVER (ORDER BY frequency)    AS f,
           NTILE(4) OVER (ORDER BY monetary)     AS m
    FROM base
), seg AS (
    SELECT *,
           CASE WHEN r >= 3 AND f >= 3 AND m >= 3 THEN 'Champions'
                WHEN r >= 3 AND f >= 2             THEN 'Loyal'
                WHEN r >= 3                        THEN 'Promising'
                WHEN r <= 2 AND m >= 3             THEN 'At Risk (high value)'
                WHEN r = 1                         THEN 'Lost'
                ELSE 'Needs Attention' END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*) AS customers,
       ROUND(AVG(recency), 0) AS avg_recency_days,
       ROUND(AVG(frequency), 1) AS avg_orders,
       ROUND(SUM(monetary), 0) AS revenue
FROM seg
GROUP BY segment
ORDER BY revenue DESC;

------------------------------------------------------------------
-- E8. Cohort retention pivot (first-order month x months since)
------------------------------------------------------------------
-- @E8 Cohort retention (active customers)
WITH first AS (
    SELECT customer_id, MIN(order_month) AS cohort
    FROM v_sales_kept
    GROUP BY customer_id
), act AS (
    SELECT DISTINCT customer_id, order_month FROM v_sales_kept
), j AS (
    SELECT f.cohort, a.customer_id,
           (CAST(substr(a.order_month, 1, 4) AS INT) - CAST(substr(f.cohort, 1, 4) AS INT)) * 12
           + CAST(substr(a.order_month, 6, 2) AS INT) - CAST(substr(f.cohort, 6, 2) AS INT) AS m
    FROM first f
    JOIN act a ON a.customer_id = f.customer_id
)
SELECT cohort,
       COUNT(DISTINCT CASE WHEN m = 0 THEN customer_id END) AS month_0,
       COUNT(DISTINCT CASE WHEN m = 1 THEN customer_id END) AS month_1,
       COUNT(DISTINCT CASE WHEN m = 2 THEN customer_id END) AS month_2,
       COUNT(DISTINCT CASE WHEN m = 3 THEN customer_id END) AS month_3,
       COUNT(DISTINCT CASE WHEN m = 4 THEN customer_id END) AS month_4,
       COUNT(DISTINCT CASE WHEN m = 5 THEN customer_id END) AS month_5
FROM j
GROUP BY cohort
ORDER BY cohort;

------------------------------------------------------------------
-- E9. Market basket: products most often bought together (self-join)
------------------------------------------------------------------
-- @E9 Market basket: top product pairs
WITH items AS (
    SELECT DISTINCT order_id, product_name FROM v_sales_kept
)
SELECT a.product_name AS product_1,
       b.product_name AS product_2,
       COUNT(*)       AS orders_together
FROM items a
JOIN items b ON a.order_id = b.order_id AND a.product_name < b.product_name
GROUP BY a.product_name, b.product_name
ORDER BY orders_together DESC, product_1, product_2
LIMIT 10;

------------------------------------------------------------------
-- E10. Salesperson attainment vs target (2026 YTD)
------------------------------------------------------------------
-- @E10 Salesperson attainment vs target (2026)
WITH act AS (
    SELECT sp_id, sp_name, SUM(net_revenue) AS revenue
    FROM v_sales_kept
    WHERE yr = '2026'
    GROUP BY sp_id, sp_name
), tgt AS (
    SELECT sp_id, SUM(target_amount) AS target
    FROM sales_targets
    WHERE substr(month, 1, 4) = '2026'
    GROUP BY sp_id
)
SELECT a.sp_name AS salesperson,
       ROUND(a.revenue, 0) AS revenue,
       ROUND(t.target, 0)  AS target,
       ROUND(100.0 * a.revenue / t.target, 1) AS attainment_pct,
       CASE WHEN a.revenue >= t.target        THEN 'On/above target'
            WHEN a.revenue >= 0.85 * t.target THEN 'Close'
            ELSE 'Below target' END AS status
FROM act a
JOIN tgt t ON t.sp_id = a.sp_id
ORDER BY attainment_pct DESC;

------------------------------------------------------------------
-- E11. Top customer in each region (ROW_NUMBER)
------------------------------------------------------------------
-- @E11 Top customer per region
WITH c AS (
    SELECT region_name, customer_id, customer_name, segment,
           SUM(net_revenue) AS revenue,
           ROW_NUMBER() OVER (PARTITION BY region_name ORDER BY SUM(net_revenue) DESC) AS rn
    FROM v_sales_kept
    GROUP BY region_name, customer_id, customer_name, segment
)
SELECT region_name, customer_id, customer_name, segment, ROUND(revenue, 0) AS revenue
FROM c
WHERE rn = 1
ORDER BY revenue DESC;

------------------------------------------------------------------
-- E12. Channel x year pivot with average order value
------------------------------------------------------------------
-- @E12 Pivot: Channel x Year
SELECT channel,
       COUNT(DISTINCT CASE WHEN yr = '2025' THEN order_id END) AS orders_2025,
       COUNT(DISTINCT CASE WHEN yr = '2026' THEN order_id END) AS orders_2026,
       ROUND(SUM(CASE WHEN yr = '2025' THEN net_revenue ELSE 0 END), 0) AS rev_2025,
       ROUND(SUM(CASE WHEN yr = '2026' THEN net_revenue ELSE 0 END), 0) AS rev_2026,
       ROUND(SUM(net_revenue) / COUNT(DISTINCT order_id), 0) AS avg_order_value
FROM v_sales_kept
GROUP BY channel
ORDER BY rev_2026 DESC;

------------------------------------------------------------------
-- E13. Returns analysis by category (LEFT JOIN-based view)
------------------------------------------------------------------
-- @E13 Returns by category
SELECT category_name,
       COUNT(*)                AS items_sold,
       SUM(is_returned)        AS items_returned,
       ROUND(100.0 * SUM(is_returned) / COUNT(*), 1) AS return_rate_pct,
       ROUND(SUM(CASE WHEN is_returned = 1 THEN net_revenue ELSE 0 END), 0) AS revenue_lost
FROM v_sales
GROUP BY category_name
ORDER BY revenue_lost DESC;

------------------------------------------------------------------
-- E14. LEFT JOIN: customers who never ordered
------------------------------------------------------------------
-- @E14 Customers with no orders (LEFT JOIN + IS NULL)
SELECT c.customer_id, c.customer_name, c.segment, r.region_name, c.signup_date
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
INNER JOIN regions r ON r.region_id = c.region_id
WHERE o.order_id IS NULL
ORDER BY c.customer_id;

------------------------------------------------------------------
-- E15. LEFT JOIN: products that never sold
------------------------------------------------------------------
-- @E15 Products never sold (LEFT JOIN + IS NULL)
SELECT p.product_id, p.product_name, cat.category_name, p.unit_price
FROM products p
INNER JOIN categories cat ON cat.category_id = p.category_id
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE oi.order_item_id IS NULL;

------------------------------------------------------------------
-- E16. Data-quality checks (every row should show 0 problems)
------------------------------------------------------------------
-- @E16 Data quality checks
SELECT 'order_items without an order' AS check_name, COUNT(*) AS problems
FROM order_items oi LEFT JOIN orders o ON o.order_id = oi.order_id WHERE o.order_id IS NULL
UNION ALL
SELECT 'orders without a customer', COUNT(*)
FROM orders o LEFT JOIN customers c ON c.customer_id = o.customer_id WHERE c.customer_id IS NULL
UNION ALL
SELECT 'orders before customer signup', COUNT(*)
FROM orders o JOIN customers c ON c.customer_id = o.customer_id WHERE o.order_date < c.signup_date
UNION ALL
SELECT 'returns before order date', COUNT(*)
FROM returns rt
JOIN order_items oi ON oi.order_item_id = rt.order_item_id
JOIN orders o ON o.order_id = oi.order_id
WHERE rt.return_date < o.order_date
UNION ALL
SELECT 'items priced below cost', COUNT(*) FROM v_sales WHERE profit < 0
UNION ALL
SELECT 'view rows vs order_items mismatch',
       ABS((SELECT COUNT(*) FROM v_sales) - (SELECT COUNT(*) FROM order_items));

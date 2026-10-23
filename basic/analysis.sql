-- Sales Analytics Project: analysis queries
-- Net revenue = unit_price * quantity * (1 - discount_pct/100)

------------------------------------------------------------------
-- A reusable view that joins all 6 tables into one flat sales table
------------------------------------------------------------------
DROP VIEW IF EXISTS v_sales;
CREATE VIEW v_sales AS
SELECT
    oi.order_item_id,
    o.order_id,
    o.order_date,
    strftime('%Y-%m', o.order_date)                         AS order_month,
    CASE
        WHEN CAST(strftime('%m', o.order_date) AS INT) <= 3 THEN 'Q1'
        WHEN CAST(strftime('%m', o.order_date) AS INT) <= 6 THEN 'Q2'
        ELSE 'Q3'
    END                                                     AS quarter,
    c.customer_id,
    c.customer_name,
    c.segment,
    r.region_name,
    p.product_name,
    cat.category_name,
    oi.quantity,
    oi.discount_pct,
    ROUND(p.unit_price * oi.quantity * (1 - oi.discount_pct / 100.0), 2) AS net_revenue
FROM order_items oi
INNER JOIN orders     o   ON o.order_id     = oi.order_id
INNER JOIN customers  c   ON c.customer_id  = o.customer_id
INNER JOIN regions    r   ON r.region_id    = c.region_id
INNER JOIN products   p   ON p.product_id   = oi.product_id
INNER JOIN categories cat ON cat.category_id = p.category_id;

------------------------------------------------------------------
-- Q1. INNER JOIN: revenue by category
------------------------------------------------------------------
-- @Q1 Revenue by category
SELECT category_name,
       COUNT(DISTINCT order_id) AS orders,
       SUM(quantity)            AS units_sold,
       ROUND(SUM(net_revenue),2) AS revenue
FROM v_sales
GROUP BY category_name
ORDER BY revenue DESC;

------------------------------------------------------------------
-- Q2. INNER JOIN: top 5 customers by revenue
------------------------------------------------------------------
-- @Q2 Top 5 customers
SELECT customer_id, customer_name, segment, region_name,
       ROUND(SUM(net_revenue),2) AS revenue
FROM v_sales
GROUP BY customer_id, customer_name, segment, region_name
ORDER BY revenue DESC
LIMIT 5;

------------------------------------------------------------------
-- Q3. LEFT JOIN: customers who never placed an order
------------------------------------------------------------------
-- @Q3 Customers with no orders (LEFT JOIN + IS NULL)
SELECT c.customer_id, c.customer_name, r.region_name
FROM customers c
LEFT JOIN orders  o ON o.customer_id = c.customer_id
INNER JOIN regions r ON r.region_id  = c.region_id
WHERE o.order_id IS NULL;

------------------------------------------------------------------
-- Q4. LEFT JOIN: products that never sold
------------------------------------------------------------------
-- @Q4 Products never sold (LEFT JOIN + IS NULL)
SELECT p.product_id, p.product_name
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE oi.order_item_id IS NULL;

------------------------------------------------------------------
-- Q5. PIVOT: revenue by region (rows) x category (columns)
--     SQL has no universal PIVOT keyword; conditional aggregation
--     (SUM + CASE) works in SQLite, MySQL, PostgreSQL, SQL Server.
------------------------------------------------------------------
-- @Q5 Pivot: Region x Category revenue
SELECT region_name,
       ROUND(SUM(CASE WHEN category_name = 'Electronics' THEN net_revenue ELSE 0 END),0) AS Electronics,
       ROUND(SUM(CASE WHEN category_name = 'Furniture'   THEN net_revenue ELSE 0 END),0) AS Furniture,
       ROUND(SUM(CASE WHEN category_name = 'Stationery'  THEN net_revenue ELSE 0 END),0) AS Stationery,
       ROUND(SUM(CASE WHEN category_name = 'Clothing'    THEN net_revenue ELSE 0 END),0) AS Clothing,
       ROUND(SUM(net_revenue),0) AS Total
FROM v_sales
GROUP BY region_name
UNION ALL
SELECT 'TOTAL',
       ROUND(SUM(CASE WHEN category_name = 'Electronics' THEN net_revenue ELSE 0 END),0),
       ROUND(SUM(CASE WHEN category_name = 'Furniture'   THEN net_revenue ELSE 0 END),0),
       ROUND(SUM(CASE WHEN category_name = 'Stationery'  THEN net_revenue ELSE 0 END),0),
       ROUND(SUM(CASE WHEN category_name = 'Clothing'    THEN net_revenue ELSE 0 END),0),
       ROUND(SUM(net_revenue),0)
FROM v_sales;

------------------------------------------------------------------
-- Q6. PIVOT: monthly revenue (rows) x customer segment (columns)
------------------------------------------------------------------
-- @Q6 Pivot: Month x Segment revenue
SELECT order_month,
       ROUND(SUM(CASE WHEN segment = 'Retail'    THEN net_revenue ELSE 0 END),0) AS Retail,
       ROUND(SUM(CASE WHEN segment = 'Corporate' THEN net_revenue ELSE 0 END),0) AS Corporate,
       ROUND(SUM(CASE WHEN segment = 'Online'    THEN net_revenue ELSE 0 END),0) AS Online,
       ROUND(SUM(net_revenue),0) AS Total
FROM v_sales
GROUP BY order_month
ORDER BY order_month;

------------------------------------------------------------------
-- Q7. PIVOT: quarterly units sold by category
------------------------------------------------------------------
-- @Q7 Pivot: Category x Quarter units sold
SELECT category_name,
       SUM(CASE WHEN quarter = 'Q1' THEN quantity ELSE 0 END) AS Q1,
       SUM(CASE WHEN quarter = 'Q2' THEN quantity ELSE 0 END) AS Q2,
       SUM(CASE WHEN quarter = 'Q3' THEN quantity ELSE 0 END) AS Q3,
       SUM(quantity) AS Total_Units
FROM v_sales
GROUP BY category_name
ORDER BY Total_Units DESC;

------------------------------------------------------------------
-- Q8. Window function + join: month-over-month revenue growth
------------------------------------------------------------------
-- @Q8 Month-over-month growth
WITH monthly AS (
    SELECT order_month, SUM(net_revenue) AS revenue
    FROM v_sales GROUP BY order_month
)
SELECT order_month,
       ROUND(revenue,0) AS revenue,
       ROUND(LAG(revenue) OVER (ORDER BY order_month),0) AS prev_month,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
             / LAG(revenue) OVER (ORDER BY order_month), 1) AS growth_pct
FROM monthly
ORDER BY order_month;

------------------------------------------------------------------
-- Q9. Rank products within each category (window function)
------------------------------------------------------------------
-- @Q9 Best product per category
SELECT * FROM (
    SELECT category_name, product_name,
           ROUND(SUM(net_revenue),0) AS revenue,
           RANK() OVER (PARTITION BY category_name ORDER BY SUM(net_revenue) DESC) AS rnk
    FROM v_sales
    GROUP BY category_name, product_name
)
WHERE rnk = 1
ORDER BY revenue DESC;

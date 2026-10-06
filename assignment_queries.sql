/* =====================================================================
   SQL ASSIGNMENT: CUSTOMER ORDER ANALYSIS
   Database : customer_orders.db  (SQLite; built from Customer_Order_Data.numbers)
   Data     : 200 orders, 2024-12-24 to 2025-06-24, 4 regions, 4 categories

   TABLES
     categories(category_id, category_name)
     subcategories(subcategory_id, subcategory_name, category_id)
     products(product_id, product_name, subcategory_id)
     customers(customer_id, customer_name, region)
     orders(order_id, customer_id, product_id, order_date, quantity,
            unit_price, total_price)
     order_details   <- VIEW joining all five tables, one row per order

   NOTE: in this dataset every customer placed exactly ONE order, so
   "total spend per customer" equals that customer's single order value.
   The queries are still written the general way (GROUP BY customer), so
   they keep working if repeat customers are added later.

   Run it:  sqlite3 customer_orders.db < assignment_queries.sql
   ===================================================================== */

.headers on
.mode column


/* ---------------------------------------------------------------------
   1. SELECT BASICS
   --------------------------------------------------------------------- */

-- Q1. Look at the raw orders table (first 10 rows)
SELECT * FROM orders LIMIT 10;

-- Q2. Pick specific columns and rename them with aliases
SELECT customer_name AS customer, region AS sales_region
FROM customers
LIMIT 10;

-- Q3. DISTINCT: which regions exist?
SELECT DISTINCT region FROM customers ORDER BY region;

-- Q4. Calculated column: recompute the total and compare with the stored one
SELECT order_id, quantity, unit_price,
       quantity * unit_price AS calculated_total,
       total_price           AS stored_total
FROM orders
LIMIT 5;


/* ---------------------------------------------------------------------
   2. WHERE (filtering)
   --------------------------------------------------------------------- */

-- Q5. Comparison operator: high-value orders
SELECT order_id, order_date, quantity, total_price
FROM orders
WHERE total_price > 40000;

-- Q6. BETWEEN on dates: all Q1 2025 orders over 20,000
SELECT order_id, order_date, total_price
FROM orders
WHERE order_date BETWEEN '2025-01-01' AND '2025-03-31'
  AND total_price > 20000;

-- Q7. IN + LIKE + OR: customers in North/East whose name starts with 'A'
SELECT customer_name, region
FROM customers
WHERE region IN ('North', 'East')
  AND customer_name LIKE 'A%';


/* ---------------------------------------------------------------------
   3. ORDER BY (sorting)
   --------------------------------------------------------------------- */

-- Q8. Ten largest orders
SELECT order_id, customer_id, order_date, total_price
FROM orders
ORDER BY total_price DESC
LIMIT 10;

-- Q9. Sort by two columns: earliest orders first, biggest first within a day
SELECT order_id, order_date, total_price
FROM orders
ORDER BY order_date ASC, total_price DESC
LIMIT 10;


/* ---------------------------------------------------------------------
   4. AGGREGATIONS: COUNT, SUM, AVG (plus MIN / MAX)
   --------------------------------------------------------------------- */

-- Q10. Whole-business summary in one row
SELECT COUNT(*)                    AS total_orders,
       COUNT(DISTINCT customer_id) AS unique_customers,
       SUM(quantity)               AS units_sold,
       SUM(total_price)            AS total_revenue,
       ROUND(AVG(total_price), 2)  AS avg_order_value,
       MIN(total_price)            AS smallest_order,
       MAX(total_price)            AS largest_order
FROM orders;


/* ---------------------------------------------------------------------
   5. GROUP BY and HAVING
   --------------------------------------------------------------------- */

-- Q11. Orders, revenue and average order value by region
SELECT region,
       COUNT(*)                   AS orders,
       SUM(total_price)           AS revenue,
       ROUND(AVG(total_price), 2) AS avg_order_value
FROM order_details
GROUP BY region
ORDER BY revenue DESC;

-- Q12. Same idea by category
SELECT category,
       COUNT(*)                   AS orders,
       SUM(total_price)           AS revenue,
       ROUND(AVG(total_price), 2) AS avg_order_value
FROM order_details
GROUP BY category
ORDER BY revenue DESC;

-- Q13. Monthly trend (strftime extracts year-month from the ISO date)
SELECT strftime('%Y-%m', order_date) AS month,
       COUNT(*)                      AS orders,
       SUM(total_price)              AS revenue
FROM orders
GROUP BY month
ORDER BY month;

-- Q14. HAVING filters AFTER grouping: sub-categories with revenue > 150,000
--      (WHERE filters rows before grouping; HAVING filters the groups)
SELECT sub_category,
       COUNT(*)         AS orders,
       SUM(total_price) AS revenue
FROM order_details
GROUP BY sub_category
HAVING SUM(total_price) > 150000
ORDER BY revenue DESC;


/* ---------------------------------------------------------------------
   6. JOINS
   --------------------------------------------------------------------- */

-- Q15. INNER JOIN (3 tables): who bought what
SELECT o.order_id, c.customer_name, p.product_name, o.total_price
FROM orders o
INNER JOIN customers c ON c.customer_id = o.customer_id
INNER JOIN products  p ON p.product_id  = o.product_id
ORDER BY o.total_price DESC
LIMIT 10;

-- Q16. Chain of joins up the product hierarchy:
--      order -> product -> sub-category -> category
SELECT o.order_id, p.product_name, s.subcategory_name, cat.category_name,
       o.total_price
FROM orders o
JOIN products      p   ON p.product_id     = o.product_id
JOIN subcategories s   ON s.subcategory_id = p.subcategory_id
JOIN categories    cat ON cat.category_id  = s.category_id
LIMIT 10;

-- Q17. LEFT JOIN: keep every sub-category, even ones with no June 2025 orders.
--      The date test goes in the ON clause so unmatched rows are kept (count = 0).
SELECT s.subcategory_name,
       COUNT(o.order_id) AS june_2025_orders
FROM subcategories s
LEFT JOIN products p ON p.subcategory_id = s.subcategory_id
LEFT JOIN orders   o ON o.product_id     = p.product_id
                    AND o.order_date    >= '2025-06-01'
GROUP BY s.subcategory_name
ORDER BY june_2025_orders ASC, s.subcategory_name;

-- Q18. LEFT JOIN anti-join: customers who have NOT placed an order.
--      Expected: 0 rows here (a useful data-integrity check).
SELECT c.customer_id, c.customer_name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;


/* ---------------------------------------------------------------------
   7. SUBQUERIES
   --------------------------------------------------------------------- */

-- Q19. Scalar subquery: orders larger than the overall average order
SELECT order_id, order_date, total_price
FROM orders
WHERE total_price > (SELECT AVG(total_price) FROM orders)
ORDER BY total_price DESC
LIMIT 10;

-- Q20. IN subquery: customers who bought anything in Electronics
SELECT customer_id, customer_name
FROM customers
WHERE customer_id IN (SELECT customer_id
                      FROM order_details
                      WHERE category = 'Electronics')
ORDER BY customer_name
LIMIT 10;

-- Q21. Correlated subquery: orders above the average of THEIR OWN category
--      (the inner query re-runs for each outer row, using d.category)
SELECT d.order_id, d.customer_name, d.category, d.total_price
FROM order_details d
WHERE d.total_price > (SELECT AVG(x.total_price)
                       FROM order_details x
                       WHERE x.category = d.category)
ORDER BY d.total_price DESC
LIMIT 10;

-- Q22. Subquery in FROM (derived table): average revenue per region
SELECT ROUND(AVG(region_revenue), 2) AS avg_revenue_per_region
FROM (SELECT region, SUM(total_price) AS region_revenue
      FROM order_details
      GROUP BY region) AS regional;


/* ---------------------------------------------------------------------
   8. CASE STATEMENTS
   --------------------------------------------------------------------- */

-- Q23. Bucket orders into size bands, then summarise each band
SELECT order_size,
       COUNT(*)         AS orders,
       SUM(total_price) AS revenue
FROM (SELECT total_price,
             CASE WHEN total_price >= 30000 THEN 'Large  (30k+)'
                  WHEN total_price >= 10000 THEN 'Medium (10k-30k)'
                  ELSE                           'Small  (<10k)'
             END AS order_size
      FROM orders) AS banded
GROUP BY order_size
ORDER BY revenue DESC;

-- Q24. Conditional aggregation (a "pivot"): revenue per category split by region
SELECT category,
       SUM(CASE WHEN region = 'North' THEN total_price ELSE 0 END) AS north,
       SUM(CASE WHEN region = 'South' THEN total_price ELSE 0 END) AS south,
       SUM(CASE WHEN region = 'East'  THEN total_price ELSE 0 END) AS east,
       SUM(CASE WHEN region = 'West'  THEN total_price ELSE 0 END) AS west,
       SUM(total_price)                                            AS total
FROM order_details
GROUP BY category
ORDER BY total DESC;


/* =====================================================================
   9. ASSIGNMENT: TOP CUSTOMERS AND AVERAGE ORDER VALUES
   ===================================================================== */

-- A1. Top 10 customers by total spend
--     (customer_name is the tie-breaker so the ranking is repeatable)
SELECT c.customer_id,
       c.customer_name,
       c.region,
       COUNT(o.order_id)          AS orders,
       SUM(o.total_price)         AS total_spent,
       ROUND(AVG(o.total_price),2) AS avg_order_value
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name, c.region
ORDER BY total_spent DESC, c.customer_name
LIMIT 10;

-- A2. Top customer in EACH region
--     (CTE = a named subquery; the correlated subquery finds each region's max)
WITH customer_spend AS (
    SELECT c.customer_id, c.customer_name, c.region,
           SUM(o.total_price) AS total_spent
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.region
)
SELECT cs.region, cs.customer_name, cs.total_spent
FROM customer_spend cs
WHERE cs.total_spent = (SELECT MAX(x.total_spent)
                        FROM customer_spend x
                        WHERE x.region = cs.region)
ORDER BY cs.region;

-- A3. Overall average order value (AOV = total revenue / number of orders)
--     Exact value is 12,100.535. SQLite's ROUND() shows 12100.53 because half-cents
--     are subject to binary floating-point representation (round-half-up gives 12,100.54).
SELECT ROUND(SUM(total_price) * 1.0 / COUNT(*), 2) AS avg_order_value
FROM orders;

-- A4. Average order value by category (highest first)
SELECT category,
       COUNT(*)                   AS orders,
       ROUND(AVG(total_price), 2) AS avg_order_value
FROM order_details
GROUP BY category
ORDER BY avg_order_value DESC;

-- A5. Average order value by region (highest first)
SELECT region,
       COUNT(*)                   AS orders,
       ROUND(AVG(total_price), 2) AS avg_order_value
FROM order_details
GROUP BY region
ORDER BY avg_order_value DESC;

-- A6. Average order value by month (the first month, Dec 2024, is only 3 days of data)
SELECT strftime('%Y-%m', order_date)  AS month,
       COUNT(*)                       AS orders,
       ROUND(AVG(total_price), 2)     AS avg_order_value
FROM orders
GROUP BY month
ORDER BY month;

-- A7. Everything together: top 10 customers vs the overall average,
--     with a CASE label (scalar subquery gives the overall AOV)
SELECT c.customer_name,
       c.region,
       SUM(o.total_price) AS total_spent,
       ROUND(100.0 * (SUM(o.total_price) - (SELECT AVG(total_price) FROM orders))
                   / (SELECT AVG(total_price) FROM orders), 1) AS pct_vs_avg_order,
       CASE WHEN SUM(o.total_price) >= 3 * (SELECT AVG(total_price) FROM orders) THEN 'VIP (3x+ average)'
            WHEN SUM(o.total_price) >= 2 * (SELECT AVG(total_price) FROM orders) THEN 'High value (2x+)'
            ELSE 'Above average'
       END AS customer_tier
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name, c.region
ORDER BY total_spent DESC, c.customer_name
LIMIT 10;

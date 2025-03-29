-- Purpose: Analyze customer purchasing patterns and product performance

-- 1. Sales by Category with Growth Rate Analysis
WITH monthly_sales AS (
    SELECT 
        p.category_id,
        c.category_name,
        DATE_TRUNC('month', o.order_date) AS month,
        SUM(oi.quantity * oi.unit_price) AS total_sales
    FROM 
        orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        JOIN products p ON oi.product_id = p.product_id
        JOIN categories c ON p.category_id = c.category_id
    WHERE 
        o.order_date BETWEEN DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months') 
        AND CURRENT_DATE
    GROUP BY 
        p.category_id, c.category_name, DATE_TRUNC('month', o.order_date)
),
category_growth AS (
    SELECT 
        category_id,
        category_name,
        month,
        total_sales,
        LAG(total_sales) OVER (PARTITION BY category_id ORDER BY month) AS prev_month_sales,
        (total_sales - LAG(total_sales) OVER (PARTITION BY category_id ORDER BY month)) / 
            NULLIF(LAG(total_sales) OVER (PARTITION BY category_id ORDER BY month), 0) * 100 AS growth_rate
    FROM 
        monthly_sales
)
SELECT 
    category_name,
    TO_CHAR(month, 'YYYY-MM') AS month,
    ROUND(total_sales::numeric, 2) AS total_sales,
    ROUND(growth_rate::numeric, 2) AS growth_percentage,
    CASE 
        WHEN growth_rate > 10 THEN 'High Growth'
        WHEN growth_rate BETWEEN 0 AND 10 THEN 'Stable Growth'
        WHEN growth_rate BETWEEN -10 AND 0 THEN 'Slight Decline'
        WHEN growth_rate < -10 THEN 'Significant Decline'
        ELSE 'New Category'
    END AS performance_indicator
FROM 
    category_growth
ORDER BY 
    category_name, month;

-- 2. Customer Segmentation by Purchase Behavior
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.quantity * oi.unit_price) AS total_spent,
        AVG(oi.quantity * oi.unit_price) AS avg_order_value,
        MAX(o.order_date) AS last_order_date,
        CURRENT_DATE - MAX(o.order_date) AS days_since_last_order,
        EXTRACT(DAY FROM (MAX(o.order_date) - MIN(o.order_date))) / 
            NULLIF(COUNT(DISTINCT o.order_id) - 1, 0) AS avg_days_between_orders
    FROM 
        customers c
        JOIN orders o ON c.customer_id = o.customer_id
        JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY 
        c.customer_id, c.first_name, c.last_name
)
SELECT 
    customer_id,
    customer_name,
    total_orders,
    ROUND(total_spent::numeric, 2) AS total_spent,
    ROUND(avg_order_value::numeric, 2) AS avg_order_value,
    last_order_date,
    days_since_last_order,
    ROUND(avg_days_between_orders::numeric, 2) AS avg_days_between_orders,
    CASE 
        WHEN days_since_last_order <= 30 AND total_orders >= 3 AND total_spent > 500 THEN 'VIP'
        WHEN days_since_last_order <= 90 AND total_spent > 300 THEN 'Loyal'
        WHEN days_since_last_order <= 180 THEN 'Active'
        WHEN days_since_last_order <= 365 THEN 'At Risk'
        ELSE 'Inactive'
    END AS customer_segment,
    NTILE(4) OVER (ORDER BY total_spent DESC) AS spend_quartile
FROM 
    customer_metrics
ORDER BY 
    total_spent DESC;

-- 3. Product Performance with Correlation Analysis
WITH product_metrics AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category_id,
        c.category_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.quantity * oi.unit_price) AS total_revenue,
        COUNT(DISTINCT o.order_id) AS order_count,
        COUNT(DISTINCT o.customer_id) AS customer_count,
        STDDEV(oi.quantity) AS purchase_quantity_stddev,
        AVG(oi.quantity) AS avg_purchase_quantity,
        CORR(oi.unit_price, oi.quantity) AS price_quantity_correlation
    FROM 
        products p
        JOIN order_items oi ON p.product_id = oi.product_id
        JOIN orders o ON oi.order_id = o.order_id
        JOIN categories c ON p.category_id = c.category_id
    GROUP BY 
        p.product_id, p.product_name, p.category_id, c.category_name
)
SELECT 
    product_id,
    product_name,
    category_name,
    total_units_sold,
    ROUND(total_revenue::numeric, 2) AS total_revenue,
    order_count,
    customer_count,
    ROUND(avg_purchase_quantity::numeric, 2) AS avg_purchase_quantity,
    ROUND(purchase_quantity_stddev::numeric, 2) AS purchase_quantity_stddev,
    ROUND(price_quantity_correlation::numeric, 2) AS price_quantity_correlation,
    CASE 
        WHEN price_quantity_correlation < -0.5 THEN 'Strong negative (price sensitive)'
        WHEN price_quantity_correlation BETWEEN -0.5 AND -0.1 THEN 'Moderate negative'
        WHEN price_quantity_correlation BETWEEN -0.1 AND 0.1 THEN 'No correlation'
        WHEN price_quantity_correlation BETWEEN 0.1 AND 0.5 THEN 'Moderate positive'
        WHEN price_quantity_correlation > 0.5 THEN 'Strong positive (luxury good)'
    END AS price_sensitivity,
    RANK() OVER (PARTITION BY category_id ORDER BY total_revenue DESC) AS rank_in_category,
    PERCENT_RANK() OVER (ORDER BY total_revenue DESC) AS percentile_rank
FROM 
    product_metrics
ORDER BY 
    total_revenue DESC;

-- 4. Cohort Retention Analysis
WITH first_purchases AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(order_date)) AS cohort_month
    FROM 
        orders
    GROUP BY 
        customer_id
),
customer_activity AS (
    SELECT 
        fp.customer_id,
        fp.cohort_month,
        DATE_TRUNC('month', o.order_date) AS activity_month,
        DATE_PART('month', AGE(DATE_TRUNC('month', o.order_date), fp.cohort_month)) AS months_since_first_purchase
    FROM 
        first_purchases fp
        JOIN orders o ON fp.customer_id = o.customer_id
),
cohort_size AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) AS num_customers
    FROM 
        first_purchases
    GROUP BY 
        cohort_month
),
retention AS (
    SELECT 
        ca.cohort_month,
        ca.months_since_first_purchase,
        COUNT(DISTINCT ca.customer_id) AS num_customers
    FROM 
        customer_activity ca
    GROUP BY 
        ca.cohort_month, ca.months_since_first_purchase
)
SELECT 
    TO_CHAR(cs.cohort_month, 'YYYY-MM') AS cohort_month,
    cs.num_customers AS original_cohort_size,
    r.months_since_first_purchase,
    r.num_customers AS retained_customers,
    ROUND((r.num_customers::numeric / cs.num_customers::numeric) * 100, 2) AS retention_rate
FROM 
    cohort_size cs
    JOIN retention r ON cs.cohort_month = r.cohort_month
WHERE 
    cs.cohort_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY 
    cs.cohort_month, r.months_since_first_purchase;

SELECT * 
FROM us_project.supply_chain_data;

-- check for duplicates

SELECT *
FROM
	(SELECT SKU, ROW_NUMBER() OVER (PARTITION BY SKU ORDER BY SKU) as row_num
FROM us_project.supply_chain_data) as table_row
WHERE row_num > 1;

-- Detect numeric outliers using IQR method
WITH stats AS (
    SELECT
        AVG(`Price`) AS avg_price,
        STDDEV(`Price`) AS std_price,
        AVG(`Defect rates`) AS avg_defect,
        STDDEV(`Defect rates`) AS std_defect
    FROM supply_chain_data
)
SELECT 
    SKU,
    `Product type`,
    `Price`,
    `Defect rates`,
    CASE 
        WHEN `Price` > avg_price + 3*std_price THEN 'High Price Outlier'
        WHEN `Price` < avg_price - 3*std_price THEN 'Low Price Outlier'
        WHEN `Defect rates` > avg_defect + 3*std_defect THEN 'High Defect Outlier'
        ELSE 'Normal'
    END AS outlier_status
FROM supply_chain_data, stats
WHERE `Price` > avg_price + 3*std_price
   OR `Price` < avg_price - 3*std_price
   OR `Defect rates` > avg_defect + 3*std_defect;

-- Stanadardization 
-- Leave Stock Keeping Unit with integer values only
SELECT SKU, replace(SKU,'SKU','')
FROM us_project.supply_chain_data;

UPDATE	us_project.supply_chain_data
SET SKU = replace(SKU,'SKU','');

-- Capitalize the first letter of the Product type
SELECT CONCAT(
    UPPER(SUBSTRING(`Product type`, 1, 1)),
    LOWER(SUBSTRING(`Product type`, 2))
) AS capitalized_string
FROM us_project.supply_chain_data;

UPDATE	us_project.supply_chain_data
SET `Product type` = CONCAT(
    UPPER(SUBSTRING(`Product type`, 1, 1)),
    LOWER(SUBSTRING(`Product type`, 2))
) ;

-- EDA of Supply Chain Management 

-- Comprehensive location performance query
SELECT 
    Location,
    SUM(`Number of products sold`) AS total_sales,
    ROUND(SUM(`Revenue generated`), 2) AS total_revenue,
    COUNT(DISTINCT SKU) AS unique_products,
    ROUND(AVG(`Number of products sold`), 1) AS avg_sales_volume,
    ROUND(AVG(`Defect rates`), 2) AS avg_defect_rate,
    RANK() OVER(ORDER BY SUM(`Number of products sold`) DESC) AS sales_rank,
    RANK() OVER(ORDER BY SUM(`Revenue generated`) DESC) AS revenue_rank,
    CASE 
        WHEN SUM(`Number of products sold`) > AVG(SUM(`Number of products sold`)) OVER() * 1.2 
        THEN 'High Potential'
        WHEN SUM(`Number of products sold`) < AVG(SUM(`Number of products sold`)) OVER() * 0.8 
        THEN 'Needs Attention'
        ELSE 'Steady Performer'
    END AS performance_category
FROM supply_chain_data
GROUP BY Location
ORDER BY total_sales DESC;

-- 1. Which location has the hightest average sales of the 3 product types ?
-- Delhi is the location that generally has the highest average sales of the product types sold for the 3 respective product types.
SELECT 
    Location,
    ROUND(AVG(CASE WHEN `Product type` = 'haircare' THEN `Number of products sold` ELSE NULL END), 1) AS avg_haircare_sales,
    ROUND(AVG(CASE WHEN `Product type` = 'skincare' THEN `Number of products sold` ELSE NULL END), 1) AS avg_skincare_sales,
    ROUND(AVG(CASE WHEN `Product type` = 'cosmetics' THEN `Number of products sold` ELSE NULL END), 1) AS avg_cosmetics_sales,
    ROUND(AVG(`Number of products sold`), 1) AS overall_avg_sales,
    RANK() OVER (ORDER BY AVG(`Number of products sold`) DESC) AS location_rank
FROM supply_chain_data
GROUP BY Location
ORDER BY overall_avg_sales DESC;

-- 2. What is the Profit Margin calculation by product type and SKU ?
SELECT 
    `Product type`,
    SKU,
    Price,
    `Manufacturing costs`,
    `Shipping costs`,
    (Price - `Manufacturing costs` - `Shipping costs`) AS gross_profit_per_unit,
    ROUND(((Price - `Manufacturing costs` - `Shipping costs`) / Price) * 100, 2) AS gross_margin_percent,
    `Number of products sold`,
    (Price - `Manufacturing costs` - `Shipping costs`) * `Number of products sold` AS total_gross_profit,
    CASE
        WHEN (Price - `Manufacturing costs` - `Shipping costs`) / Price < 0.2 THEN 'Low Margin'
        WHEN (Price - `Manufacturing costs` - `Shipping costs`) / Price > 0.4 THEN 'High Margin'
        ELSE 'Medium Margin'
    END AS margin_category
FROM supply_chain_data
ORDER BY gross_margin_percent DESC;

-- 3. What are the sales by customer demographics like ?
SELECT 
    `Customer demographics`,
    COUNT(*) AS product_count,
    SUM(`Number of products sold`) AS total_units_sold,
    SUM(`Revenue generated`) AS total_revenue,
    ROUND(SUM(`Revenue generated`)/SUM(`Number of products sold`), 2) AS avg_price_point
FROM us_project.supply_chain_data
GROUP BY `Customer demographics`
ORDER BY total_revenue DESC;

-- 4. WHata are the product preferences by demographics like ?
SELECT 
    `Customer demographics`,
    `Product type`,
    SUM(`Number of products sold`) AS total_units_sold,
    RANK() OVER(PARTITION BY `Customer demographics` ORDER BY SUM(`Number of products sold`) DESC) AS popularity_rank
FROM supply_chain_data
GROUP BY `Customer demographics`, `Product type`
ORDER BY `Customer demographics`, popularity_rank;

-- 5. Which Transportation Modes are the most efficient based on average shipping time and cost ?
SELECT 
    `Transportation modes`,
    AVG(`Shipping times`) AS avg_shipping_time,
    AVG(`Shipping costs`) AS avg_shipping_cost,
    SUM(`Revenue generated`) AS total_revenue,
    COUNT(*) AS shipments
FROM supply_chain_data
GROUP BY `Transportation modes`
ORDER BY avg_shipping_time, avg_shipping_cost;

-- In depth transportation efficiency with cost-benefit analysis
SELECT 
    `Transportation modes`,
    `Routes`,
    COUNT(*) AS shipments,
    ROUND(AVG(`Shipping times`), 2) AS avg_shipping_time,
    ROUND(AVG(`Shipping costs`), 2) AS avg_shipping_cost,
    ROUND(SUM(`Revenue generated`), 2) AS total_revenue,
    ROUND(SUM(`Revenue generated`) / SUM(`Shipping costs`), 2) AS revenue_per_shipping_dollar,
    ROUND(AVG(`Defect rates`), 2) AS avg_defect_rate,
    RANK() OVER(PARTITION BY `Transportation modes` ORDER BY AVG(`Shipping times`)) AS time_rank,
    RANK() OVER(PARTITION BY `Routes` ORDER BY AVG(`Shipping costs`)) AS cost_rank,
    CASE
        WHEN AVG(`Shipping times`) < (SELECT AVG(`Shipping times`) FROM supply_chain_data) 
             AND AVG(`Shipping costs`) < (SELECT AVG(`Shipping costs`) FROM supply_chain_data)
        THEN 'High Efficiency'
        WHEN AVG(`Shipping times`) > (SELECT AVG(`Shipping times`) FROM supply_chain_data) * 1.2
             AND AVG(`Shipping costs`) > (SELECT AVG(`Shipping costs`) FROM supply_chain_data) * 1.2
        THEN 'Low Efficiency'
        ELSE 'Standard Efficiency'
    END AS efficiency_category
FROM supply_chain_data
GROUP BY `Transportation modes`, `Routes`
ORDER BY revenue_per_shipping_dollar DESC;

-- 6. How do varying routes perform with different modes of transport ?
SELECT 
    `Routes`,
    `Transportation modes`,
    AVG(`Shipping times`) AS avg_shipping_time,
    AVG(`Shipping costs`) AS avg_shipping_cost,
    COUNT(*) AS shipments
FROM supply_chain_data
GROUP BY `Routes`, `Transportation modes`
ORDER BY `Routes`, avg_shipping_time;

-- 7. What are the products with the highest defect rates
SELECT 
    `Product type`,
    SKU,
    `Defect rates`,
    `Inspection results`,
    `Manufacturing costs`,
    RANK() OVER(ORDER BY `Defect rates` DESC) AS defect_rank
FROM supply_chain_data
WHERE `Inspection results` = 'Fail'
ORDER BY `Defect rates` DESC
LIMIT 10;

-- Best / Worst product sales by revenue 
-- 8. What were the Top 10 best performing products by revenue ?
SELECT 
    `Product type`,
    Location,
    SKU,
    `Number of products sold`,
    `Revenue generated`,
    ROUND(`Revenue generated`/`Number of products sold`, 2) AS avg_price,
    RANK() OVER(ORDER BY `Revenue generated` DESC) AS revenue_rank
FROM us_project.supply_chain_data
ORDER BY `Revenue generated` DESC
LIMIT 10;

-- 9. What were the Top 10 worst performing products by revenue ?
SELECT 
    `Product type`,
    Location,
    SKU,
    `Number of products sold`,
    `Revenue generated`,
    ROUND(`Revenue generated`/`Number of products sold`, 2) AS avg_price,
    RANK() OVER(ORDER BY `Revenue generated` DESC) AS revenue_rank
FROM us_project.supply_chain_data
ORDER BY `Revenue generated` ASC
LIMIT 10;

-- 10. What is the impact of the defect rates of the varying product types on inventory and costs
SELECT 
    `Product type`,
    ROUND(AVG(`Defect rates`), 2) AS avg_defect_rate_percent,
    ROUND(SUM(`Number of products sold` * `Defect rates` / 100), 0) AS estimated_defective_units,
    ROUND(SUM(`Manufacturing costs` * `Number of products sold` * `Defect rates` / 100), 2) AS cost_of_defects,
    ROUND(AVG(`Inspection results` = 'Fail') * 100, 2) AS inspection_failure_rate,
    CASE
        WHEN AVG(`Defect rates`) > 3 THEN 'Critical Quality Issue'
        WHEN AVG(`Defect rates`) > 1 THEN 'Moderate Quality Issue'
        ELSE 'Acceptable Quality'
    END AS quality_status
FROM supply_chain_data
GROUP BY `Product type`
ORDER BY avg_defect_rate_percent DESC;


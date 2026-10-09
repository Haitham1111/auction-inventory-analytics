-- Business question: How far below retail do lots sell, and does that change with item size?
-- Only lots whose title advertises a retail price. Discount = 1 - hammer / retail (dollar-weighted).
USE Auction_Inventory;

SELECT COALESCE(retail_tier, 'ALL RETAIL-PRICED LOTS')                    AS retail_tier,
       COUNT(*)                                                           AS lots,
       SUM(retail_price)                                                  AS retail_total,
       SUM(hammer_price)                                                  AS hammer_total,
       CAST(100.0 * SUM(hammer_price) / SUM(retail_price) AS DECIMAL(5,1))       AS recovery_pct,
       CAST(100.0 * (1 - SUM(hammer_price) / SUM(retail_price)) AS DECIMAL(5,1)) AS discount_pct
FROM dbo.v_lots
WHERE retail_price IS NOT NULL
GROUP BY GROUPING SETS ((retail_tier), ())
ORDER BY CASE WHEN retail_tier IS NULL THEN 1 ELSE 0 END, retail_tier;

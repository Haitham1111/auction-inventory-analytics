-- Business question: What did each auction sell, and for how much?
-- Lots, hammer total, median / mean / max hammer, unique buyers, and how many lots never moved
-- past the $5 opening bid. GROUPING SETS adds the combined row.
USE Auction_Inventory;

WITH med AS (
    SELECT DISTINCT auction_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hammer_price) OVER (PARTITION BY auction_name) AS median_hammer,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hammer_price) OVER ()                          AS median_all
    FROM dbo.v_lots
)
SELECT COALESCE(l.auction_name, 'COMBINED')                  AS auction,
       COUNT(*)                                              AS lots,
       SUM(l.hammer_price)                                   AS hammer_total,
       CASE WHEN GROUPING(l.auction_name) = 1 THEN MAX(m.median_all) ELSE MAX(m.median_hammer) END AS median_hammer,
       CAST(AVG(l.hammer_price) AS DECIMAL(10,2))            AS mean_hammer,
       MAX(l.hammer_price)                                   AS max_hammer,
       COUNT(DISTINCT l.buyer_id)                            AS unique_buyers,
       SUM(CASE WHEN l.hammer_price <= 5 THEN 1 ELSE 0 END)  AS lots_at_opening_bid,
       CAST(100.0 * SUM(CASE WHEN l.hammer_price <= 5 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS pct_at_opening_bid
FROM dbo.v_lots AS l
LEFT JOIN med AS m ON m.auction_name = l.auction_name
GROUP BY GROUPING SETS ((l.auction_name), ())
ORDER BY CASE WHEN l.auction_name IS NULL THEN 1 ELSE 0 END, hammer_total DESC;

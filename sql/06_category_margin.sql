-- Business question: Which categories carry the resale margin?
-- Per category: lots, hammer, average lot price, and for retail-priced lots the dollar spread
-- between advertised retail and what the lot hammered for (the room a reseller has to work with).
USE Auction_Inventory;

SELECT category,
       COUNT(*)                                                                  AS lots,
       SUM(hammer_price)                                                         AS hammer_total,
       CAST(AVG(hammer_price) AS DECIMAL(10,2))                                  AS avg_hammer,
       COUNT(retail_price)                                                       AS lots_with_retail,
       SUM(retail_price)                                                         AS retail_total,
       SUM(CASE WHEN retail_price IS NOT NULL THEN retail_price - hammer_price END) AS retail_spread,
       CAST(100.0 * SUM(CASE WHEN retail_price IS NOT NULL THEN hammer_price END)
            / NULLIF(SUM(retail_price), 0) AS DECIMAL(5,1))                      AS recovery_pct
FROM dbo.v_lots
GROUP BY category
ORDER BY hammer_total DESC;

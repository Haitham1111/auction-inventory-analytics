-- Business question: Where do lots actually land on price?
-- Lots and hammer dollars per price band; shows how much of the revenue comes from the few big lots.
USE Auction_Inventory;

SELECT price_band,
       COUNT(*)                                                                   AS lots,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1))             AS pct_of_lots,
       SUM(hammer_price)                                                          AS hammer_total,
       CAST(100.0 * SUM(hammer_price) / SUM(SUM(hammer_price)) OVER () AS DECIMAL(5,1)) AS pct_of_hammer
FROM dbo.v_lots
GROUP BY price_band
ORDER BY price_band;

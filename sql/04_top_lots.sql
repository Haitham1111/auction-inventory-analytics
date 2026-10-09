-- Business question: Which lots drove the money?
-- Top 10 lots by hammer price with category, advertised retail and discount; RANK() keeps ties honest.
USE Auction_Inventory;

WITH ranked AS (
    SELECT RANK() OVER (ORDER BY hammer_price DESC) AS price_rank,
           lot, category, LEFT(title, 70) AS title, hammer_price, retail_price,
           CAST(100.0 * discount_to_retail AS DECIMAL(5,1)) AS discount_pct
    FROM dbo.v_lots
)
SELECT * FROM ranked
WHERE price_rank <= 10
ORDER BY price_rank, lot;

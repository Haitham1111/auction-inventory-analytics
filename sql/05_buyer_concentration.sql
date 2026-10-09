-- Business question: Is the buying crowd concentrated or spread out?
-- Spend per buyer, share of total, and running cumulative share (window functions over the CTE).
USE Auction_Inventory;

WITH spend AS (
    SELECT buyer_id, COUNT(*) AS lots_won, SUM(hammer_price) AS spend
    FROM dbo.v_lots
    GROUP BY buyer_id
)
SELECT TOP 10
       RANK() OVER (ORDER BY spend DESC)                                          AS buyer_rank,
       buyer_id, lots_won, spend,
       CAST(100.0 * spend / SUM(spend) OVER () AS DECIMAL(5,1))                   AS pct_of_hammer,
       CAST(100.0 * SUM(spend) OVER (ORDER BY spend DESC, buyer_id ROWS UNBOUNDED PRECEDING)
            / SUM(spend) OVER () AS DECIMAL(5,1))                                 AS cumulative_pct,
       COUNT(*) OVER ()                                                           AS total_buyers
FROM spend
ORDER BY spend DESC, buyer_id;

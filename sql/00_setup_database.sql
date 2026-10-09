-- 00_setup_database.sql -- run once before 01..06
-- Server: .\SQLEXPRESS | Creates database Auction_Inventory, loads the two cleaned result files
-- (data/*_results_clean.csv, written by analysis/auction_analysis.py) and builds the v_lots view.
-- Edit the two BULK INSERT paths if your copy lives elsewhere. The SQL Server service account
-- needs read access to that folder (C:\Users\Public works on a default install).

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'Auction_Inventory')
    CREATE DATABASE Auction_Inventory;
GO

USE Auction_Inventory;
GO

DROP VIEW  IF EXISTS dbo.v_lots;
DROP TABLE IF EXISTS dbo.lots;
DROP TABLE IF EXISTS dbo.auctions;

CREATE TABLE dbo.auctions (
    auction_id    INT          NOT NULL PRIMARY KEY,
    auction_name  VARCHAR(60)  NOT NULL,
    auction_date  DATE         NOT NULL,
    city          VARCHAR(40)  NOT NULL
);
INSERT INTO dbo.auctions VALUES
    (23154, 'Home & Kitchen Liquidation', '2026-03-28', 'Phoenix, AZ'),
    (23166, 'Pallets Liquidation',        '2026-03-28', 'Phoenix, AZ');

CREATE TABLE dbo.lots (
    auction_id    INT            NOT NULL REFERENCES dbo.auctions (auction_id),
    lot           VARCHAR(10)    NOT NULL,      -- keeps leading zeros (pallet lots are 0094..0099)
    title         NVARCHAR(300)  NOT NULL,
    buyer_id      VARCHAR(20)    NOT NULL,      -- auction house's anonymous bidder number
    quantity      INT            NOT NULL,
    hammer_price  DECIMAL(10,2)  NOT NULL,
    CONSTRAINT pk_lots PRIMARY KEY (auction_id, lot)
);
GO

-- Staging table matches the cleaned CSV layout exactly (lot,title,buyer_id,quantity,hammer_price).
DROP TABLE IF EXISTS #stage;
CREATE TABLE #stage (lot VARCHAR(10), title NVARCHAR(300), buyer_id VARCHAR(20), quantity INT, hammer_price DECIMAL(10,2));

-- The cleaned CSVs are UTF-8.
BULK INSERT #stage FROM 'C:\Users\Public\auction-inventory\home_kitchen_results_clean.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);
INSERT INTO dbo.lots SELECT 23154, lot, title, buyer_id, quantity, hammer_price FROM #stage;
TRUNCATE TABLE #stage;

BULK INSERT #stage FROM 'C:\Users\Public\auction-inventory\pallets_results_clean.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);
INSERT INTO dbo.lots SELECT 23166, lot, title, buyer_id, quantity, hammer_price FROM #stage;
DROP TABLE #stage;
GO

-- v_lots: one row per lot with everything the analysis needs.
--   retail_price  parsed from titles like "(Retail $1,121.00) Lanbo 24 Inch ..."; NULL when the
--                 title doesn't advertise one. Case-insensitive, so "(REtail $119.99)" counts too.
--   category      rule-based from title keywords (first match wins) -- the exports carry no category.
--   price_band    hammer price bucket; $5 is the opening bid on every lot.
CREATE VIEW dbo.v_lots AS
WITH base AS (
    SELECT l.auction_id, a.auction_name, a.auction_date, l.lot,
           REPLACE(REPLACE(REPLACE(l.title, '&#34;', '"'), '&#38;', '&'), '&amp;', '&') AS title,
           l.buyer_id, l.quantity, l.hammer_price,
           PATINDEX('%retail $%', l.title) AS rpos
    FROM dbo.lots AS l
    JOIN dbo.auctions AS a ON a.auction_id = l.auction_id
),
parsed AS (
    SELECT b.*,
           CASE WHEN rpos > 0 THEN SUBSTRING(title, rpos + 8, 20) END AS rtext
    FROM base AS b
)
SELECT auction_id, auction_name, auction_date, lot, title, buyer_id, quantity, hammer_price,
       r.retail_price,
       CASE WHEN r.retail_price > 0 THEN CAST(1 - hammer_price / r.retail_price AS DECIMAL(6,4)) END AS discount_to_retail,
       CASE
           WHEN title LIKE 'Pallet of%'                                                        THEN 'Pallets (mixed)'
           WHEN title LIKE '%Range Hood%'                                                      THEN 'Range Hoods'
           WHEN title LIKE '%NACS%' OR title LIKE '%EV Charging%' OR title LIKE '%Car Audio%'
             OR title LIKE '%Headlight%' OR title LIKE '%Camshaft%' OR title LIKE '%Turbo%'
             OR title LIKE '%Oil Filter%' OR title LIKE '%Wiring Harness%' OR title LIKE '%Toyota%' THEN 'Automotive & EV'
           WHEN title LIKE '%Refrigerator%' OR title LIKE '%Freezer%' OR title LIKE '%Cooler%'
             OR title LIKE '%Ice Maker%'                                                       THEN 'Refrigeration & Ice'
           WHEN title LIKE '%Heater%' OR title LIKE '%Radiator%'                               THEN 'Heating'
           WHEN title LIKE '%Washer%' OR title LIKE '%Washing%' OR title LIKE '%Dryer%'
             OR title LIKE '%Laundry%'                                                         THEN 'Laundry'
           WHEN title LIKE '%Microwave%' OR title LIKE '%Oven%' OR title LIKE '%Cooking Range%'
             OR title LIKE '%Electric Range%' OR title LIKE '%Food Warmer%' OR title LIKE '%Espresso%'
             OR title LIKE '%Grill%'                                                           THEN 'Kitchen Appliances'
           WHEN title LIKE '%Toilet%' OR title LIKE '%Bathtub%' OR title LIKE '%Spud%'
             OR title LIKE '%Bath Bar%' OR title LIKE '%Supply Elbow%' OR title LIKE '%Hot Water%' THEN 'Plumbing & Bath'
           WHEN title LIKE '%iPad%' OR title LIKE '%iPhone%' OR title LIKE '%Keyboard%'
             OR title LIKE '%Kvm%' OR title LIKE '%Quadcopter%' OR title LIKE '%Battery%'
             OR title LIKE '%Pager%'                                                           THEN 'Electronics'
           WHEN title LIKE '%Circuit Breaker%' OR title LIKE '%Hinge%' OR title LIKE '%Door Closer%'
             OR title LIKE '%Hole Saw%' OR title LIKE '%Glue Gun%' OR title LIKE '%Light%'
             OR title LIKE '%Sconce%' OR title LIKE '%Workbench%' OR title LIKE '%Button Maker%' THEN 'Hardware & Electrical'
           ELSE 'Home, Toys & Misc'
       END AS category,
       CASE
           WHEN hammer_price <= 5   THEN '1. $5 (opening bid)'
           WHEN hammer_price <= 20  THEN '2. $6-20'
           WHEN hammer_price <= 50  THEN '3. $21-50'
           WHEN hammer_price <= 100 THEN '4. $51-100'
           ELSE                          '5. Over $100'
       END AS price_band,
       CASE
           WHEN r.retail_price IS NULL THEN NULL
           WHEN r.retail_price < 100   THEN '1. Under $100'
           WHEN r.retail_price < 250   THEN '2. $100-249'
           WHEN r.retail_price < 500   THEN '3. $250-499'
           ELSE                             '4. $500+'
       END AS retail_tier
FROM parsed
CROSS APPLY (SELECT TRY_CAST(REPLACE(LEFT(rtext, PATINDEX('%[^0-9.,]%', rtext + 'x') - 1), ',', '') AS DECIMAL(10,2)) AS retail_price) AS r;
GO

-- Sanity check: expect 168 lots, $3,710.02 hammer, 120 lots with an advertised retail price.
SELECT COUNT(*) AS lots, SUM(hammer_price) AS hammer_total, COUNT(retail_price) AS lots_with_retail,
       SUM(retail_price) AS retail_total
FROM dbo.v_lots;

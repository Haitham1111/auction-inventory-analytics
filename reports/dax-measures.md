# Power BI Model - Auction Inventory Dashboard

`powerbi/auction-inventory-dashboard.pbix`. Two tables: `FactLots` (168 rows, from SQL Server view `dbo.v_lots`) and `_Measures` (measure container). The measures below were read from the model through TOM (read-only) and checked against `sql/`.

## Power Query - `FactLots`

Navigates to the view rather than passing a native SQL string, so the query folds.

```m
let
    Source = Sql.Database(".\SQLEXPRESS", "Auction_Inventory"),
    v_lots = Source{[Schema = "dbo", Item = "v_lots"]}[Data],
    #"Changed Types" = Table.TransformColumnTypes(v_lots, {
        {"auction_id", Int64.Type}, {"auction_name", type text}, {"auction_date", type date},
        {"lot", type text}, {"title", type text}, {"buyer_id", type text}, {"quantity", Int64.Type},
        {"hammer_price", Currency.Type}, {"retail_price", Currency.Type}, {"discount_to_retail", type number},
        {"category", type text}, {"price_band", type text}, {"retail_tier", type text}
    }),
    #"Added Lot Title" = Table.AddColumn(#"Changed Types", "Lot Title", each
        let t = if Text.StartsWith([title], "(") then Text.Trim(Text.AfterDelimiter([title], ")")) else [title]
        in if Text.Length(t) > 55 then Text.Start(t, 52) & "..." else t, type text)
in
    #"Added Lot Title"
```

`Lot Title` strips the `(Retail $...)` prefix and truncates to 55 characters for table visuals.

## Measures - `_Measures`

| Measure | DAX | Format | Purpose |
|---|---|---|---|
| Lots Sold | `COUNTROWS ( FactLots )` | `#,0` | Lot count (168 all data). |
| Hammer Total | `SUM ( FactLots[hammer_price] )` | `$#,0` | Total hammer ($3,710). |
| Avg Hammer | `AVERAGE ( FactLots[hammer_price] )` | `$#,0.00` | Mean lot price. |
| Median Hammer | `MEDIAN ( FactLots[hammer_price] )` | `$#,0.00` | Typical lot price ($5). Mean is skewed by a few appliances. |
| Top Lot | `MAX ( FactLots[hammer_price] )` | `$#,0` | Highest single hammer. |
| Unique Buyers | `DISTINCTCOUNT ( FactLots[buyer_id] )` | `#,0` | Distinct bidder IDs (41). |
| Lots at Opening Bid | `CALCULATE ( COUNTROWS ( FactLots ), FactLots[hammer_price] <= 5 )` | `#,0` | Lots that sold at the $5 opening bid (96). |
| Opening Bid Share | `DIVIDE ( [Lots at Opening Bid], [Lots Sold] )` | `0.0%` | Share of lots with no competing bid (57%). |
| Retail Value | `SUM ( FactLots[retail_price] )` | `$#,0` | Advertised retail on the 120 retail-priced lots ($27,839). |
| Hammer on Retail-Priced Lots | `CALCULATE ( [Hammer Total], NOT ISBLANK ( FactLots[retail_price] ) )` | `$#,0` | Hammer on the same 120 lots ($3,320). Keeps the discount like-for-like. |
| Recovery Rate | `DIVIDE ( [Hammer on Retail-Priced Lots], [Retail Value] )` | `0.0%` | Hammer per retail dollar (11.9%). |
| Discount to Retail | `IF ( NOT ISBLANK ( [Retail Value] ), 1 - [Recovery Rate] )` | `0.0%` | 88.1% overall. |
| Retail Spread | `[Retail Value] - [Hammer on Retail-Priced Lots]` | `$#,0` | Dollar gap, retail minus hammer. Per category, Refrigeration & Ice is largest ($5,994). |
| Top Buyer Share | `DIVIDE ( MAXX ( VALUES ( FactLots[buyer_id] ), [Hammer Total] ), [Hammer Total] )` | `0.0%` | Largest buyer's share of dollars (22.5%). |
| Top 5 Buyer Share | `DIVIDE ( SUMX ( TOPN ( 5, VALUES ( FactLots[buyer_id] ), [Hammer Total] ), [Hammer Total] ), [Hammer Total] )` | `0.0%` | Top 5 buyers' share of dollars (about 61%). |

## DAX pitfalls

- **BLANK-capable measures.** `Retail Value` is BLANK for any filter with no retail-priced lot (SUM of nothing). That makes `Recovery Rate` and `Retail Spread` BLANK (`DIVIDE` returns BLANK on a zero or BLANK denominator), and `Discount to Retail` BLANK by design (the `IF` has no else branch). `Opening Bid Share`, `Top Buyer Share`, `Top 5 Buyer Share` return BLANK when `Hammer Total` is 0 or BLANK; `Avg Hammer`, `Median Hammer` and `Top Lot` are BLANK on empty filters. `Lots Sold`, `Lots at Opening Bid` and `Unique Buyers` return 0 or BLANK on empty filters.
- **`BLANK() < 3` is TRUE in DAX** (BLANK compares as 0). Do not use a threshold like `[Discount to Retail] < 0.3` in conditional formatting or `IF` logic without `NOT ISBLANK()` first, or retail-less categories will be flagged as "low discount".
- **Retail-less lots.** 48 of 168 lots have no retail price. Use `Hammer on Retail-Priced Lots`, not `Hammer Total`, against `Retail Value`, or the discount is overstated.
- **Opening bid is hardcoded.** `Lots at Opening Bid` uses `<= 5`; it will be wrong for an auction with a different opening bid.
- **Share measures are context-sensitive.** `Top Buyer Share` and `Top 5 Buyer Share` iterate `VALUES(buyer_id)` inside the current filter, so under a category slicer they show the leader within that category, not overall.
- **Retail Spread is not a hammer-price spread.** Its max-min hammer spread for Refrigeration & Ice is $235.01, a different thing.

# Auction Inventory Analytics

Analyzing liquidation auction results from LocalAuctions.com (Phoenix, AZ) — tracking what liquidation lots actually sell for, how far below retail they go, and where the resale margin lives. Built with **Excel** (raw exports, intake tracking) and **Python** (cleaning + analysis).

## Business problem

Buying liquidation lots for resale only works if you know the real numbers: what lots hammer for, which categories carry margin, and how deep the discount to retail runs. This project turns raw auction result exports into those answers.

## Data

Source: LocalAuctions.com public auction results, Phoenix AZ, March 2026 (`data/raw/` — original Excel exports, untouched).

| Auction | Date | Lots | Hammer total |
|---|---|---|---|
| Home & Kitchen Liquidation (ID 23154) | Mar 28, 2026 | 162 | **$3,535.02** |
| Pallets Liquidation (ID 23166) | Mar 28, 2026 | 6 | $175.00 |
| **Combined** | | **168** | **$3,710.02** |

Also in `data/raw/`: the item-listing template (`auction_23613_items_list.csv`) showing how lots are consigned and listed.

## Method

1. **Excel** — raw results exports from LocalAuctions.com; lot tracking and intake.
2. **Python** (`analysis/auction_analysis.py`) — parses the exports (they ship with junk header rows above the real table), cleans lot/buyer/price fields, and computes the findings. Writes cleaned CSVs to `data/`.

Reproduce it:

```bash
pip install -r requirements.txt
python analysis/auction_analysis.py
```

## Findings (verified from the data)

- **162 lots, $3,535.02 hammer** in the Home & Kitchen auction — the headline event. Median lot sold for **$5**; mean **$21.82**; top lot **$240** (a Vissani bottom-freezer refrigerator, retail $969).
- **88.1% average discount to retail.** 119 of 162 lots advertised a retail price in the title; those lots hammered for $3,294.02 against $27,718.66 of stated retail value.
- **37 unique buyers** competed; the top buyer spent $835 across the event. Buyer concentration is low — no single buyer dominates.
- Appliances and refrigeration carry the highest absolute margin: the top 8 lots by hammer price are all major appliances (refrigerators, beverage coolers, food warmers, heaters).
- The Pallets auction (6 bulk lots, $175 total) shows the other end of the strategy: low per-lot prices on assorted-item pallets.

## What's next

- Track the same auctions month over month to spot seasonal pricing patterns.
- Build a simple "bid ceiling" calculator: given a lot's retail price and category, suggest a max bid that preserves a target resale margin.

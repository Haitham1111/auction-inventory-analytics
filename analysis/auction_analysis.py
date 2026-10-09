"""
Auction inventory analytics — LocalAuctions.com Phoenix liquidation results.

Reads the raw LocalAuctions.com results exports (Excel, with a few junk header
rows above the real table), cleans them, and computes headline findings:

  * lots sold and total hammer value per auction
  * price distribution (min / median / mean / max)
  * hammer price vs. advertised retail price (parsed from lot titles)
  * top lots by hammer price, buyer concentration

Outputs cleaned CSVs to ../data/ and prints a findings summary.

Run from the repo root:
    pip install -r requirements.txt
    python analysis/auction_analysis.py
"""

import csv
import re
from collections import Counter
from pathlib import Path
from statistics import median

import openpyxl

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
DATA = ROOT / "data"

AUCTIONS = {
    "home_kitchen": RAW / "home_kitchen_auction_23154_results.xlsx",
    "pallets": RAW / "pallets_auction_23166_results.xlsx",
}

RETAIL_RE = re.compile(r"[Rr]etail\s*\$([\d,]+\.?\d*)")


def load_results(path):
    """Parse a LocalAuctions.com results export into a list of dicts."""
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    ws = wb.active
    rows = list(ws.iter_rows(values_only=True))
    header_idx = next(i for i, r in enumerate(rows) if r[0] == "Lot #")
    lots = []
    for r in rows[header_idx + 1:]:
        if r[0] is None or not str(r[0]).strip():
            continue
        lots.append({
            "lot": str(r[0]).strip(),
            "title": str(r[1]).strip() if r[1] else "",
            "buyer_id": str(r[2]).strip() if r[2] else "",
            "quantity": int(float(r[3])) if r[3] else 0,
            "hammer_price": float(r[4]) if r[4] else 0.0,
        })
    return lots


def retail_price(title):
    m = RETAIL_RE.search(title or "")
    return float(m.group(1).replace(",", "")) if m else None


def summarize(name, lots):
    prices = [l["hammer_price"] for l in lots]
    with_retail = [(l["hammer_price"], retail_price(l["title"])) for l in lots]
    with_retail = [(h, r) for h, r in with_retail if r]
    buyers = Counter(l["buyer_id"] for l in lots)
    spend = Counter()
    for l in lots:
        spend[l["buyer_id"]] += l["hammer_price"]
    return {
        "auction": name,
        "lots": len(lots),
        "hammer_total": round(sum(prices), 2),
        "hammer_min": min(prices),
        "hammer_median": median(prices),
        "hammer_mean": round(sum(prices) / len(prices), 2),
        "hammer_max": max(prices),
        "lots_with_retail": len(with_retail),
        "retail_total": round(sum(r for _, r in with_retail), 2),
        "retail_discount_pct": round(
            100 * (1 - sum(h for h, _ in with_retail) / sum(r for _, r in with_retail)), 1
        ) if with_retail else None,
        "unique_buyers": len(buyers),
        "top_lot": max(lots, key=lambda l: l["hammer_price"]),
        "top_buyer_by_spend": spend.most_common(1)[0],
    }


def main():
    all_lots = []
    for name, path in AUCTIONS.items():
        lots = load_results(path)
        out = DATA / f"{name}_results_clean.csv"
        with open(out, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=["lot", "title", "buyer_id", "quantity", "hammer_price"])
            w.writeheader()
            w.writerows(lots)
        all_lots.extend(lots)
        s = summarize(name, lots)
        print(f"--- {s['auction']} ---")
        print(f"lots: {s['lots']} | hammer: ${s['hammer_total']:,.2f} | "
              f"median: ${s['hammer_median']:,.0f} | mean: ${s['hammer_mean']:,.2f} | "
              f"max: ${s['hammer_max']:,.0f}")
        print(f"unique buyers: {s['unique_buyers']}")
        if s["retail_discount_pct"] is not None:
            print(f"lots with retail price: {s['lots_with_retail']} | "
                  f"retail total: ${s['retail_total']:,.2f} | "
                  f"avg discount vs retail: {s['retail_discount_pct']}%")
        print(f"top lot: ${s['top_lot']['hammer_price']:,.0f} — {s['top_lot']['title'][:70]}")
        print(f"top buyer spend: buyer {s['top_buyer_by_spend'][0]} "
              f"${s['top_buyer_by_spend'][1]:,.2f}")
        print(f"cleaned csv -> {out.relative_to(ROOT)}\n")

    print("=== COMBINED ===")
    print(f"lots: {len(all_lots)} | hammer: "
          f"${sum(l['hammer_price'] for l in all_lots):,.2f}")


if __name__ == "__main__":
    main()

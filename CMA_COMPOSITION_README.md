# CMA CIS Q1-2026 — per-fund composition (Table 18) import

## What changed
The previous `import-cma-cis.ts` scored **0** on this report (0 fund AUMs, 0
composition rows, 221 bogus schemes). Table 18 is a fully-ruled grid whose
cells are vertically centred and whose fund names wrap across 2-3 lines, so the
old "trailing numbers on one reconstructed line" approach never sees all 8
columns on a single line.

The parser is rewritten to be coordinate-based:
1. read every text item with its (x, y) from pdfjs;
2. build per-fund AUM + CMA fund-type anchors from Tables 11-15;
3. anchor each Table-18 row by matching its **Total** column to a known
   per-fund AUM (pins the row regardless of name wrapping, drops subtotals);
4. bin the 8 asset-class numbers into columns by x, **zipping tokens to rows
   positionally within each column** (immune to the sub-row vertical offset);
5. reconcile each row's 8 classes against its own Total (<0.5%).

Section boundaries are detected by **content** (table headers), not hardcoded
page numbers, so it survives next quarter's pagination.

Result on CISReportQ1-2026.pdf: **43 schemes, 162 fund AUMs, 163 composition
rows — 151 auto-apply, 12 flagged for review, every row reconciles.**
Column identity verified against real holdings (Britam Bond Plus 83% GoK,
Arvocap Thamani 86% listed, NCBA Global Equity Special USD 98% offshore, etc.),
so the mapping is correct, not merely self-consistent.

## Run it
```bash
# 1. parse only — verify, no DB:
deno run -A supabase/scripts/import-cma-cis.ts stage \
    --pdf CISReportQ1-2026.pdf --period 2026-03-31 --dry --out cma.json

# 2. stage to Supabase for review:
deno run -A --env-file=fructa-admin/.env.local \
    supabase/scripts/import-cma-cis.ts stage \
    --pdf CISReportQ1-2026.pdf --period 2026-03-31 \
    --source https://www.cma.or.ke/.../CISReportQ1-2026.pdf

# 3. promote reconciled, non-flagged rows onto funds/companies:
deno run -A --env-file=fructa-admin/.env.local \
    supabase/scripts/import-cma-cis.ts apply --period 2026-03-31
```
`apply` writes `funds.composition` (+ `aum_kes`, `aum_as_of`,
`composition_source_url`) for the 151, and `companies.aum_kes`/`market_share`
from the 43 schemes. It **skips** any row with a `review` flag.

**After apply, rebuild the snapshot in admin** — `apply` writes the DB, but the
app reads the published `funds-snapshot.json`. Also confirm `snapshot.ts` /
`_shared/types.ts` publish the `composition` field (this was a pending change).

## Manual review before/after apply

### Name-collision pairs (12 rows, auto-apply skipped — map by hand)
Two different funds share a normalised name, so `apply` can't tell them apart.
Composition math is correct for each; only the DB mapping is ambiguous:

| name | totals (KES) | note |
|---|---|---|
| AA Kenya Balanced Fund | 655.8M / 364.4M | 364M is actually the **MMF** (pdfjs mangled African Alliance's wrapped scheme name) |
| Dry Associates Money Market Fund USD | 3.567B / 3.565B | two near-identical USD lines |
| Enwealth Money Market Fund | 1.752B / 29.0M | real MMF vs a Balanced-typed 29M fund (confirmed) |
| GenAfrica Money Market Fund | 4.696B / 237.5M | real MMF vs a Fixed-Income-typed 237M fund (confirmed) |
| Lofty Corban Money Market Fund | 4.404B / 191.0M | real MMF vs a small variant |
| Ziidi Money Market Fund | 18.22B / 113.9M | real MMF vs a small variant |

### African Alliance swap — verify before publishing
CMA's own labels are crossed:
- **AA Kenya Fixed Income Fund** is typed *Equity* and holds 132M **listed**;
- **AA Kenya Equity Fund** is typed *Fixed Income* and holds 251M **GoK**.
Verify against African Alliance's site before trusting the type tags.

### Negative-cash funds (6) — legitimate CMA reporting (derivative books)
Jaza, Kuza Momentum Special, Mansa-X Special USD (-2.4B), Mansa-X Shariah
KES/USD, NCBA Fixed Income Basket KES. The donut (`composition_pie.dart`)
filters `value > 0`, so these render without a cash slice — expected.

-- 0027_fund_returns.sql
-- Bucket B — trailing performance from each manager's MONTHLY fund fact sheet
-- (NOT the CMA quarterly report, which only carries composition/AUM).
--
-- Flat "latest standing" columns: the app renders current trailing figures,
-- never a returns time-series, so a monthly re-import simply overwrites. All
-- nullable and per-horizon, so a young fund with no 5Y history shows only what
-- it has, and an unseeded fund renders exactly as before.
--
-- Benchmark returns are stored PER HORIZON (bench_1y/3y/5y) straight from the
-- sheet — the trailing 3Y T-bill average is not today's spot rate, so comparing
-- a 3Y fund return against the config spot benchmark would be dishonest.

alter table public.funds
  add column if not exists return_ytd    numeric,  -- fund, % (year to date)
  add column if not exists return_1y     numeric,  -- fund, annualised %
  add column if not exists return_3y     numeric,
  add column if not exists return_5y     numeric,
  add column if not exists bench_1y      numeric,  -- stated benchmark, annualised %
  add column if not exists bench_3y      numeric,
  add column if not exists bench_5y      numeric,
  add column if not exists best_month    numeric,  -- best monthly return, trailing 12 mo, %
  add column if not exists worst_month   numeric,  -- worst monthly return, trailing 12 mo, %
  add column if not exists returns_as_of date;     -- fact-sheet month these figures are from

comment on column public.funds.return_1y is
  'Trailing 1-year annualised return, %, from the manager''s monthly fact sheet. Latest standing only.';
comment on column public.funds.bench_1y is
  'Stated benchmark''s trailing 1-year return, %, from the same fact sheet. Per-horizon so the vs-benchmark comparison is on-basis.';
comment on column public.funds.best_month is
  'Best single monthly return over the trailing 12 months, % (fact-sheet "Best 12 Month"). Pairs with worst_month as a consistency band.';
comment on column public.funds.returns_as_of is
  'The fact-sheet month these returns were published for — shown as the "as of" stamp on the performance card.';

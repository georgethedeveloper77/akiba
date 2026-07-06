-- 0023_basis_benchmarks.sql

-- funds.basis — how a fund's number is quoted. Drives whether a fund shows a
-- yield at all: MMF and Fixed Income quote an annual yield; Equity/Balanced/
-- Special don't (NAV / period returns), so the app renders AUM + composition
-- for them instead of a misleading "rate".
alter table public.funds
  add column if not exists basis text
    check (basis in ('yield', 'nav', 'none'));

update public.funds set basis = case
  when fund_type in ('mmf', 'fixed_income')        then 'yield'
  when category  in ('tbill', 'bond', 'sacco')     then 'yield'
  else 'none'
end
where basis is null;

-- Benchmark layer. Inflation, CBR, the three T-bill tenors, and the MMF
-- withholding-tax rate live in app_config, so they already ride in the
-- snapshot's config{} and the app reads them next to rates. Edit on
-- /admin/config. Values are objects carrying as_of + source for the context
-- strip. Real figures: CBK MPC 09 Jun 2026, KNBS May 2026, CBK auction 15 Jun.
insert into public.app_config (key, value) values
  ('benchmark.inflation', '{"rate":6.7,"as_of":"2026-05-31","source":"KNBS"}'::jsonb),
  ('benchmark.cbr',       '{"rate":8.75,"as_of":"2026-06-09","source":"CBK MPC"}'::jsonb),
  ('benchmark.tbill_91',  '{"rate":8.7067,"as_of":"2026-06-15","source":"CBK 2686/091"}'::jsonb),
  ('benchmark.tbill_182', '{"rate":8.6006,"as_of":"2026-06-15","source":"CBK 2660/182"}'::jsonb),
  ('benchmark.tbill_364', '{"rate":8.8715,"as_of":"2026-06-15","source":"CBK 2615/364"}'::jsonb),
  ('benchmark.wht_pct',   '{"rate":15,"source":"KRA withholding tax on MMF/interest"}'::jsonb)
on conflict (key) do nothing;

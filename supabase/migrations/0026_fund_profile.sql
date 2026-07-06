-- 0026_fund_profile.sql
-- Trust + terms enrichment for the fund detail page. Static, per-fund fields
-- pulled from manager fact sheets (inception, stated benchmark, all-in expense
-- ratio, redemption terms, top-up minimum, objective) plus the manager-family
-- custody chain (trustee / custodian / auditor) on companies.
--
-- Every column is nullable. The snapshot and app render exactly as they do
-- today until a fund/company is seeded, so the Dart side can ship ahead of the
-- data. Seed a fund's profile on /admin/funds/[id]; custody is manager-level.

-- ── Per-fund static profile ──────────────────────────────────────────────
alter table public.funds
  add column if not exists inception_date  date,
  add column if not exists benchmark_key   text
    check (benchmark_key in ('tbill_91','tbill_182','tbill_364','cbr')),
  add column if not exists expense_ratio   numeric,   -- all-in TER, % p.a.
  add column if not exists redemption_fee  numeric,   -- exit fee, %
  add column if not exists lock_in_months  int,       -- 0/null = no lock-in
  add column if not exists top_up_min      numeric,   -- subsequent top-up min
  add column if not exists objective       text;      -- one-line fund aim

comment on column public.funds.benchmark_key is
  'Which app_config benchmark this fund quotes against: tbill_91 | tbill_182 | tbill_364 | cbr. App maps to benchmark.<key> in config{}.';
comment on column public.funds.expense_ratio is
  'Total expense ratio (all-in annual cost), %. More honest than mgmt_fee alone.';
comment on column public.funds.redemption_fee is
  'Exit/redemption fee, %. Pairs with lock_in_months to describe liquidity terms.';

-- Sensible benchmark defaults by type; a fund''s own fact sheet overrides on
-- the edit page. Kenyan convention: MMFs track the 91-day, fixed income the
-- 364-day. Legacy category funds (tbill/sacco) are left null on purpose — a
-- T-bill fund *is* the benchmark, and SACCOs don''t quote against one.
update public.funds set benchmark_key = case
  when fund_type = 'mmf'          then 'tbill_91'
  when fund_type = 'fixed_income' then 'tbill_364'
end
where benchmark_key is null and fund_type in ('mmf','fixed_income');

-- ── Manager-family custody chain (shared across a manager's funds) ────────
-- Trust signals: independent custody + external audit. These sit on companies
-- because a manager (e.g. Nabo Capital) uses one trustee/custodian/auditor
-- across its whole family; per-fund override isn't needed for launch.
alter table public.companies
  add column if not exists trustee   text,
  add column if not exists custodian text,
  add column if not exists auditor   text;

comment on column public.companies.custodian is
  'Independent custodian holding the fund assets (trust signal). Manager-level.';
comment on column public.companies.trustee is
  'Trustee overseeing the unit trust on behalf of investors. Manager-level.';

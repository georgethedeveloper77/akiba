-- 0017_composition.sql
-- Quarterly composition + AUM from the CMA CIS report (uploaded via admin).
-- Composition is stored as a JSONB map of the 8 CMA asset classes → KES amount:
--   { "gok":…, "fixed_deposits":…, "cash":…, "listed":…,
--     "unlisted":…, "offshore":…, "other_cis":…, "alternative":… }

-- ── funds: per-fund composition + AUM (Table 18 + Tables 11–15) ────────────
alter table public.funds
  add column if not exists composition        jsonb,
  add column if not exists aum_kes            numeric,      -- fund AUM (KES)
  add column if not exists aum_as_of          date,         -- quarter end
  add column if not exists composition_source_url text;     -- official CMA PDF

-- ── companies: scheme-level AUM + market share (Table 1) ───────────────────
alter table public.companies
  add column if not exists aum_kes       numeric,
  add column if not exists market_share  numeric,  -- 0..100 (%)
  add column if not exists aum_as_of     date;

-- ── staging: one row per CMA upload, for admin review before publish ───────
-- The admin uploads a quarter's PDF; the parser writes parsed rows here keyed
-- by the report period. Admin eyeballs, then promotes to funds/companies.
create table if not exists public.cma_imports (
  id          uuid primary key default gen_random_uuid(),
  period      date        not null,             -- quarter end (e.g. 2026-03-31)
  source_url  text,
  uploaded_at timestamptz not null default now(),
  status      text        not null default 'staged', -- staged|applied|discarded
  -- parsed payload: { funds:[{fund_name,type,composition,aum}], schemes:[{name,aum,market_share}] }
  payload     jsonb       not null default '{}'::jsonb,
  unique (period)
);

comment on column public.funds.composition is
  'CMA asset-class split (KES per class). Quarterly, admin-reviewed.';
comment on table public.cma_imports is
  'Staging for quarterly CMA CIS report uploads before promotion.';

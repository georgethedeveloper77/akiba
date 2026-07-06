-- 0009_insurance.sql
-- Insurers are modelled as funds rows with kind='insurance'. The snapshot
-- splits them into a separate `insurers[]` array so the app's rate list stays
-- clean. Motor + Travel only ship at launch (App Review 2.1).

-- Allow the new 'insurance' category value.
alter table public.funds drop constraint if exists funds_category_check;
alter table public.funds add constraint funds_category_check
  check (category in
    ('mmf_kes','mmf_usd','bond','tbill','sacco','stock','insurance'));

alter table public.funds
  add column if not exists kind text not null default 'fund'
    check (kind in ('fund','insurance')),
  add column if not exists plans        jsonb,   -- [{name, basis, price}]
  add column if not exists min_premium  numeric,
  add column if not exists excess_pct   numeric,
  add column if not exists excess_min   numeric,
  add column if not exists claims_days  integer,
  add column if not exists rating       integer; -- 1..5 stars

comment on column public.funds.kind is
  'fund | insurance — insurers carry plans/premium/excess/rating instead of a yield.';

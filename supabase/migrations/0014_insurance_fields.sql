-- 0014_insurance_fields.sql
-- Fields the motor comparison needs on insurer rows (kind='insurance'):
--   motor_rate  — premium as a % of vehicle value (e.g. 2.30)
--   benefits    — the cover checklist chips
-- (excess_pct, excess_min, claims_days, rating, min_premium came in 0009;
--  plans jsonb holds travel tiers for D1b.)

alter table public.funds
  add column if not exists motor_rate numeric,       -- % of vehicle value
  add column if not exists benefits   text[] default '{}';

comment on column public.funds.motor_rate is
  'Insurer motor premium as a percent of vehicle value; premium = max(value*motor_rate/100, min_premium).';

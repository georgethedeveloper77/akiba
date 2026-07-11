-- Priced (NAV) fund fields. `basis` already routes yield|nav|none; a nav fund
-- quotes a unit price instead of a yield, so these carry that price, its as-of
-- date, and an optional income distribution (e.g. Lofty-Corban Bond USD 4.00%).
-- All nullable: a yield fund leaves them null and nothing about its path changes.
--
-- NOTE: confirm this is the next free number with `supabase migration list`
-- before `db push`; bump the prefix if 0040 is taken. `if not exists` keeps a
-- re-run safe if the columns were already added by hand in the SQL editor.

alter table funds add column if not exists price_per_unit numeric;
alter table funds add column if not exists price_as_of date;
alter table funds add column if not exists distribution_pct numeric;

comment on column funds.price_per_unit is
  'NAV per unit for basis=nav funds (bond/equity/priced special), in the fund''s own currency. Not a yield.';
comment on column funds.price_as_of is
  'As-of date of price_per_unit (manager quote / fact-sheet date).';
comment on column funds.distribution_pct is
  'Optional income distribution / interest %, e.g. Lofty-Corban Bond USD 4.00.';

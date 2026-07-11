-- Lofty-Corban priced (NAV) funds, from the 10 Jul 2026 rates card.
-- Run AFTER 0040_fund_pricing.sql is applied. One-time backfill (SQL editor),
-- not a migration. Raw SQL does NOT republish  hit "Rebuild snapshot" after.
--
-- Card -> DB mapping (IDs confirmed from the funds table):
--   Bond Fund (KES)  13.36              -> lofty-corban-fi-kes  ("Fixed Income Fund")
--   Bond Fund (USD)  10.12 + 4.00% int  -> lofty-corban-fi-usd  ("Fixed Income Fund USD")
--   Equity Fund (KES) 14.58             -> lofty-corban-eq-kes
--   Global Assets Special (KES) 10.71   -> lofty-corban-sp-kes-global-assets
--
-- Not touched: lofty-corban-sp-kes-special ("Special Money Market Fund", nav 8.92)
-- is not on this card.

begin;

-- 1. Correct the two mislabeled Bond funds. In the DB they are "Fixed Income
--    Fund" with basis=yield and a unit price sitting in current_rate (13.35),
--    which the app was rendering as a "13.35% gross" yield. They are priced
--    funds: flip to nav, clear the bogus rate, and drop the bad history point.
update funds
   set basis = 'nav', current_rate = null
 where id in ('lofty-corban-fi-kes', 'lofty-corban-fi-usd');

delete from rate_history
 where fund_id in ('lofty-corban-fi-kes', 'lofty-corban-fi-usd');

-- 2. Set unit prices (and Bond USD's distribution) on all four priced funds.
update funds set price_per_unit = 13.36, price_as_of = date '2026-07-10'
 where id = 'lofty-corban-fi-kes';

update funds set price_per_unit = 10.12, price_as_of = date '2026-07-10', distribution_pct = 4.00
 where id = 'lofty-corban-fi-usd';

update funds set price_per_unit = 14.58, price_as_of = date '2026-07-10'
 where id = 'lofty-corban-eq-kes';

update funds set price_per_unit = 10.71, price_as_of = date '2026-07-10'
 where id = 'lofty-corban-sp-kes-global-assets';

commit;

-- Verify:
--   select id, name, currency, basis, current_rate, price_per_unit, price_as_of, distribution_pct
--   from funds where id like 'lofty-corban-%' order by name;

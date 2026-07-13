-- 0056_stock_eps.sql
--
-- Earnings per share, so the stock page's P/E is a real number.
--
-- The approved mockup showed "P / E 12.4" in the stat triad. Fructa had no
-- earnings data of any kind, so that stat could only ever have been invented.
-- Rather than drop the stat or fake it, this adds the one input it needs.
--
-- EPS is NOT scraped and never will be. It is printed in every listed company's
-- abridged results announcement (NCBA 14.20, DTB 33.65 for FY2025), it changes
-- twice a year, and it is a figure an admin reads off a PDF and types in. A
-- scraper for a number that moves twice a year, across sixty four bespoke
-- investor-relations pages, would be fragile for no gain, and a mis-parsed EPS
-- produces a confidently wrong P/E, which is worse than no P/E.
--
-- eps_year exists because a P/E computed from today's price and a three year
-- old EPS is not a P/E, it is a coincidence. The app shows the year alongside,
-- and it can decide for itself whether a figure is too stale to publish.
--
-- eps may be NEGATIVE. A loss-making company has negative earnings, and Kenya
-- Airways has made a loss for most of the last decade. A P/E on negative
-- earnings is meaningless, so the app must suppress it rather than render a
-- negative multiple as though it meant something. There is deliberately no
-- CHECK (eps > 0): the honest value for a loss-making company is the real
-- negative number, not a null that pretends we never looked.

alter table public.stocks
  add column if not exists eps numeric(14, 4),
  add column if not exists eps_year integer;

comment on column public.stocks.eps is
  'Basic earnings per share, KES, from the company''s own results announcement. Typed by an admin, never scraped. May be negative for a loss-making company, in which case the app suppresses P/E rather than showing a negative multiple.';

comment on column public.stocks.eps_year is
  'The financial year the EPS belongs to. A P/E built from today''s price and a stale EPS is not a P/E.';

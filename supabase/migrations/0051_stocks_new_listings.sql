-- 0051_stocks_new_listings.sql
--
-- Two ordinary shares the 0049 seed missed. It was built from a December 2025
-- board; the live 10 July 2026 board carries 71 listings, not 67.
--
--   FMLY  Family Bank Ltd        listed by introduction on 23 June 2026,
--                                the NSE's 12th listed bank
--   KPC   Kenya Pipeline Company
--
-- Both are ordinary shares and both belong in the list.
--
-- Still deliberately excluded, because none of them is a slice of a business
-- and the Learn course teaches exactly that distinction:
--   ALP    ALP Real Estate Investment Trust   REIT   (new on the board)
--   TRFC   TRIFIC Green USD I-REIT            REIT   (new on the board)
--   LAPR   Laptrust Imara Income-REIT         REIT
--   GLD    Absa NewGold ETF                   ETF
--   SMWF   Satrix MSCI World Feeder ETF       ETF
--   KPLC-P4 / KPLC-P7                         preference shares
--
-- The scraper reports every unmatched ticker rather than skipping it, which is
-- how these surfaced. That is the system working: a new listing announces
-- itself instead of the app quietly presenting an incomplete market.

insert into public.stocks (id, ticker, name, sector) values
  ('family-bank-ltd', 'FMLY', 'Family Bank Ltd', 'Banking'),
  ('kenya-pipeline-company-plc', 'KPC', 'Kenya Pipeline Company Plc', 'Energy and Petroleum')
on conflict (id) do update set
  ticker = excluded.ticker,
  name   = excluded.name,
  sector = excluded.sector;

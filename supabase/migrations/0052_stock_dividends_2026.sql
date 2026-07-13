-- 0052_stock_dividends_2026.sql
--
-- The twelve corporate actions carried on the NSE Daily Price List of
-- 10 July 2026, transcribed BY EYE from the PDF.
--
-- Not OCR'd. Tesseract at 300dpi read "27-Mar-2025" for 27-Mar-2026 and
-- "10-Apr-2024" for 10-Apr-2026 on this very block. A dividend with the wrong
-- year is worse than no dividend, so these were read and typed by hand.
--
-- ── WHAT THIS IS NOT ───────────────────────────────────────────────────────
-- This is the exchange's PENDING ACTIONS window, not a dividend history. It
-- carries Safaricom's FINAL dividend and not its interim. So for any company
-- that pays an interim, dps_latest here is only part of the year, and the
-- div_yield the snapshot computes from it will read LOW.
--
-- Safaricom: final 1.15 alone gives 1.15 / 35.05 = 3.28%. The real trailing
-- yield is materially higher. A yield that reads low is still a wrong number.
--
-- Therefore: apply this migration for the DATES (book closure and payment date
-- are complete and correct for the current cycle, and they are what a buyer
-- actually needs to know), but do not treat div_yield as trustworthy until the
-- interims are backfilled. See the note at the bottom.
--
-- ── VERIFY BEFORE APPLYING ─────────────────────────────────────────────────
-- 1. financial_year is INFERRED, not printed on the list. The rule used: the
--    year of the most recently COMPLETED financial year at the date of
--    announcement. Most NSE companies close in December, so a dividend declared
--    in 2026 belongs to FY2025. Safaricom closes on 31 March, so its May 2026
--    declaration belongs to FY2026. Check the ones marked CHECK below.
-- 2. Two book-closure dates where my reading and the OCR disagreed are marked
--    CONFLICT. I have used my reading of the PDF. Confirm them.

insert into public.stock_dividends
  (stock_id, financial_year, kind, dps_kes, declared_on, book_closure, payment_date, source_url)
select s.id, v.fy, v.kind, v.dps, v.declared, v.books, v.pay,
       'https://www.nse.co.ke/wp-content/uploads/10-JUL-26.pdf'
from (values
  -- ticker, FY, kind,    dps,    declared,     book closure,  payment
  ('SCOM', 2026, 'final',   1.15, date '2026-05-07', date '2026-08-04', date '2026-09-04'),  -- CHECK FY: March year end
  ('CRWN', 2025, 'final',   3.00, date '2026-05-25', date '2026-06-26', date '2026-08-31'),  -- "First & Final" -> single final row
  ('LBTY', 2025, 'final',   0.50, date '2026-03-11', date '2026-06-26', date '2026-08-30'),  -- CONFLICT: OCR read 15-Jun for book closure
  ('KNRE', 2025, 'final',   0.15, date '2026-03-27', date '2026-06-19', date '2026-07-31'),
  ('NSE',  2025, 'final',   1.00, date '2026-03-27', date '2026-05-21', date '2026-07-31'),
  ('TOTL', 2025, 'final',   3.45, date '2026-04-30', date '2026-06-26', date '2026-07-31'),  -- CONFLICT: OCR read 24-Jun for book closure
  ('TPSE', 2025, 'final',   0.35, date '2026-04-30', date '2026-06-26', date '2026-07-30'),
  ('JUB',  2025, 'final',  13.00, date '2026-04-10', date '2026-06-11', date '2026-07-24'),
  ('BOC',  2025, 'final',  10.35, date '2026-04-16', date '2026-05-31', date '2026-07-21'),
  -- Payment date "SUBJECT TO APPROVAL" on the list. Null, not a guessed date:
  -- a payment date the app invents is a promise the company has not made.
  ('PORT', 2025, 'final',   1.25, date '2026-06-22', null,              null),
  ('WTK',  2025, 'final',  15.00, date '2026-06-26', date '2026-07-31', null),
  ('KAPC', 2025, 'final',  30.00, date '2026-06-26', date '2026-07-31', null)
) as v(ticker, fy, kind, dps, declared, books, pay)
join public.stocks s on s.ticker = v.ticker
on conflict (stock_id, financial_year, kind) do update set
  dps_kes      = excluded.dps_kes,
  declared_on  = excluded.declared_on,
  book_closure = excluded.book_closure,
  payment_date = excluded.payment_date,
  source_url   = excluded.source_url,
  updated_at   = now();

-- Every ticker above must exist in `stocks` or its dividend is silently lost by
-- the join. Fail loudly instead: if the count is short, something is wrong with
-- the seed and we want to know now, not when a yield renders blank.
do $$
declare n integer;
begin
  select count(*) into n
    from public.stock_dividends
   where source_url like '%10-JUL-26.pdf';
  if n <> 12 then
    raise exception 'expected 12 dividend rows, wrote %. A ticker in the list is missing from `stocks`.', n;
  end if;
end;
$$;

-- ── STILL MISSING: interim dividends ───────────────────────────────────────
-- The companies below pay interims that this list does not carry, so their
-- dps_latest (and therefore div_yield) is incomplete until those rows land:
--   SCOM, EABL, and the banks (EQTY, KCB, COOP, ABSA, SCBK, NCBA, DTK, IMH).
-- Source for the full set: each company's annual report, or the dividends table
-- at african-markets.com/en/stock-markets/nse/dividends.

-- 0050_stocks_prices_on.sql
--
-- Turns on the stocks price lane and schedules the daily scrape.
--
-- `stocks.prices_enabled` was written in 0047 as a licence gate. It is now a
-- KILL SWITCH: set it false and the scraper stops and every price surface in
-- the app hides itself, with no deploy. Keep it for the reasons that have
-- nothing to do with licensing: a bad parse, a source outage, a wrong number
-- loose in the wild. One UPDATE and the prices are gone.

update public.app_config
   set value = 'true'::jsonb
 where key = 'stocks.prices_enabled';

-- Attribution, shown under the stocks list and on the stock page. Honest about
-- what the number is: yesterday's close, not a live quote, and not a trade.
insert into public.app_config (key, value)
values (
  'stocks.price_disclaimer',
  '"End of day closing prices, not live. Fructa is informational and does not place trades. Buy and sell through a CMA-licensed broker."'::jsonb
)
on conflict (key) do update set value = excluded.value;

insert into public.app_config (key, value)
values (
  'stocks.price_source',
  '"NSE end of day"'::jsonb
)
on conflict (key) do nothing;

-- ── schedule ───────────────────────────────────────────────────────────────
-- The NSE trades 09:30 to 15:00 EAT. The board settles after the close, so we
-- read it in the evening: 16:00 UTC = 19:00 EAT, weekdays. Late enough that the
-- close is final, early enough that a failure is visible the same evening.
--
-- Routed through invoke_edge_function (0048), so a missing vault secret writes
-- a visible failure row instead of silently doing nothing for six days.

do $$
begin
  if exists (select 1 from cron.job where jobname = 'fructa-scrape-nse') then
    perform cron.unschedule('fructa-scrape-nse');
  end if;
end;
$$;

select cron.schedule(
  'fructa-scrape-nse',
  '0 16 * * 1-5',
  $cron$select public.invoke_edge_function('scrape-nse');$cron$
);

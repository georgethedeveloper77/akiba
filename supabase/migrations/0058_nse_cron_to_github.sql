-- 0058_nse_cron_to_github.sql
--
-- Unschedule the Supabase-side NSE cron. It cannot succeed.
--
-- The pg_cron job `fructa-scrape-nse` fires the scrape-nse edge function, which
-- fetches afx from Supabase's eu-central-1 egress. afx BLOCKS that address: it
-- drops the packets silently, no 403 and no 429, just no answer until the socket
-- dies at 150 seconds. We swapped the honest "FructaBot/1.0" user agent for a
-- real Chrome string and got the identical hang, which is how we know it is the
-- IP and not the header.
--
-- Leaving the job scheduled would mean a guaranteed red failure every weekday
-- at 19:00 EAT, which is worse than useless: an alarm that always fires is an
-- alarm nobody reads, and it would bury the day a REAL failure appears.
--
-- The fetch now runs on a GitHub Actions runner (.github/workflows/scrape-nse.yml)
-- whose IP looks like an ordinary client, and that runner POSTs the parsed board
-- back to the same edge function. So the function is NOT retired: it still owns
-- ticker mapping, the sanity band, prev_close, source health, the run log and the
-- snapshot. Only the fetching moved.
--
-- ke-cbk-tbills already works this way. This is the second time a Kenyan data
-- host has been fine with a normal client and hostile to a cloud region, which
-- is worth remembering before the next scraper is written for the edge by
-- default.

do $$
begin
  if exists (select 1 from cron.job where jobname = 'fructa-scrape-nse') then
    perform cron.unschedule('fructa-scrape-nse');
  end if;
end
$$;

-- Record why, where the next person will look.
insert into public.app_config (key, value)
values (
  'stocks.price_source_note',
  '"NSE prices are fetched by the scrape-nse GitHub Action, not by Supabase cron: afx blocks Supabase egress IPs. The edge function still validates and stores."'::jsonb
)
on conflict (key) do update set value = excluded.value;

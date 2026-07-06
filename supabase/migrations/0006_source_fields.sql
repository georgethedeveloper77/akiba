-- 0006_source_fields.sql
-- Where each rate is read from, and whether it's automated or updated by hand.
-- Powers the admin's Sources directory.

alter table public.funds
  add column if not exists rate_source_url text,
  add column if not exists source_type text not null default 'auto'
    check (source_type in ('auto', 'manual'));

-- The sources we maintain by hand (JS-gated CBK, SACCO, NSE) start as manual.
update public.funds
  set source_type = 'manual'
  where id in ('cbk-tbill-91', 'cbk-ifb-latest', 'stima-sacco', 'safaricom-nse');

-- Official page to read the CBK T-bill rate from.
update public.funds
  set rate_source_url = 'https://www.centralbank.go.ke/bills-bonds/treasury-bills/'
  where id = 'cbk-tbill-91';

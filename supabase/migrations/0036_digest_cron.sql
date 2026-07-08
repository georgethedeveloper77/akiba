-- 0036_digest_cron.sql
-- Schedule the weekly digest: Fridays 06:00 UTC (= 09:00 EAT), matching the
-- "Weekly digest - Fridays" copy in the app's Settings. pg_cron fires it;
-- pg_net calls the edge function with the same x-cron-secret the function
-- checks. Reuses the Vault secrets set up in 0004_cron.sql (project_url,
-- cron_secret) — no new Vault entries needed.
--
-- The digest function pushes only to the 'digest_weekly' OneSignal segment, so
-- this reaches just the users who left the Weekly digest toggle on.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Guard against a re-run stacking a duplicate schedule: drop any prior digest
-- job (matched by command) before (re)creating it.
do $$
declare jid bigint;
begin
  select jobid into jid from cron.job where command ilike '%weekly-digest%' limit 1;
  if jid is not null then
    perform cron.unschedule(jid);
    raise notice 'removed existing weekly-digest cron job %', jid;
  end if;
end $$;

select cron.schedule(
  'fructa-weekly-digest',
  '0 6 * * 5',                    -- 06:00 UTC Friday = 09:00 EAT
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/weekly-digest',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Inspect / manage later:
--   select jobid, jobname, schedule, active from cron.job where command ilike '%weekly-digest%';
--   select * from cron.job_run_details order by start_time desc limit 20;
--   select cron.unschedule('fructa-weekly-digest');

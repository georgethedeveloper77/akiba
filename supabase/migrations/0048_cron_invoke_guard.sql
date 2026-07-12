-- 0048_cron_invoke_guard.sql
--
-- Why this exists.
--
-- Both cron jobs built their URL inline:
--
--   url := (select decrypted_secret from vault.decrypted_secrets
--           where name = 'project_url') || '/functions/v1/scrape-aggregator'
--
-- When a vault secret is missing, that select returns NULL rather than
-- raising. In Postgres, NULL || 'text' is NULL. So the URL collapsed to NULL,
-- net.http_post died on a not-null constraint, and the edge function was never
-- called. No HTTP request was made, so nothing was ever written to
-- scraper_runs, so the admin console kept showing the last SUCCESSFUL run as
-- though it were the current state.
--
-- Rates went stale for six days and nobody could see it. The scraper was not
-- failing. It was never running.
--
-- This migration routes both jobs through one function that checks the secrets
-- BEFORE building the URL, and writes a visible failure row when they are
-- missing.
--
-- Note on the design: the guard deliberately does NOT raise an exception on a
-- missing secret. Raising would roll back the failure row we just wrote, and
-- we would be back to a failure that only exists in cron.job_run_details,
-- which is exactly the log nobody read for six days. Instead it logs a row the
-- admin console already surfaces, and raises a WARNING. Loud where somebody is
-- actually looking.

-- ── the guarded invoker ────────────────────────────────────────────────────

create or replace function public.invoke_edge_function(fn text)
returns bigint
language plpgsql
security definer
set search_path = public, vault, net, pg_temp
as $$
declare
  v_url    text;
  v_secret text;
  v_missing text;
  v_req_id bigint;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'cron_secret';

  -- Name every missing secret, not just the first. A half-fixed vault should
  -- not need a second round trip to discover.
  v_missing := nullif(
    concat_ws(', ',
      case when v_url    is null or btrim(v_url)    = '' then 'project_url' end,
      case when v_secret is null or btrim(v_secret) = '' then 'cron_secret' end
    ), '');

  if v_missing is not null then
    perform public.log_cron_failure(
      fn,
      'Vault secret missing or empty: ' || v_missing ||
      '. The edge function was NOT called.'
    );
    raise warning
      'invoke_edge_function(%): vault secret(s) missing or empty: %. Nothing was called. Fix with vault.create_secret() or vault.update_secret().',
      fn, v_missing;
    return null;
  end if;

  -- rtrim guards against a project_url stored with a trailing slash, which
  -- would otherwise produce a double slash in the path.
  select net.http_post(
    url     := rtrim(v_url, '/') || '/functions/v1/' || fn,
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'x-cron-secret', v_secret
               ),
    body    := '{}'::jsonb
  ) into v_req_id;

  return v_req_id;
end;
$$;

comment on function public.invoke_edge_function(text) is
  'Calls an edge function from pg_cron. Checks the vault secrets first, because a missing secret yields NULL, not an error, and NULL || text is NULL.';

-- ── the visible failure row ────────────────────────────────────────────────
--
-- Writes into scraper_runs, which the admin Overview already reads: a run with
-- ok = false becomes a red "Needs attention" item and a red heatmap cell.
--
-- The whole body is wrapped so that a schema drift in scraper_runs can never
-- take down the cron job itself. Logging is best-effort; the job is not.

create or replace function public.log_cron_failure(fn text, msg text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  begin
    insert into public.scraper_runs
      (source, started_at, finished_at, written, rejected, ok, unmapped, errors)
    values
      ('cron:' || fn, now(), now(), 0, 0, false, array[]::text[], array[msg]::text[]);
  exception when others then
    -- Never let the logger break the caller. If scraper_runs has drifted, say
    -- so in the cron log and move on.
    raise warning 'log_cron_failure(%): could not write to scraper_runs: %', fn, sqlerrm;
  end;
end;
$$;

comment on function public.log_cron_failure(text, text) is
  'Best-effort failure row so a broken cron job is visible in the admin console, not only in cron.job_run_details.';

-- Security-definer functions must not be callable by the public API roles.
revoke all on function public.invoke_edge_function(text) from public;
revoke all on function public.log_cron_failure(text, text) from public;
grant execute on function public.invoke_edge_function(text) to postgres;
grant execute on function public.log_cron_failure(text, text) to postgres;

-- ── repoint both jobs at the guard ─────────────────────────────────────────
-- Unschedule guarded on existence: cron.unschedule() raises if the job is not
-- there, which would abort the migration on a fresh database.

do $$
begin
  if exists (select 1 from cron.job where jobname = 'akiba-scrape-aggregator') then
    perform cron.unschedule('akiba-scrape-aggregator');
  end if;
  if exists (select 1 from cron.job where jobname = 'fructa-scrape-aggregator') then
    perform cron.unschedule('fructa-scrape-aggregator');
  end if;
  if exists (select 1 from cron.job where jobname = 'fructa-weekly-digest') then
    perform cron.unschedule('fructa-weekly-digest');
  end if;
end;
$$;

-- 09:00 UTC = 12:00 EAT, weekdays. Unchanged; the schedule was never the bug.
-- Renamed off the legacy "akiba" prefix while we are in here.
select cron.schedule(
  'fructa-scrape-aggregator',
  '0 9 * * 1-5',
  $cron$select public.invoke_edge_function('scrape-aggregator');$cron$
);

-- 06:00 UTC Friday. Unchanged.
select cron.schedule(
  'fructa-weekly-digest',
  '0 6 * * 5',
  $cron$select public.invoke_edge_function('weekly-digest');$cron$
);

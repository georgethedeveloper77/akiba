-- 0003_scraper_runs.sql
-- Every scraper invocation records a row here. This is what the admin panel's
-- "scraper health / last success per source" view reads.

create table public.scraper_runs (
  id          bigint generated always as identity primary key,
  source      text        not null,
  started_at  timestamptz not null,
  finished_at timestamptz,
  written     int         not null default 0,
  rejected    int         not null default 0,
  unmapped    text[]      not null default '{}',
  errors      text[]      not null default '{}',
  ok          boolean     not null default false
);

create index scraper_runs_source_time_idx on public.scraper_runs (source, started_at desc);

-- Internal telemetry: readable only via service role (admin). No anon policy,
-- so RLS hides it from the app entirely.
alter table public.scraper_runs enable row level security;

-- 0057_source_health.sql
--
-- Per-source health, so a blocked source is backed off instead of hammered.
--
-- afx started dropping our requests silently: no 403, no 429, just no answer
-- until the socket died. That is a firewall dropping packets, and the correct
-- response to it is NOT to keep knocking every single weekday forever. A host
-- that has decided it does not like you likes you even less after the two
-- hundredth request.
--
-- So: every failure raises consecutive_failures, and past a threshold the source
-- goes into cooldown and is SKIPPED entirely until blocked_until passes. One
-- clean run resets it to zero.
--
-- The backoff is deliberately slow to start. The cron fires once a weekday
-- anyway, so one or two failures need no cooldown at all: tomorrow's scheduled
-- run IS the retry. Cooldown only kicks in when a source is properly down, and
-- then it steps 3 days, 1 week, 2 weeks.
--
-- A manual re-run from admin IGNORES the cooldown. When a human presses the
-- button they are asking a specific question ("is it back yet?"), and refusing
-- to answer because of a timer we invented would be obnoxious.

create table if not exists public.source_health (
  source                text primary key,
  consecutive_failures  integer     not null default 0,
  blocked_until         date,
  last_ok_at            timestamptz,
  last_error            text,
  updated_at            timestamptz not null default now()
);

comment on table public.source_health is
  'Availability state per scrape source. Drives cooldown/backoff so a source that is blocking us is not hit every day forever.';
comment on column public.source_health.blocked_until is
  'Skip this source entirely until this date. Null means available. A manual admin re-run ignores it.';
comment on column public.source_health.consecutive_failures is
  'Reset to 0 by any run that returns a usable board. Drives the backoff ladder: 3 failures = 3 days, 4 = 1 week, 5+ = 2 weeks.';

alter table public.source_health enable row level security;

-- Seed the source we have. Available, no history.
insert into public.source_health (source)
values ('afx-nse')
on conflict (source) do nothing;

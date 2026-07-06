-- 0012_market_events.sql
-- Events written by the pipeline, consumed by the notifier and the News feed.

create table public.market_events (
  id         bigint generated always as identity primary key,
  type       text not null
               check (type in ('rate_change','leader_change','auction_result','coupon')),
  category   text,                               -- optional scope, e.g. 'mmf_kes'
  fund_id    text references public.funds(id) on delete cascade,
  payload    jsonb,                              -- headline, deltas, etc.
  created_at timestamptz not null default now()
);
create index market_events_created_idx on public.market_events (created_at desc);

alter table public.market_events enable row level security;
create policy market_events_public_read on public.market_events
  for select to anon, authenticated using (true);

-- Provenance (source register): every rate_history row records its source URL
-- alongside the existing `source` id.
alter table public.rate_history add column if not exists source_url text;

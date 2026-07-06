-- 0021_rate_review.sql
-- Hold-for-approval lane. The aggregator stops auto-applying surprising rates;
-- they wait here until an admin approves. Approving writes the value through to
-- rate_history + funds.current_rate exactly as an auto apply would. In-tolerance
-- rates still apply automatically and never touch this table.

create table public.rate_review (
  id          bigint generated always as identity primary key,
  fund_id     text not null references public.funds(id) on delete cascade,
  source      text not null,                      -- adapter id: serrari-mmf, etica-site...
  old_rate    numeric,                            -- funds.current_rate at scrape time
  new_rate    numeric not null,
  delta_bps   numeric,                            -- (new_rate - old_rate) * 100
  as_of       date not null,
  reason      text not null default 'jump'
                check (reason in ('jump','conflict','new_fund')),
  status      text not null default 'pending'
                check (status in ('pending','approved','rejected')),
  created_at  timestamptz not null default now(),
  decided_at  timestamptz,
  decided_by  text,
  -- one review row per fund/day; a fresh scrape replaces it and re-opens review
  unique (fund_id, as_of)
);
create index rate_review_pending_idx
  on public.rate_review (status) where status = 'pending';

comment on table public.rate_review is
  'Scraped rates held for manual approval (large jump, source conflict, or new fund).';

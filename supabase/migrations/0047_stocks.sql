-- 0047_stocks.sql
-- NSE-listed equities.
--
-- Scope notes:
--   * `stocks` are NSE-listed companies. These are NOT the same entity as
--     `companies` (which are fund managers / insurers). No FK between them.
--   * Price data (stock_prices) is NSE market data and is subject to an NSE
--     redistribution licence. The `stocks.prices_enabled` app_config key gates
--     whether publish-snapshot emits any price field to the app. Default false.
--   * Dividend and company-fact data comes from public company announcements
--     and annual reports, and is not gated.

-- ---------------------------------------------------------------------------
-- stocks
-- ---------------------------------------------------------------------------
create table if not exists public.stocks (
  id                  text primary key,            -- slug, e.g. 'safaricom-plc'
  ticker              text not null unique,        -- e.g. 'SCOM'
  name                text not null,               -- e.g. 'Safaricom PLC'
  sector              text,                        -- e.g. 'Telecommunications'
  segment             text,                        -- 'MIM' | 'AIM' | 'GEMS'
  isin                text,
  about               text,                        -- one paragraph, plain text
  logo_url            text,                        -- logos bucket, public
  brand_color         text,                        -- hex, nullable
  website             text,
  ir_url              text,                        -- investor relations page
  shares_outstanding  bigint,                      -- for market cap
  listed_on           date,
  active              boolean not null default true,
  sort_order          integer,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index if not exists stocks_active_idx  on public.stocks (active);
create index if not exists stocks_sector_idx  on public.stocks (sector);
create index if not exists stocks_segment_idx on public.stocks (segment);

comment on column public.stocks.segment is 'NSE market segment: MIM, AIM or GEMS';
comment on column public.stocks.shares_outstanding is 'Used with latest close to derive market cap. Null means market cap is hidden.';

-- ---------------------------------------------------------------------------
-- stock_dividends
-- Public data. Sourced from company announcements and annual reports.
-- ---------------------------------------------------------------------------
create table if not exists public.stock_dividends (
  id             uuid primary key default gen_random_uuid(),
  stock_id       text not null references public.stocks (id) on delete cascade,
  financial_year integer not null,                 -- e.g. 2025
  kind           text not null default 'final',    -- 'interim' | 'final' | 'special'
  dps_kes        numeric(12,4) not null,           -- dividend per share, KES
  declared_on    date,
  book_closure   date,
  payment_date   date,
  source_url     text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint stock_dividends_kind_ck
    check (kind in ('interim', 'final', 'special')),
  constraint stock_dividends_unique
    unique (stock_id, financial_year, kind)
);

create index if not exists stock_dividends_stock_idx
  on public.stock_dividends (stock_id, financial_year desc);

comment on table public.stock_dividends is 'Declared dividends per share. One row per stock per financial year per kind.';

-- ---------------------------------------------------------------------------
-- stock_prices
-- NSE market data. LICENCE GATED. Populate only under an NSE data agreement.
-- ---------------------------------------------------------------------------
create table if not exists public.stock_prices (
  id          bigserial primary key,
  stock_id    text not null references public.stocks (id) on delete cascade,
  as_of       date not null,                       -- trading day
  close_kes   numeric(14,4) not null,
  prev_close  numeric(14,4),
  day_high    numeric(14,4),
  day_low     numeric(14,4),
  volume      bigint,
  source      text,                                -- feed identifier
  created_at  timestamptz not null default now(),
  constraint stock_prices_unique unique (stock_id, as_of)
);

create index if not exists stock_prices_stock_asof_idx
  on public.stock_prices (stock_id, as_of desc);

comment on table public.stock_prices is 'NSE price history. Subject to NSE data redistribution licence. Gated by app_config key stocks.prices_enabled.';

-- ---------------------------------------------------------------------------
-- brokers
-- CMA-licensed stockbrokers, for the "Where to buy" section.
-- ---------------------------------------------------------------------------
create table if not exists public.brokers (
  id          text primary key,                    -- slug, e.g. 'dyer-and-blair'
  name        text not null,
  license_no  text,
  blurb       text,                                -- one short line
  phone       text,
  email       text,
  website     text,
  app_url     text,                                -- deep link or store link
  logo_url    text,
  active      boolean not null default true,
  sort_order  integer,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists brokers_active_idx on public.brokers (active, sort_order);

comment on table public.brokers is 'CMA-licensed stockbrokers. Fructa routes users out to these. Fructa does not execute trades.';

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists stocks_touch on public.stocks;
create trigger stocks_touch
  before update on public.stocks
  for each row execute function public.touch_updated_at();

drop trigger if exists stock_dividends_touch on public.stock_dividends;
create trigger stock_dividends_touch
  before update on public.stock_dividends
  for each row execute function public.touch_updated_at();

drop trigger if exists brokers_touch on public.brokers;
create trigger brokers_touch
  before update on public.brokers
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- The app reads the published snapshot, never these tables directly.
-- Admin and edge functions use the service role, which bypasses RLS.
-- So: enable RLS with no permissive policy = deny by default to anon.
-- ---------------------------------------------------------------------------
alter table public.stocks         enable row level security;
alter table public.stock_dividends enable row level security;
alter table public.stock_prices   enable row level security;
alter table public.brokers        enable row level security;

-- ---------------------------------------------------------------------------
-- Config gate
-- ---------------------------------------------------------------------------
insert into public.app_config (key, value)
values (
  'stocks.prices_enabled',
  'false'::jsonb
)
on conflict (key) do nothing;

insert into public.app_config (key, value)
values (
  'stocks.price_disclaimer',
  '"Prices are NSE delayed. Fructa does not place trades. Buy and sell through a CMA-licensed broker."'::jsonb
)
on conflict (key) do nothing;

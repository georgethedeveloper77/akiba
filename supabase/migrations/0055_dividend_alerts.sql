-- 0055_dividend_alerts.sql
--
-- Book-closure alerts. The one stock notification worth a user's attention.
--
-- To receive a dividend you must be on the register when the books close. Miss
-- it by a day and you get nothing, however long you then hold. That date lives
-- in an image-only PDF on the exchange's website and nowhere a retail investor
-- would ever look. This is the asymmetry Fructa exists to close.
--
-- Deliberately NOT a price alert. A daily "SCOM moved 2%" across 64 counters is
-- noise a user mutes within a week, and it trains exactly the instinct the
-- Learn course spends a unit arguing against.

create table if not exists public.dividend_alert_log (
  -- The dedupe key IS the identity: one send per stock, per financial year, per
  -- dividend kind, per lead. Making it the primary key means the database
  -- itself refuses a duplicate, so a retry or an overlapping cron cannot push
  -- the same deadline at somebody twice. Sending a user the same alert three
  -- mornings running is how an app gets uninstalled.
  dedupe_key      text primary key,
  stock_id        text not null references public.stocks(id) on delete cascade,
  financial_year  integer not null,
  kind            text not null,
  lead_days       integer not null,
  heading         text,
  body            text,
  recipients      integer,
  onesignal_id    text,
  sent_at         timestamptz not null default now()
);

create index if not exists dividend_alert_log_stock_idx
  on public.dividend_alert_log (stock_id, financial_year);

alter table public.dividend_alert_log enable row level security;
-- No policy: service role only. Nothing client-side ever reads this.

-- ── schedule ───────────────────────────────────────────────────────────────
-- 06:00 UTC = 09:00 EAT, daily. A morning alert about a deadline the user can
-- still act on today, before the market opens at 09:30. Sending this at 3am
-- would be technically identical and practically useless.
--
-- Daily, not weekdays only: book closure dates fall on weekends, and a Friday
-- run would miss a Sunday deadline entirely.
--
-- Routed through invoke_edge_function (0048), so a missing vault secret writes
-- a visible failure row instead of failing silently for six days.

do $$
begin
  if exists (select 1 from cron.job where jobname = 'fructa-dividend-alerts') then
    perform cron.unschedule('fructa-dividend-alerts');
  end if;
end;
$$;

select cron.schedule(
  'fructa-dividend-alerts',
  '0 6 * * *',
  $cron$select public.invoke_edge_function('emit-dividend-alerts');$cron$
);

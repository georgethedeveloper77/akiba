-- 0010_fx_rates.sql
-- CBK indicative exchange rates (USD/KES, daily). Used to show KES-equivalent
-- earnings on USD positions.

create table public.fx_rates (
  pair  text    not null,                        -- 'USD/KES'
  rate  numeric not null,
  as_of date    not null,
  primary key (pair, as_of)
);

alter table public.fx_rates enable row level security;
create policy fx_rates_public_read on public.fx_rates
  for select to anon, authenticated using (true);

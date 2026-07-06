-- 0007_companies.sql
-- Companies become the parent entity: funds/insurers/saccos/government all
-- belong to a company. Backfilled one-per-manager from existing funds.

create table public.companies (
  id          text primary key,                 -- slug of the name
  name        text not null,
  type        text not null default 'fund_manager'
                check (type in ('fund_manager','insurer','sacco','government')),
  brand_color text,                             -- hex, e.g. '#E7B24C'
  logo_url    text,
  website     text,
  verified    boolean not null default false,
  updated_at  timestamptz not null default now()
);

comment on table public.companies is
  'Parent entity for funds, insurers, saccos and government issuers.';

create trigger companies_touch_updated_at
  before update on public.companies
  for each row execute function public.touch_updated_at();

-- Link funds to their company.
alter table public.funds
  add column if not exists company_id text references public.companies(id);
create index funds_company_idx on public.funds (company_id);

-- Backfill: one company per distinct manager (slugged), typed from the funds
-- it manages. Insurers are seeded later (0009).
insert into public.companies (id, name, type)
select
  trim(both '-' from regexp_replace(lower(manager), '[^a-z0-9]+', '-', 'g')) as id,
  min(manager)                                                              as name,
  case
    when bool_or(category = 'sacco')            then 'sacco'
    when bool_or(manager ilike '%central bank%') then 'government'
    else 'fund_manager'
  end as type
from public.funds
where coalesce(manager, '') <> ''
group by trim(both '-' from regexp_replace(lower(manager), '[^a-z0-9]+', '-', 'g'))
on conflict (id) do nothing;

update public.funds f
set company_id =
  trim(both '-' from regexp_replace(lower(f.manager), '[^a-z0-9]+', '-', 'g'))
where f.company_id is null and coalesce(f.manager, '') <> '';

-- RLS: public read (parity with funds; app reads via snapshot anyway).
alter table public.companies enable row level security;
create policy companies_public_read on public.companies
  for select to anon, authenticated using (true);

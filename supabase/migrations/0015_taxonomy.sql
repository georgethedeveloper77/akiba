-- 0015_taxonomy.sql
-- Real Kenyan fund taxonomy. Extends the fund category set and adds a manager
-- class to companies (bank-owned / insurance-owned / independent / specialised).
--
-- Note: the APP must know how to label/colour a new category before funds start
-- carrying it (else the tile has no label). Import equity/balanced/islamic/reit
-- only after the app category update ships (import-cma.ts --full).

alter table public.funds drop constraint if exists funds_category_check;
alter table public.funds add constraint funds_category_check
  check (category in (
    'mmf_kes','mmf_usd','bond','tbill','sacco','stock','insurance',
    'balanced','equity','islamic','reit'
  ));

alter table public.companies
  add column if not exists manager_class text not null default 'independent'
    check (manager_class in ('bank','insurance','independent','specialized','government'));

comment on column public.companies.manager_class is
  'bank | insurance | independent | specialized | government — how the manager is owned/classified.';

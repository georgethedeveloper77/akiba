-- 0008_agents.sql
-- Company agents (and free agents that map to many companies) for the
-- call/WhatsApp CTAs on the company page.

create table public.agents (
  id         text primary key,
  name       text not null,
  role       text,
  phone      text,
  whatsapp   boolean not null default false,
  photo_url  text,
  active     boolean not null default true,
  is_free    boolean not null default false,    -- independent agent
  updated_at timestamptz not null default now()
);

create trigger agents_touch_updated_at
  before update on public.agents
  for each row execute function public.touch_updated_at();

-- Many-to-many: a free agent maps to several companies.
create table public.agent_companies (
  agent_id   text not null references public.agents(id)    on delete cascade,
  company_id text not null references public.companies(id) on delete cascade,
  primary key (agent_id, company_id)
);
create index agent_companies_company_idx on public.agent_companies (company_id);

alter table public.agents          enable row level security;
alter table public.agent_companies enable row level security;

-- Only active agents are publicly visible.
create policy agents_public_read on public.agents
  for select to anon, authenticated using (active);
create policy agent_companies_public_read on public.agent_companies
  for select to anon, authenticated using (true);

-- 0041_insurance_types.sql
-- Admin-managed insurance types for the Insure home grid. Each row is one card:
-- a key, a display label, a material icon name (mapped app-side, never emoji),
-- a live/soon status, an order, and an optional static subtitle. Motor and
-- Travel route to live comparison flows in the app; any other key renders as a
-- coming-soon card until its pricing model lands.

create table if not exists insurance_types (
  key    text primary key,                       -- 'motor','travel','life','medical',...
  label  text not null,
  icon   text,                                    -- material icon name (app-side map)
  status text not null default 'soon',            -- 'live' | 'soon'
  ord    integer not null default 0,
  sub    text,                                    -- optional static subtitle override
  active boolean not null default true
);

-- Seed the two flows the app can actually price today. Idempotent.
insert into insurance_types (key, label, icon, status, ord) values
  ('motor',  'Motor',  'motor',  'live', 0),
  ('travel', 'Travel', 'travel', 'live', 1)
on conflict (key) do nothing;

comment on table insurance_types is 'Cards on the Insure home grid. Motor/travel route to live flows; other keys show as coming-soon.';
comment on column insurance_types.status is 'live = has a comparison flow; soon = coming-soon card.';
comment on column insurance_types.icon is 'Material icon name resolved app-side (motor, travel, life, medical, home, business, marine, ...).';

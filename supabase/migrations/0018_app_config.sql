-- V6: remote config. Key/value jsonb published inside the snapshot as
-- `config`, so admin edits reach every device on the next pipeline run —
-- no app release, no extra fetch, works with the on-device/no-login model.
create table if not exists app_config (
  key         text primary key,
  value       jsonb not null,
  description text,
  updated_at  timestamptz not null default now()
);

alter table app_config enable row level security;
-- service-role only (admin server actions + publish-snapshot); no anon access.

-- Seeds: current baked-in copy, so admin starts from the shipped strings.
insert into app_config (key, value, description) values
  ('onboarding.headline', '"We watch the rates\nso you don''t"',
   'Onboarding alerts scene — headline (\n for line break)'),
  ('onboarding.body',
   '"Get a nudge when a money-market rate moves, a T-bill auction prints, or one of your saved comparisons flips its leader."',
   'Onboarding alerts scene — body'),
  ('onboarding.cta', '"Turn on alerts"', 'Onboarding — primary button'),
  ('onboarding.later', '"Maybe later"', 'Onboarding — skip button'),
  ('learn.card.title', '"Learn"', 'Settings Learn card — title'),
  ('learn.card.subtitle', '"MMFs, gross vs net, why rates move · **soon**"',
   'Settings Learn card — subtitle (**bold** renders accent)')
on conflict (key) do nothing;

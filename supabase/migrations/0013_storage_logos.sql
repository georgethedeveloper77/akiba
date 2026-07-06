-- 0013_storage_logos.sql
-- Public storage for manually-curated brand assets. One `logos` bucket keyed
-- by category folder (funds/ insurance/ sacco/ gvt/ …), plus a `favicons`
-- bucket. Public read; admin uploads use the service role (bypasses RLS).
-- (Articles for D2 move to 0014.)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('logos', 'logos', true, 2097152,
     array['image/png','image/jpeg','image/webp','image/svg+xml']),
  ('favicons', 'favicons', true, 1048576,
     array['image/png','image/x-icon','image/svg+xml','image/webp'])
on conflict (id) do nothing;

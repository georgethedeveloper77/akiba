-- 0005_snapshot_bucket.sql
-- Public bucket that holds funds-snapshot.json — the static file the app reads
-- cache-first instead of querying the DB on every open. Public = world-readable
-- over the CDN URL; writes stay service-role only (publish-snapshot bypasses RLS).

insert into storage.buckets (id, name, public)
values ('snapshots', 'snapshots', true)
on conflict (id) do update set public = true;

-- Public read URL once published:
--   https://lxtyrtgyfrhxyjraroku.supabase.co/storage/v1/object/public/snapshots/funds-snapshot.json

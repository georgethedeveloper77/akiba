-- 0025_scraper_run_trigger.sql
-- Record whether each aggregator run was fired by pg_cron or by the admin's
-- manual "Re-run", so the Scrapers page can show it and base its health check
-- on scheduled runs only.
--
-- History note: this was originally drafted as 0024 but that version number
-- collided with a stray 0024_reschedule_cron.sql. It lives at 0025 now.
-- Idempotent: safe even if the column was already added by hand during repair.

alter table scraper_runs
  add column if not exists trigger text not null default 'cron';

-- Existing rows default to 'cron'; no backfill needed.

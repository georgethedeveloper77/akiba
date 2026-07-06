-- 0016_reschedule_cron.sql
-- Kenyan MMF rates publish mid-morning–noon EAT. 03:00 UTC (06:00 EAT) ran
-- before they update, so it captured stale figures. Move the daily aggregator
-- run to 13:00 UTC (16:00 EAT), safely after updates. Only the schedule
-- changes; the job's HTTP command is untouched.
select cron.alter_job(
  (select jobid from cron.job where command ilike '%scrape-aggregator%' limit 1),
  schedule => '0 13 * * *'
);

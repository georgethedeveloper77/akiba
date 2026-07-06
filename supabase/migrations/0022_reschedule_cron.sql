-- Reschedule the aggregator to 09:00 UTC (12:00 EAT), weekdays only.
-- 03:00 UTC was before managers post the day's yields; noon EAT is late enough,
-- and fund yields don't move on weekends. Matched by command so the job name
-- doesn't matter.
do $$
declare jid bigint;
begin
  select jobid into jid from cron.job where command ilike '%scrape-aggregator%' limit 1;
  if jid is null then
    raise notice 'no scrape-aggregator cron job found — check migrations/0004_cron.sql';
  else
    perform cron.alter_job(job_id := jid, schedule := '0 9 * * 1-5');
    raise notice 'rescheduled job % to 0 9 * * 1-5 (09:00 UTC weekdays)', jid;
  end if;
end $$;

select jobid, jobname, schedule, active
from cron.job where command ilike '%scrape-aggregator%';

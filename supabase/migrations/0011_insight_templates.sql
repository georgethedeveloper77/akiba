-- 0011_insight_templates.sql
-- Template bank for the Signals engine. Seeded from the app's built-in bank so
-- app and DB agree; editable in the admin without an app release. The app
-- picks deterministically per fund per day; this table only supplies phrasings.

create table public.insight_templates (
  id       bigint generated always as identity primary key,
  key      text not null,                        -- condition key (17 at launch)
  tag      text not null check (tag in ('STRENGTH','WATCH','NOTE')),
  template text not null,                         -- may contain {n}{r}{net}{min}{fee}{d}{liq}{tb}{cp} + <b>
  active   boolean not null default true,
  unique (key, template)
);
create index insight_templates_key_idx on public.insight_templates (key) where active;

alter table public.insight_templates enable row level security;
create policy insight_templates_public_read on public.insight_templates
  for select to anon, authenticated using (active);

insert into public.insight_templates (key, tag, template) values
('upBig','STRENGTH',$t${n} jumped <b>{d} pts this week</b> — the sharpest move in its class.$t$),
('upBig','STRENGTH',$t$A <b>+{d} pt week</b> puts {n} among the market's fastest risers.$t$),
('upBig','STRENGTH',$t$Momentum is with {n}: <b>up {d} pts in 7 days</b>, well past the pack.$t$),
('upSmall','STRENGTH',$t${n} drifted up {d} pts this week — steady, in line with the sector.$t$),
('upSmall','STRENGTH',$t$A quiet +{d} pt week for {n}; the whole class is grinding higher.$t$),
('upSmall','STRENGTH',$t${n} added {d} pts over 7 days — nothing dramatic, direction is right.$t$),
('downBig','WATCH',$t${n} shed <b>{d} pts this week</b> — repricing faster than peers after the CBK move.$t$),
('downBig','WATCH',$t$A <b>−{d} pt week</b>: {n} is absorbing the base-rate trim ahead of the pack.$t$),
('downSmall','NOTE',$t${n} eased {d} pts as older high-coupon paper matured. Nothing structural.$t$),
('downSmall','NOTE',$t$A soft −{d} pt week for {n}; normal churn, not a trend break.$t$),
('flat','NOTE',$t${n} has held {r}% steady — low drama, and that's the point of this instrument.$t$),
('flat','NOTE',$t$No movement at {n} this week; the rate is pinned at {r}%.$t$),
('top1','STRENGTH',$t$Highest gross yield in its class right now at <b>{r}%</b> ({net}% net).$t$),
('top1','STRENGTH',$t$Leads its category: <b>{r}%</b> gross, {net}% after tax — top of the table.$t$),
('liqFast','STRENGTH',$t$Liquidity is the edge: <b>{liq}</b> — fastest access in the peer set.$t$),
('liqFast','STRENGTH',$t$<b>{liq}</b> — near-instant access most rivals can't match.$t$),
('minLow','STRENGTH',$t$Entry from just <b>{min}</b> — the most accessible ticket in the class.$t$),
('minLow','STRENGTH',$t$A <b>{min}</b> minimum makes this the easiest first position here.$t$),
('minHigh','WATCH',$t$Entry needs <b>KES {min}</b> — the steepest minimum in the set.$t$),
('minHigh','WATCH',$t$The <b>KES {min}</b> ticket prices out smaller savers; the yield is the compensation.$t$),
('feeHigh','WATCH',$t$Management fee of <b>{fee}</b> runs above the 2.00% peer norm — it eats into the net.$t$),
('feeHigh','WATCH',$t$Watch the <b>{fee}</b> fee: higher than peers, and it compounds against you.$t$),
('taxfree','STRENGTH',$t$Coupon is <b>tax-free</b> — the effective yield beats taxed paper by roughly 3 pts.$t$),
('taxfree','STRENGTH',$t$No withholding tax here: the {r}% you see is closer to what you keep.$t$),
('tbillHeavy','NOTE',$t$<b>{tb}% of the book is T-bills</b> — riding elevated auction rates while they last.$t$),
('tbillHeavy','NOTE',$t$A T-bill-heavy book ({tb}%) tracks the auctions closely, up and down.$t$),
('corpHeavy','WATCH',$t$<b>{cp}% corporate paper</b> — pays a premium over peers but adds credit exposure.$t$),
('corpHeavy','WATCH',$t$The {cp}% corporate slice is why the yield is fat; it's also where the risk lives.$t$),
('usd','NOTE',$t$Earns in dollars and tracks US short rates, not CBK — a hedge as much as a yield.$t$),
('sacco','WATCH',$t$Payouts are <b>annual, declared at the AGM</b> — not a daily-accruing rate like an MMF.$t$),
('bondLock','NOTE',$t$Money is locked to maturity; secondary exit exists but is price-sensitive.$t$)
on conflict (key, template) do nothing;

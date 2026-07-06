-- Insight bank: composition + manager-position keys unlocked by the CMA CIS
-- data (0017 funds.composition + companies.aum_kes/market_share). Additive —
-- phrasings only; the engine gains the conditions (see INSIGHT_KEYS_SPEC.md).
-- Deterministic per fund/day pick already rotates multiple phrasings per key.
--
-- New tokens the engine must fill (all optional per key):
--   {gok} govt-paper %   {dep} cash+deposit %   {off} offshore %
--   {unl} unlisted %     {top} top-class %      {topName} top-class label
--   {rank} manager rank  {aum} manager AUM short (e.g. "KES 103.2B")
-- Existing tokens ({r} {net} {d} {min} {fee} {liq} {tb} {cp} {n}) unchanged.
-- Bold uses <b>…</b> to match the existing 17 keys.

insert into insight_templates (key, tag, template, active) values
  -- ── composition (per fund, from funds.composition) ──────────────────────
  ('gokHeavy','NOTE','<b>{gok}%</b> sits in government securities — T-bills, bonds and infrastructure paper carry sovereign backing.',true),
  ('gokHeavy','NOTE','Government paper makes up <b>{gok}%</b> of the book, the lowest-risk slice of the fixed-income market.',true),

  ('depositHeavy','NOTE','Held mostly in cash and fixed deposits (<b>{dep}%</b>) — steady, though returns track what banks are paying.',true),
  ('depositHeavy','NOTE','<b>{dep}%</b> is parked in bank deposits, so the yield leans on deposit rates rather than the bond market.',true),

  ('offshoreEx','NOTE','<b>{off}%</b> is invested offshore — a slice of currency and global-market exposure.',true),
  ('offshoreEx','WATCH','Around <b>{off}%</b> sits in offshore assets; returns will move with the shilling as well as the market.',true),

  ('unlistedEx','WATCH','<b>{unl}%</b> is in unlisted securities — higher yield potential, but harder to price and exit.',true),
  ('unlistedEx','WATCH','A notable <b>{unl}%</b> is unlisted; that lifts yield but adds liquidity and transparency risk.',true),

  ('concentrated','WATCH','Concentrated: <b>{top}%</b> of the fund is a single asset class ({topName}).',true),
  ('concentrated','WATCH','One class — {topName} — carries <b>{top}%</b> of the book, so its fortunes drive the fund.',true),

  ('diversified','STRENGTH','Well spread across asset classes — no single holding dominates the book.',true),
  ('diversified','STRENGTH','Balanced mix of government paper, deposits and securities — diversification is doing its job here.',true),

  -- ── manager position (from companies.aum_kes / market_share) ────────────
  ('mgrTop','STRENGTH','Run by a top-<b>{rank}</b> manager by assets under management.',true),
  ('mgrTop','STRENGTH','Among the largest houses in the market — ranked #<b>{rank}</b> by AUM.',true),

  ('mgrBig','NOTE','The manager oversees <b>{aum}</b> across its funds.',true),
  ('mgrBig','NOTE','Backed by a sizeable book — <b>{aum}</b> under management.',true)
on conflict (key, template) do nothing;

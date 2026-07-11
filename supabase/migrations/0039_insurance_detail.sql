-- 0039_insurance_detail.sql
-- Detail fields for the IN-3 Insure surface (funds rows, kind='insurance').
-- Feeds the insurer detail screen (trust strip, contact grid, licensed classes,
-- objective signals) and the region-priced travel flow. All nullable, so a
-- motor-only or travel-only insurer serialises fine. Reuses the funds table via
-- the kind filter, consistent with the existing insurer columns (0009 / 0014).
-- New columns only; nothing existing is altered or dropped.

alter table funds
  add column if not exists settle_pct     numeric,   -- IRA claims-paid %, trust strip
  add column if not exists licensed_since integer,   -- year licensed, drives the "N yrs" meta
  add column if not exists phone          text,      -- contact grid: Call
  add column if not exists whatsapp       text,      -- contact grid: WhatsApp (wa.me)
  add column if not exists email          text,      -- contact grid: Email (mailto:)
  add column if not exists paybill        text,      -- contact grid: Paybill number
  add column if not exists website        text,      -- contact grid: Website
  add column if not exists brand_color    text,      -- per-insurer tint (logo + detail glow)
  add column if not exists classes        jsonb,     -- IRA authorized classes: [{code,label}]
  add column if not exists signals        jsonb,     -- objective signals: [{tag,label,text}], tag in STRENGTH|WATCH|NOTE
  add column if not exists travel_regions jsonb,     -- region base price per traveller: {ea,af,ww,sch}
  add column if not exists travel_cover   text;      -- headline cover, e.g. "KES 5M med"

comment on column funds.settle_pct is 'Insurer claims-paid percentage from IRA returns; trust strip only.';
comment on column funds.classes is 'IRA authorized insurance classes for the detail chips: array of {code,label}.';
comment on column funds.signals is 'Objective, editor-written signals for the detail screen: array of {tag,label,text} with tag in STRENGTH|WATCH|NOTE.';
comment on column funds.travel_regions is 'Base per-traveller price by region for a standard (<=7 day) trip: {ea,af,ww,sch}. App scales by trip length and traveller count.';

-- 0053_brokers.sql
--
-- CMA-licensed firms a retail investor can actually buy NSE shares through.
--
-- Source: the CMA's own live licensee register, read 12 July 2026.
--   Stockbrokers    licensees.cma.or.ke/licenses/4
--   Investment banks licensees.cma.or.ke/licenses/3   (these broker equities too)
--
-- Every name, licence number and website below is copied from that register.
-- Nothing is invented. Where the register carries no website, website is null:
-- a broker with no link renders without one rather than with a guessed URL.
--
-- ── WHY BOTH LISTS ─────────────────────────────────────────────────────────
-- "Stockbroker" and "investment bank" are two CMA licence classes, and both can
-- execute equity trades for you. Showing only licences/4 would hide Dyer and
-- Blair, SBG, Sterling and Standard Investment Bank, which is most of where
-- retail volume actually goes. AIB-AXYS holds BOTH licences (141 as a
-- stockbroker, 260 as an investment bank) and appears once, under the broker
-- licence it has held longest.
--
-- ── THIS REGISTER MOVES ────────────────────────────────────────────────────
-- Green Margin Capital was licensed in February 2026. AIB-AXYS was upgraded to
-- an investment bank in May 2026. Firms are licensed and de-licensed regularly.
-- Re-read the register once a quarter. A de-licensed broker left in this table
-- is Fructa pointing a user at a firm the regulator has removed, which is the
-- worst thing this table could do.
--
-- blurb, phone, email and logo_url are left NULL throughout. The CMA register
-- does not carry them, and this is not a table to fill with plausible guesses:
-- a wrong phone number on a page about where to send money is not a cosmetic
-- error. Fill them from each firm's own site, verified, or leave them empty.

insert into public.brokers (id, name, license_no, website, sort_order) values
  -- Stockbrokers (CMA licences/4)
  ('abc-capital',            'ABC Capital',                          '013', 'https://www.abccapital.co.ke/',       10),
  ('aib-axys-africa',        'AIB-AXYS Africa',                      '141', 'https://www.aib-axysafrica.com/',     11),
  ('francis-drummond',       'Francis Drummond and Company',         '016', 'https://drummond.co.ke/',             12),
  ('kingdom-securities',     'Kingdom Securities',                   '018', 'https://kingdomsecurities.co.ke/',    13),
  ('oms-africa',             'OMS Africa (Old Mutual Securities)',   '020', 'https://www.oldmutual.co.ke/',        14),
  ('suntra-investments',     'Suntra Investments',                   '022', 'https://suntra.co.ke/',               15),
  ('efg-hermes-kenya',       'EFG Hermes Kenya',                     '105', 'https://www.efghermes.com/en/kenya',  16),
  ('kestrel-capital',        'Kestrel Capital (East Africa)',        '136', 'https://www.kestrelcapital.com/',     17),
  ('spk-investment',         'SPK Investment Services',              '176', null,                                  18),
  ('green-margin-capital',   'Green Margin Capital',                 '253', 'http://www.greenmargincapital.com',   19),

  -- Investment banks (CMA licences/3). Same market, different licence class.
  ('absa-securities',        'ABSA Securities',                      '002', 'https://www.absabank.co.ke/personal/',                     30),
  ('dyer-and-blair',         'Dyer and Blair Investment Bank',       '004', 'https://www.dyerandblair.com/',                            31),
  ('equity-investment-bank', 'Equity Investment Bank',               '005', 'https://equitygroupholdings.com/ke/investor-relations/',   32),
  ('faida-investment-bank',  'Faida Investment Bank',                '006', 'https://fib.co.ke/',                                       33),
  ('genghis-capital',        'Genghis Capital',                      '007', 'https://www.genghis-capital.com/',                         34),
  ('kcb-investment-bank',    'KCB Investment Bank',                  '008', 'https://ke.kcbgroup.com/for-you/investments',              35),
  ('ncba-investment-bank',   'NCBA Investment Bank',                 '009', null,                                                       36),
  ('sbg-securities',         'SBG Securities',                       '011', 'https://www.sbgsecurities.co.ke/sbgsecurities/securities', 37),
  ('standard-investment-bank','Standard Investment Bank',            '012', 'https://www.sib.co.ke/mansa-x/',                           38),
  ('sterling-capital',       'Sterling Capital',                     '021', 'https://sterlingib.com/',                                  39),
  ('dry-associates',         'Dry Associates Investment Bank',       '114', 'https://www.dryassociates.com/about/',                     40),
  ('salaam-investment-bank', 'Salaam Investment Bank Kenya',         '115', 'https://salaaminvestments.com/',                           41),
  ('gulfcap-investment-bank','Gulfcap Investment Bank',              '170', 'https://gcib.africa/',                                     42),
  ('investcent',             'Investcent Investment Bank',           '187', 'https://www.investcent.co/',                               43),
  ('victoria-wealth',        'Victoria Wealth Management',           '241', 'https://www.victoriabank.co.ke/',                          44),
  ('rock-investment-bank',   'Rock Investment Bank',                 '230', 'https://rockadvisors.org/',                                45),
  ('fintrust-securities',    'Fintrust Securities',                  '258', 'https://www.fintrustsecurities.co.ke/',                    46),
  ('cinemark-investment-bank','Cinemark Investment Bank',            '264', 'http://www.cinemarkconsult.com/',                          47)
on conflict (id) do update set
  name       = excluded.name,
  license_no = excluded.license_no,
  website    = excluded.website,
  sort_order = excluded.sort_order,
  active     = true,
  updated_at = now();

-- ── HOW TO BUY ─────────────────────────────────────────────────────────────
-- Admin-editable copy for the "Where to buy" section. This is a route, not a
-- recommendation: Fructa never places a trade and never names a best broker.
--
-- The CDS-account line is no longer the whole story. In February 2026 Safaricom
-- and the NSE launched Ziidi Trader inside M-Pesa, under CMA oversight, which
-- lets a user buy listed shares from the phone WITHOUT opening a separate CDS
-- account, starting at a single share. For most Kenyan retail users that is now
-- the first door, and a "how to buy" screen that opens with "visit a broker and
-- open a CDS account" is describing the harder path as though it were the only
-- one. Both routes stay: M-Pesa for a first share, a broker for a full
-- brokerage relationship, research and larger orders.

insert into public.app_config (key, value) values
  ('stocks.how_to_buy_title',
   '"How to buy shares"'::jsonb),
  ('stocks.how_to_buy_body',
   '"You can buy NSE-listed shares in two ways. Ziidi Trader inside M-Pesa lets you buy from your phone without opening a separate CDS account, starting from a single share. Or open a CDS account with any CMA-licensed broker below for a full brokerage relationship, research and larger orders. Fructa does not place trades and does not recommend a broker."'::jsonb),
  ('stocks.brokers_note',
   '"Every firm listed is licensed by the Capital Markets Authority. The register changes, so check licensees.cma.or.ke before you open an account."'::jsonb)
on conflict (key) do update set value = excluded.value;

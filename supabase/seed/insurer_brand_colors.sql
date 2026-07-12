-- Insurer brand colours.
--
-- WHY EVERYTHING IS BLUE RIGHT NOW
--
--   Color insurerBrand(BuildContext context, Insurer i) =>
--       hexColor(i.brandColor) ?? categoryColor('insurance');
--
-- funds.brand_color is NULL on all 38 insurers, so every one of them falls
-- through to the generic 'insurance' category colour. That is why the peer
-- ranking bars, the sticky quote CTA and the logo-wall monograms are all the
-- same blue, and why CIC renders blue rather than its actual red.
--
-- Every hex below is COPIED from a companies row that already exists in this
-- database, for a company in the same brand family. Nothing here is invented,
-- sampled from a website, or eyeballed from a logo. An insurer whose brand
-- colour is not already in the DB is left NULL on purpose: it keeps the
-- fallback, which is honest, rather than getting a colour I guessed.

begin;

-- ── Verified sibling brands ───────────────────────────────────────────────
-- Read as: <insurer>  <-  <companies row the hex comes from>

update funds set brand_color = '#0177be'   -- britam-asset-managers
where id = 'britam-general' and kind = 'insurance';

update funds set brand_color = '#ac1f2d'   -- cic-asset-management
where id = 'cic-general' and kind = 'insurance';

update funds set brand_color = '#039775'   -- old-mutual-investment-group
where id = 'old-mutual-general' and kind = 'insurance';

update funds set brand_color = '#013380'   -- sanlam-investments-east-africa
where id = 'sanlam-allianz-general' and kind = 'insurance';

update funds set brand_color = '#ba0d2f'   -- jubilee-unit-trust-collective-investment
where id = 'jubilee-health' and kind = 'insurance';

update funds set brand_color = '#032d6c'   -- madison-investment-managers
where id = 'madison-general' and kind = 'insurance';

-- APA and Apollo are the same house: the `apollo` company row's own website is
-- apainsurance.org, which is the tell.
update funds set brand_color = '#103962'   -- apollo
where id = 'apa-insurance' and kind = 'insurance';

-- Likewise Orient: the `orient-umbrella-...` company row points at
-- orientlife.co.ke.
update funds set brand_color = '#19286c'   -- orient-umbrella-collective-investment-scheme...
where id = 'kenya-orient' and kind = 'insurance';

update funds set brand_color = '#a32a29'   -- equity-investment-bank-collective-investment
where id in ('equity-general', 'equity-health') and kind = 'insurance';

update funds set brand_color = '#38302e'   -- ncba-unit-trust-funds
where id = 'ncba-insurance' and kind = 'insurance';

commit;

-- ── What is deliberately NOT set, and why ─────────────────────────────────
--
-- ICEA LION      icea-lion-asset-management carries NO brand_color and no
--                logo_url. The separate `icea` company row has #0f67c5, but its
--                website is sc.com/ke (Standard Chartered), so that row's colour
--                cannot be trusted for ICEA LION. Left NULL rather than shipping
--                a colour sourced from a row that is visibly wrong.
--
-- Mayfair        mayfair-umbrella-collective-investment has a logo but
--                brand_color is NULL. Nothing to copy.
--
-- The other 25   AAR, Amaco, Cannon, Definite, Directline, Fidelity Shield,
--                First Assurance, GA, Geminia, Heritage, Intra Africa, Kenindia,
--                Kenyan Alliance, Monarch, MUA, Occidental, Pacis, Pioneer,
--                Star Discover, Takaful, Tausi, Bupa, and the three under
--                statutory management have no sibling company row at all.
--
-- To fix those properly, upload each logo to the `logos` bucket and set
-- companies.brand_color, or set funds.logo_domain so the favicon resolves.
-- Seven insurers already have logo_domain (aar-insurance.com, apainsurance.org,
-- directline.co.ke, gainsuranceltd.com, jubileeinsurance.com, oldmutual.co.ke,
-- pioneerassurance.co.ke) and those already render a real mark. The rest fall
-- back to a monogram, which is CORRECT behaviour and not a bug.

-- Verify:
--   select id, name, brand_color, logo_domain, company_id
--   from funds where kind = 'insurance' order by brand_color nulls last, name;

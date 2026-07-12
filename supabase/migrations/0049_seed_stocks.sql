-- 0049_seed_stocks.sql
--
-- The 62 ordinary shares listed on the NSE, with ticker, name and sector.
--
-- What is here: company identity. Which companies exist, what they are called,
-- what they do. This is public information and Fructa is free to publish it.
--
-- What is NOT here, deliberately: price, volume, day change. Those are NSE
-- market data and require an NSE redistribution licence, which also covers
-- derived values such as a sparkline or a computed dividend yield. They live
-- in stock_prices, which stays empty until a licence exists, and publish-
-- snapshot emits no price field while stocks.prices_enabled is false.
--
-- Also NOT here: `segment` (MIM / AIM / GEMS). The sector for each company is
-- from the NSE register and is reliable. Per-company segment assignments are
-- not, and inventing them would put wrong facts on a screen whose whole job is
-- teaching people the difference between these listings. Nothing renders
-- segment today, so nothing is lost by leaving it null. Fill it when there is
-- a source.
--
-- Excluded (not company shares, so they do not belong in a list that teaches
-- "a share is a slice of a business"):
--   GLD, SMWF        exchange traded funds
--   KPLC-P4, KPLC-P7 preference shares
--   LAPR             real estate investment trust
--
-- Re-runnable: conflicts update the name and sector, so a later correction to
-- this file can simply be re-applied.

insert into public.stocks (id, ticker, name, sector) values
  ('eaagads-limited', 'EGAD', 'Eaagads Limited', 'Agricultural'),
  ('kapchorua-tea-company-limited', 'KAPC', 'Kapchorua Tea Company Limited', 'Agricultural'),
  ('kakuzi-limited', 'KUKZ', 'Kakuzi Limited', 'Agricultural'),
  ('limuru-tea-company-limited', 'LIMT', 'Limuru Tea Company Limited', 'Agricultural'),
  ('sasini-limited', 'SASN', 'Sasini Limited', 'Agricultural'),
  ('williamson-tea-kenya-limited', 'WTK', 'Williamson Tea Kenya Limited', 'Agricultural'),
  ('car-and-general-kenya-limited', 'CGEN', 'Car and General (Kenya) Limited', 'Automobiles and Accessories'),
  ('sameer-africa-plc', 'SMER', 'Sameer Africa Plc', 'Automobiles and Accessories'),
  ('absa-bank-kenya-plc', 'ABSA', 'Absa Bank Kenya Plc', 'Banking'),
  ('bk-group-plc', 'BKG', 'BK Group Plc', 'Banking'),
  ('co-operative-bank-of-kenya-limited', 'COOP', 'Co-operative Bank of Kenya Limited', 'Banking'),
  ('diamond-trust-bank-kenya-limited', 'DTK', 'Diamond Trust Bank Kenya Limited', 'Banking'),
  ('equity-group-holdings-plc', 'EQTY', 'Equity Group Holdings Plc', 'Banking'),
  ('hf-group-plc', 'HFCK', 'HF Group Plc', 'Banking'),
  ('iandm-group-plc', 'IMH', 'I&M Group Plc', 'Banking'),
  ('kcb-group-plc', 'KCB', 'KCB Group Plc', 'Banking'),
  ('ncba-group-plc', 'NCBA', 'NCBA Group Plc', 'Banking'),
  ('stanbic-holdings-plc', 'SBIC', 'Stanbic Holdings Plc', 'Banking'),
  ('standard-chartered-bank-kenya-limited', 'SCBK', 'Standard Chartered Bank Kenya Limited', 'Banking'),
  ('deacons-east-africa-plc', 'DCON', 'Deacons (East Africa) Plc', 'Commercial and Services'),
  ('homeboyz-entertainment-plc', 'HBE', 'Homeboyz Entertainment Plc', 'Commercial and Services'),
  ('kenya-airways-plc', 'KQ', 'Kenya Airways Plc', 'Commercial and Services'),
  ('longhorn-publishers-plc', 'LKL', 'Longhorn Publishers Plc', 'Commercial and Services'),
  ('nairobi-business-ventures-plc', 'NBV', 'Nairobi Business Ventures Plc', 'Commercial and Services'),
  ('nation-media-group-plc', 'NMG', 'Nation Media Group Plc', 'Commercial and Services'),
  ('wpp-scangroup-plc', 'SCAN', 'WPP ScanGroup Plc', 'Commercial and Services'),
  ('standard-group-plc', 'SGL', 'Standard Group Plc', 'Commercial and Services'),
  ('tps-eastern-africa-plc', 'TPSE', 'TPS Eastern Africa Plc', 'Commercial and Services'),
  ('uchumi-supermarket-plc', 'UCHM', 'Uchumi Supermarket Plc', 'Commercial and Services'),
  ('express-kenya-plc', 'XPRS', 'Express Kenya Plc', 'Commercial and Services'),
  ('arm-cement-plc', 'ARM', 'ARM Cement Plc', 'Construction and Allied'),
  ('bamburi-cement-plc', 'BAMB', 'Bamburi Cement Plc', 'Construction and Allied'),
  ('east-african-cables-plc', 'CABL', 'East African Cables Plc', 'Construction and Allied'),
  ('crown-paints-kenya-plc', 'CRWN', 'Crown Paints Kenya Plc', 'Construction and Allied'),
  ('east-african-portland-cement-plc', 'PORT', 'East African Portland Cement Plc', 'Construction and Allied'),
  ('kengen-plc', 'KEGN', 'KenGen Plc', 'Energy and Petroleum'),
  ('kenya-power-and-lighting-company-plc', 'KPLC', 'Kenya Power and Lighting Company Plc', 'Energy and Petroleum'),
  ('totalenergies-marketing-kenya-plc', 'TOTL', 'TotalEnergies Marketing Kenya Plc', 'Energy and Petroleum'),
  ('umeme-limited', 'UMME', 'Umeme Limited', 'Energy and Petroleum'),
  ('britam-holdings-plc', 'BRIT', 'Britam Holdings Plc', 'Insurance'),
  ('cic-insurance-group-plc', 'CIC', 'CIC Insurance Group Plc', 'Insurance'),
  ('jubilee-holdings-limited', 'JUB', 'Jubilee Holdings Limited', 'Insurance'),
  ('kenya-reinsurance-corporation-limited', 'KNRE', 'Kenya Reinsurance Corporation Limited', 'Insurance'),
  ('liberty-kenya-holdings-plc', 'LBTY', 'Liberty Kenya Holdings Plc', 'Insurance'),
  ('sanlam-kenya-plc', 'SLAM', 'Sanlam Kenya Plc', 'Insurance'),
  ('centum-investment-company-plc', 'CTUM', 'Centum Investment Company Plc', 'Investment'),
  ('home-afrika-limited', 'HAFR', 'Home Afrika Limited', 'Investment'),
  ('kurwitu-ventures-limited', 'KURV', 'Kurwitu Ventures Limited', 'Investment'),
  ('olympia-capital-holdings-plc', 'OCH', 'Olympia Capital Holdings Plc', 'Investment'),
  ('transcentury-plc', 'TCL', 'TransCentury Plc', 'Investment'),
  ('nairobi-securities-exchange-plc', 'NSE', 'Nairobi Securities Exchange Plc', 'Investment Services'),
  ('africa-mega-agricorp-plc', 'AMAC', 'Africa Mega Agricorp Plc', 'Manufacturing and Allied'),
  ('british-american-tobacco-kenya-plc', 'BAT', 'British American Tobacco Kenya Plc', 'Manufacturing and Allied'),
  ('boc-kenya-plc', 'BOC', 'BOC Kenya Plc', 'Manufacturing and Allied'),
  ('carbacid-investments-plc', 'CARB', 'Carbacid Investments Plc', 'Manufacturing and Allied'),
  ('east-african-breweries-plc', 'EABL', 'East African Breweries Plc', 'Manufacturing and Allied'),
  ('eveready-east-africa-plc', 'EVRD', 'Eveready East Africa Plc', 'Manufacturing and Allied'),
  ('flame-tree-group-holdings-plc', 'FTGH', 'Flame Tree Group Holdings Plc', 'Manufacturing and Allied'),
  ('mumias-sugar-company-limited', 'MSC', 'Mumias Sugar Company Limited', 'Manufacturing and Allied'),
  ('shri-krishana-overseas-plc', 'SKL', 'Shri Krishana Overseas Plc', 'Manufacturing and Allied'),
  ('unga-group-plc', 'UNGA', 'Unga Group Plc', 'Manufacturing and Allied'),
  ('safaricom-plc', 'SCOM', 'Safaricom Plc', 'Telecommunication')
on conflict (id) do update set
  ticker = excluded.ticker,
  name   = excluded.name,
  sector = excluded.sector;

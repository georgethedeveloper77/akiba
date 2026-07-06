// Source label (normalised) -> our funds.id.
//
// The `funds` table is the source of truth. This map only points at fund ids
// that already exist; anything a source lists that isn't mapped is returned as
// `unmapped` so the admin can add it. A scraper never invents a fund.
//
// Layers:
//   * short manager tokens  ("cic")               -> press / industry adapters
//   * official CMA names     ("cic money market fund") -> for existing funds
//   * Serrari casual labels  (SERRARI_KES_MMF_MAP) -> serrari-mmf adapter
//
// Official names + AUM are from the CMA CIS Quarterly Report (period ended
// 31 Mar 2026), Table 11. Full universe incl. unseeded funds lives in
// data/cma/mmf-registry-q1-2026.json.
//
// NOTE: KES and USD share manager tokens ("cytonn" in both). index.ts merges
// {...KES, ...USD} so USD wins shared tokens — fine for USD-tagged sources,
// wrong for a KES-only source. The Serrari /ke/mmf page is KES-only, so its
// adapter reads SERRARI_KES_MMF_MAP directly, not the merged map.
//
// FLAGGED: zimele-mmf-kes and sanlam-mmf-usd are kept from the original map,
// but the CMA report lists no MMF for Zimele and no Sanlam USD MMF. Confirm
// against the funds table; drop if they don't exist.

// KES: existing funds only (tokens + official names)
export const KES_MMF_NAME_MAP: Record<string, string> = {
  "cic": "cic-mmf-kes",
  "etica": "etica-mmf-kes",
  "cytonn": "cytonn-mmf-kes",
  "sanlam": "sanlam-mmf-kes",
  "old mutual": "oldmutual-mmf-kes",
  "britam": "britam-mmf-kes",
  "icea lion": "icealion-mmf-kes",
  "ncba": "ncba-mmf-kes",
  "madison": "madison-mmf-kes",
  "zimele": "zimele-mmf-kes",
  "co-op": "coop-mmf-kes",
  "kuza": "kuza-mmf-kes",
  "ncba money market (kes) fund": "ncba-mmf-kes",
  "kuza money market fund kes": "kuza-mmf-kes",
  "britam money market fund": "britam-mmf-kes",
  "madison money market fund": "madison-mmf-kes",
  "etica money market fund": "etica-mmf-kes",
  "sanlamallianz money market fund": "sanlam-mmf-kes",
  "cic money market fund": "cic-mmf-kes",
  "icea lion money market fund": "icealion-mmf-kes",
  "co-op money market fund": "coop-mmf-kes",
  "cytonn money market fund": "cytonn-mmf-kes",
  "old mutual money market fund": "oldmutual-mmf-kes",
};

// USD: existing funds only (tokens + official names)
export const USD_MMF_NAME_MAP: Record<string, string> = {
  "cytonn": "cytonn-mmf-usd",
  "etica": "etica-mmf-usd",
  "sanlam": "sanlam-mmf-usd",
  "etica money market fund -usd": "etica-mmf-usd",
  "cytonn money market fund usd": "cytonn-mmf-usd",
};

// Serrari casual label -> official KES name (existing funds only)
export const SERRARI_KES_MMF_MAP: Record<string, string> = {
  "sanlam": "SanlamAllianz Money Market Fund",
  "sanlam allianz": "SanlamAllianz Money Market Fund",
  "sanlamallianz": "SanlamAllianz Money Market Fund",
  "cic": "CIC Money Market Fund",
  "old mutual": "Old Mutual Money Market Fund",
  "oldmutual": "Old Mutual Money Market Fund",
  "co-op": "Co-op Money Market Fund",
  "coop": "Co-op Money Market Fund",
  "co op": "Co-op Money Market Fund",
  "icea lion": "ICEA LION Money Market Fund",
  "icea": "ICEA LION Money Market Fund",
  "icealion": "ICEA LION Money Market Fund",
  "icea-lion": "ICEA LION Money Market Fund",
  "britam": "Britam Money Market Fund",
  "etica": "Etica Money Market Fund",
  "madison": "Madison Money Market Fund",
  "kuza": "Kuza Money Market Fund KES",
  "cytonn": "Cytonn Money Market Fund",
  "ncba": "NCBA Money Market (KES) Fund",
};

// PENDING - not yet in `funds`. Seed each (see mmf-registry-q1-2026.json),
// confirm the id, then add its official name to KES_MMF_NAME_MAP and its
// aliases to SERRARI_KES_MMF_MAP. Until then these surface as `unmapped`.
//   "absa-mmf-kes"                   "ABSA Shilling Money Market Fund"  (absa)
//   "kcb-mmf-kes"                    "KCB Money Market Fund KES"  (kcb)
//   "ziidi-mmf-kes"                  "Ziidi Money Market Fund"  (ziidi)
//   "jubilee-mmf-kes"                "Jubilee Money Market Fund KES"  (jubilee)
//   "nabo-mmf-kes"                   "Nabo KES Money Market Fund"  (nabo)
//   "cpf-mmf-kes"                    "CPF Money Market Fund"  (cpf)
//   "genafrica-mmf-kes"              "GenAfrica Money Market Fund"  (genafrica)
//   "loftycorban-mmf-kes"            "Lofty Corban Money Market Fund"  (lofty corban)
//   "dryassociates-mmf-kes"          "Dry Associates Money Market Fund KES"  (dry associates)
//   "apollo-mmf-kes"                 "Apollo Money Market Fund"  (apollo)
//   "mali-mmf-kes"                   "Mali Money Market Fund"  (mali)
//   "stanbic-mmf-kes"                "Stanbic Money Market Fund"  (stanbic)
//   "enwealth-mmf-kes"               "Enwealth Money Market Fund"  (enwealth)
//   "arvocap-mmf-kes"                "Arvocap Money Market Fund"  (arvocap)
//   "gulfcap-mmf-kes"                "GCIB Money Market Fund"  (gulfcap)
//   "genghis-mmf-kes"                "Genghis Money Market Fund"  (genghis)
//   "mayfair-mmf-kes"                "Mayfair Money Market Fund"  (mayfair)
//   "orient-mmf-kes"                 "Orient Kasha Money Market Fund"  (orient kasha)
//   "faulu-mmf-kes"                  "Faulu Money Market Fund"  (faulu)
//   "taifa-mmf-kes"                  "Taifa Money Market Fund KES"  (taifa)
//   "ziidi-shariah-mmf-kes"          "Ziidi Shariah Money Market Fund"  (ziidi shariah)
//   "eib-mmf-kes"                    "EIB Money Market Fund"  (equity)
//   "amana-mmf-kes"                  "Amana Money Market Fund"  (amana)
//   "xeno-mmf-kes"                   "XENO Kenya Money Market Fund"  (xeno)

export function normalize(name: string): string {
  return name.trim().toLowerCase().replace(/\s+/g, " ");
}

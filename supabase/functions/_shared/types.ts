export interface RatePoint {
  fund_id: string;
  rate: number;      // gross effective annual yield, %
  as_of: string;     // YYYY-MM-DD (EAT day)
  source: string;    // scraper id
  source_url?: string;
}

// A source adapter is the ONLY place that knows a source's shape.
// It returns raw (name, rate) rows; mapping to fund_id happens upstream,
// so swapping sources never touches the pipeline.
export interface SourceRow {
  name: string;                 // fund/company name as the source labels it
  rate: number;                 // gross EAR, %
  currency: "KES" | "USD";
  asOf?: string;                // optional YYYY-MM-DD; overrides the run date
}

export interface SourceAdapter {
  id: string;
  fetchRows(): Promise<SourceRow[]>;
}

// ── Snapshot v2 shapes ─────────────────────────────────────────────────────
// v2 keeps every v1 field and adds companies/agents/insurers/fx/templates/
// events. The app reads `schema` and falls back to v1 when it's absent.

export interface SnapshotFund {
  id: string;
  name: string;
  manager: string;
  category: string;
  fund_type: string | null;   // mmf | fixed_income | equity | balanced | special
  currency: string;
  basis: string | null;       // yield | nav | none — drives whether a rate shows
  retail: boolean;            // consumer-visible cut
  current_rate: number | null;
  tax_free: boolean;
  min_invest: number | null;
  mgmt_fee: number | null;
  site_url: string | null;
  invest_url: string | null;
  contact_url: string | null;
  logo_domain: string | null;
  verified: boolean;
  featured: boolean;
  company_id: string | null;
}

export interface SnapshotCompany {
  id: string;
  name: string;
  type: string;                 // fund_manager | insurer | sacco | government
  brand_color: string | null;
  logo_url: string | null;
  website: string | null;
  verified: boolean;
  aum_kes: number | null;
  market_share: number | null;
  rank: number | null;
  aum_as_of: string | null;
}

export interface SnapshotAgent {
  id: string;
  name: string;
  role: string | null;
  phone: string | null;
  whatsapp: boolean;
  photo_url: string | null;
  is_free: boolean;
  company_ids: string[];
}

export interface SnapshotInsurer {
  id: string;
  name: string;
  company_id: string | null;
  currency: string;
  plans: unknown;               // [{name, basis, price}]
  min_premium: number | null;
  excess_pct: number | null;
  excess_min: number | null;
  claims_days: number | null;
  rating: number | null;
  logo_domain: string | null;
}

export interface SnapshotFx {
  pair: string;                 // 'USD/KES'
  rate: number;
  as_of: string;
}

export interface SnapshotTemplate {
  key: string;
  tag: "STRENGTH" | "WATCH" | "NOTE";
  template: string;
}

export interface SnapshotEvent {
  type: string;
  category: string | null;
  fund_id: string | null;
  payload: unknown;
  created_at: string;
}

export interface SnapshotV2 {
  schema: 2;
  as_of: string;
  funds: SnapshotFund[];
  insurers: SnapshotInsurer[];
  companies: SnapshotCompany[];
  agents: SnapshotAgent[];
  fx: SnapshotFx[];
  insight_templates: SnapshotTemplate[];
  events: SnapshotEvent[];
}

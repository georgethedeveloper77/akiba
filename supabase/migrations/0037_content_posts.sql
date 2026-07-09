-- 0037_content_posts.sql
-- Extend the EXISTING posts table (created in 0035_content.sql for the website
-- blog) into a unified content system that also feeds the app. A post is
-- authored once and surfaces on both the website blog and the app.
--
-- 0035 gave us: slug (PK), title, excerpt, body, cover_url, published (bool),
-- published_at, seo_title, seo_description, created_at, updated_at.
-- This adds the app/brief fields on top. Reuses excerpt (as summary) and
-- cover_url (as hero) rather than duplicating them.
--
-- `kind` splits 'article' (evergreen blog) from 'brief' (short, timely, the
-- curated news replacement). Existing rows default to 'article'. No news
-- scraper: briefs are authored in admin.
--
-- NOTE: 0035's comment called posts "web-only, kept out of the snapshot". That
-- changes here: the snapshot builder now publishes published posts so the app
-- blog can read them cache-first, exactly like learn.

alter table public.posts
  add column if not exists kind text not null default 'article'
    check (kind in ('article', 'brief')),
  add column if not exists author          text,
  add column if not exists tags            text[] not null default '{}',
  add column if not exists fund_id         text,   -- optional soft link (no FK)
  add column if not exists company_id      text,   -- optional soft link
  add column if not exists pinned          boolean not null default false,
  add column if not exists reading_minutes int;     -- articles only; null for briefs

create index if not exists posts_kind_idx    on public.posts (kind);
create index if not exists posts_pub_idx      on public.posts (published, published_at desc);
create index if not exists posts_fund_idx     on public.posts (fund_id);
create index if not exists posts_company_idx  on public.posts (company_id);
create index if not exists posts_tags_idx     on public.posts using gin (tags);

-- Bump updated_at on edit (0035 only set a default). Useful for the website
-- "last updated" stamp and cache reasoning.
create or replace function public.tg_posts_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists posts_set_updated_at on public.posts;
create trigger posts_set_updated_at
  before update on public.posts
  for each row execute function public.tg_posts_updated_at();

-- Sample rows (one article, one brief) so the app blog + briefs rail have
-- something to render. Uses the 0035 column shape. Delete freely.
insert into public.posts
  (slug, kind, title, excerpt, body, published, published_at, author, tags)
values
  (
    'what-the-15-percent-wht-really-costs-you',
    'article',
    'What the 15% Withholding Tax Really Costs You',
    'A KES 100,000 placement at 12% gross is not 12% in your pocket. Here is the arithmetic.',
    'Every money market fund advertises a gross yield. The number you actually earn is lower, because a 15% withholding tax is deducted at source before the interest reaches you.

Take KES 100,000 placed at a 12% gross annual yield. Gross interest is KES 12,000 over a year. The 15% tax removes KES 1,800, leaving KES 10,200 in your pocket. Your real, after-tax yield is 10.2%, not 12%.

This is why comparing funds on gross rate alone is misleading. A fund quoting 12.4% gross and one quoting 12.0% gross are only 34 basis points apart after tax, not 40. Always compare on net.',
    true,
    now(),
    'Fructa',
    array['tax', 'mmf', 'basics']
  ),
  (
    'cbk-holds-cbr-at-8-75',
    'brief',
    'CBK Holds the Central Bank Rate at 8.75%',
    'The Monetary Policy Committee left the benchmark unchanged on 9 June 2026, citing easing inflation.',
    'The Central Bank of Kenya''s Monetary Policy Committee kept the Central Bank Rate at 8.75% at its June meeting. Inflation printed at 6.7% for May, inside the target band. For money market fund holders, a stable CBR means fund yields are unlikely to move sharply in either direction over the coming weeks.',
    true,
    now(),
    'Fructa',
    array['cbk', 'rates']
  )
on conflict (slug) do nothing;

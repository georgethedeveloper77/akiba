# scrapers — browser-based (JS-gated sources)

Some sources (CBK) require JavaScript, so a plain fetch (Supabase edge
functions) can't read them. These use Playwright (a real headless browser)
and run on a GitHub Actions cron.

Runtime split:
- Server-rendered sources  -> supabase/functions (Deno edge functions)
- JS-gated / PDF sources    -> here (Playwright on GitHub Actions)

## Setup
1. Push the repo to GitHub (Actions needs it there).
2. Repo -> Settings -> Secrets and variables -> Actions, add:
   - SUPABASE_URL
   - SUPABASE_SERVICE_ROLE_KEY   (service role — full write; keep it a secret)
3. The workflow runs weekly (Thu) and via the manual "Run workflow" button.

## Run locally
```
cd scrapers
npm install && npx playwright install chromium
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node cbk-tbills.mjs
```

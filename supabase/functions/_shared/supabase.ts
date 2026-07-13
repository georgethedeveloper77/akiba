import { createClient } from "jsr:@supabase/supabase-js@2.85.0";

// Service-role client for edge functions. Bypasses RLS (server-side only).
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.
export function adminClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}
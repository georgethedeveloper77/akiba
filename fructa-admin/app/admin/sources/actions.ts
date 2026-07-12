"use server";

import { supabaseAdmin } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// Section-scoped writer: this form carries the two source links and nothing
// else, so it updates exactly those two columns. It never reads a field it does
// not own, which is what stops a save here from blanking a rate or a status.
//
// setRate and setSourceType stay in funds/actions.ts, where they already live.

export type Result = { ok: boolean; error: string | null };

const str = (fd: FormData, k: string) => String(fd.get(k) ?? "").trim();

function cleanUrl(v: string): string | null {
  if (!v) return null;
  return /^https?:\/\//i.test(v) ? v : `https://${v}`;
}

export async function updateSourceLinks(fd: FormData): Promise<Result> {
  const id = str(fd, "id");
  if (!id) return { ok: false, error: "Missing fund." };

  const { error } = await supabaseAdmin()
    .from("funds")
    .update({
      rate_source_url: cleanUrl(str(fd, "rate_source_url")),
      site_url: cleanUrl(str(fd, "site_url")),
    })
    .eq("id", id);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/admin/sources");
  return { ok: true, error: null };
}

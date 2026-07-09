"use server";

import { supabaseAdmin } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// Content = the website's legal/marketing pages (privacy, terms, …). The blog
// moved to its own route (/admin/blog); post + cover writes live in
// app/admin/blog/actions.ts now.

export type Result = { ok: boolean; error: string | null };

const str = (fd: FormData, k: string) => String(fd.get(k) ?? "").trim();
const body = (fd: FormData) => String(fd.get("body") ?? "");

export async function savePage(fd: FormData): Promise<Result> {
  const slug = str(fd, "slug");
  if (!slug) return { ok: false, error: "Missing page." };
  const { error } = await supabaseAdmin()
    .from("pages")
    .update({ title: str(fd, "title"), body: body(fd), updated_at: new Date().toISOString() })
    .eq("slug", slug);
  if (error) return { ok: false, error: error.message };
  revalidatePath("/admin/content");
  revalidatePath(`/${slug}`);
  return { ok: true, error: null };
}

"use server";

import { supabaseAdmin } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// Content = the website's legal and company pages (privacy, terms, about).
// The blog moved to its own route (/admin/blog); post and cover writes live in
// app/admin/blog/actions.ts.
//
// Each writer touches ONLY the columns its own form carries, so saving a body
// can never blank a title.

export type Result = { ok: boolean; error: string | null };

const str = (fd: FormData, k: string) => String(fd.get(k) ?? "").trim();
const body = (fd: FormData) => String(fd.get("body") ?? "");

const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

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

export async function createPage(fd: FormData): Promise<Result> {
  const slug = str(fd, "slug").toLowerCase();
  const title = str(fd, "title");

  if (!title) return { ok: false, error: "Give the page a title." };
  if (!SLUG_RE.test(slug)) {
    return { ok: false, error: "The slug should be lowercase words joined by hyphens, like cookie-policy." };
  }

  const db = supabaseAdmin();
  const { data: existing } = await db.from("pages").select("slug").eq("slug", slug).maybeSingle();
  if (existing) return { ok: false, error: `/${slug} already exists.` };

  const { error } = await db.from("pages").insert({
    slug,
    title,
    body: body(fd) || `## ${title}\n\n`,
    updated_at: new Date().toISOString(),
  });
  if (error) return { ok: false, error: error.message };

  revalidatePath("/admin/content");
  revalidatePath(`/${slug}`);
  return { ok: true, error: null };
}

export async function deletePage(fd: FormData): Promise<Result> {
  const slug = str(fd, "slug");
  if (!slug) return { ok: false, error: "Missing page." };

  const { error } = await supabaseAdmin().from("pages").delete().eq("slug", slug);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/admin/content");
  revalidatePath(`/${slug}`);
  return { ok: true, error: null };
}

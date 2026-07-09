"use server";

import { supabaseAdmin } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

export type Result = { ok: boolean; error: string | null };
export type CreateResult = { ok: boolean; error: string | null; slug?: string };

const str = (fd: FormData, k: string) => String(fd.get(k) ?? "").trim();
const strOrNull = (fd: FormData, k: string) => str(fd, k) || null;
const bodyOf = (fd: FormData) => String(fd.get("body") ?? "");

function slugify(s: string): string {
  return s.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

function parseTags(fd: FormData): string[] {
  const raw = String(fd.get("tags") ?? "");
  if (!raw) return [];
  try {
    const j = JSON.parse(raw);
    if (Array.isArray(j)) return j.map((s) => String(s).trim()).filter(Boolean).slice(0, 12);
  } catch {
    // fall through to CSV
  }
  return raw.split(",").map((s) => s.trim()).filter(Boolean).slice(0, 12);
}

function numOrNull(fd: FormData, k: string): number | null {
  const v = str(fd, k);
  if (!v) return null;
  const n = Number(v);
  return Number.isFinite(n) ? Math.round(n) : null;
}

function revalidatePost(slug?: string) {
  revalidatePath("/admin/blog");
  revalidatePath("/blog");
  if (slug) revalidatePath(`/blog/${slug}`);
}

// Kick the publish-snapshot edge function so app content (blog + briefs) updates
// within the snapshot cache window instead of waiting for the next scrape.
// Non-fatal by design: the DB write already succeeded, so a failed rebuild just
// means the app picks the change up at the next scheduled publish. If your admin
// "Rebuild snapshot" uses a different contract (x-cron-secret, a shared action),
// point me at it and I'll swap this one helper.
async function rebuildSnapshot(): Promise<void> {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) return;
  try {
    await fetch(`${url}/functions/v1/publish-snapshot`, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, apikey: key, "Content-Type": "application/json" },
      body: "{}",
    });
  } catch {
    // swallow — app stays on the last good snapshot until the next publish
  }
}

// ── Create ──────────────────────────────────────────────────────────────────
export async function createPost(fd: FormData): Promise<CreateResult> {
  const title = str(fd, "title");
  if (!title) return { ok: false, error: "Title is required." };
  const kind = str(fd, "kind") === "brief" ? "brief" : "article";
  const slug = slugify(str(fd, "slug") || title);
  if (!slug) return { ok: false, error: "Could not derive a slug." };
  const { error } = await supabaseAdmin().from("posts").insert({ slug, title, kind });
  if (error) {
    return { ok: false, error: error.message.includes("duplicate") ? "That slug already exists." : error.message };
  }
  revalidatePost(slug);
  return { ok: true, error: null, slug };
}

// ── Update (field-scoped) ───────────────────────────────────────────────────
// Never touches cover_url (upload owns it) or published (toggle owns it).
export async function updatePost(fd: FormData): Promise<Result> {
  const slug = str(fd, "slug");
  if (!slug) return { ok: false, error: "Missing post." };
  const kind = str(fd, "kind") === "brief" ? "brief" : "article";

  const patch: Record<string, unknown> = {
    title: str(fd, "title"),
    kind,
    excerpt: strOrNull(fd, "excerpt"),
    body: bodyOf(fd),
    tags: parseTags(fd),
    fund_id: strOrNull(fd, "fund_id"),
    company_id: strOrNull(fd, "company_id"),
    updated_at: new Date().toISOString(),
  };

  if (kind === "article") {
    patch.pinned = str(fd, "pinned") === "true";
    patch.reading_minutes = numOrNull(fd, "reading_minutes");
    patch.seo_title = strOrNull(fd, "seo_title");
    patch.seo_description = strOrNull(fd, "seo_description");
  } else {
    // Briefs carry none of the article-only fields; clear them so a converted
    // article doesn't leave a stale pin or reading time behind.
    patch.pinned = false;
    patch.reading_minutes = null;
  }

  const { error } = await supabaseAdmin().from("posts").update(patch).eq("slug", slug);
  if (error) return { ok: false, error: error.message };
  revalidatePost(slug);
  await rebuildSnapshot();
  return { ok: true, error: null };
}

export async function togglePostPublished(fd: FormData): Promise<Result> {
  const slug = str(fd, "slug");
  if (!slug) return { ok: false, error: "Missing post." };
  const publish = fd.get("value") === "true";
  const patch = publish
    ? { published: true, published_at: new Date().toISOString() }
    : { published: false };
  const { error } = await supabaseAdmin().from("posts").update(patch).eq("slug", slug);
  if (error) return { ok: false, error: error.message };
  revalidatePost(slug);
  await rebuildSnapshot();
  return { ok: true, error: null };
}

export async function togglePinned(fd: FormData): Promise<Result> {
  const slug = str(fd, "slug");
  if (!slug) return { ok: false, error: "Missing post." };
  const pinned = fd.get("value") === "true";
  const { error } = await supabaseAdmin().from("posts").update({ pinned }).eq("slug", slug);
  if (error) return { ok: false, error: error.message };
  revalidatePost(slug);
  await rebuildSnapshot();
  return { ok: true, error: null };
}

export async function deletePost(fd: FormData): Promise<Result> {
  const slug = str(fd, "slug");
  if (!slug) return { ok: false, error: "Missing post." };
  const { error } = await supabaseAdmin().from("posts").delete().eq("slug", slug);
  if (error) return { ok: false, error: error.message };
  revalidatePost(slug);
  await rebuildSnapshot();
  return { ok: true, error: null };
}

// ── Cover images (marketing bucket, blog/ folder) ───────────────────────────
const MIME_EXT: Record<string, string> = {
  "image/png": "png",
  "image/jpeg": "jpg",
  "image/webp": "webp",
};

export async function uploadPostCover(fd: FormData): Promise<Result> {
  const slug = str(fd, "slug");
  const file = fd.get("file") as File | null;
  if (!slug) return { ok: false, error: "Missing post." };
  if (!file || file.size === 0) return { ok: false, error: "No file selected." };
  if (file.size > 4 * 1024 * 1024) return { ok: false, error: "File is over 4 MB." };
  const ext = MIME_EXT[file.type];
  if (!ext) return { ok: false, error: "Use a PNG, JPG or WebP image." };

  const path = `blog/${slug}.${ext}`;
  const bytes = new Uint8Array(await file.arrayBuffer());
  const db = supabaseAdmin();
  const up = await db.storage.from("marketing").upload(path, bytes, { upsert: true, contentType: file.type });
  if (up.error) return { ok: false, error: `Storage: ${up.error.message}` };

  const { data } = db.storage.from("marketing").getPublicUrl(path);
  const url = `${data.publicUrl}?v=${Date.now()}`;
  const { error } = await db.from("posts").update({ cover_url: url }).eq("slug", slug);
  if (error) return { ok: false, error: error.message };
  revalidatePost(slug);
  await rebuildSnapshot();
  return { ok: true, error: null };
}

export async function removePostCover(fd: FormData): Promise<Result> {
  const slug = str(fd, "slug");
  const url = str(fd, "url");
  if (!slug) return { ok: false, error: "Missing post." };
  const db = supabaseAdmin();
  const marker = "/object/public/marketing/";
  const i = url.indexOf(marker);
  if (i >= 0) {
    const path = url.slice(i + marker.length).split("?")[0];
    await db.storage.from("marketing").remove([path]);
  }
  const { error } = await db.from("posts").update({ cover_url: null }).eq("slug", slug);
  if (error) return { ok: false, error: error.message };
  revalidatePost(slug);
  await rebuildSnapshot();
  return { ok: true, error: null };
}

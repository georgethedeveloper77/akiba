import { supabaseAdmin } from "@/lib/supabase/server";
import { BlogClient, type PostRow, type LinkOption } from "./BlogClient";

export const dynamic = "force-dynamic";

export default async function BlogPage() {
  const db = supabaseAdmin();
  const [{ data: posts }, { data: funds }, { data: companies }] = await Promise.all([
    db
      .from("posts")
      .select(
        "slug,kind,title,excerpt,body,cover_url,published,published_at,seo_title,seo_description,tags,fund_id,company_id,pinned,reading_minutes,updated_at",
      )
      .order("updated_at", { ascending: false }),
    db.from("funds").select("id,name").eq("kind", "fund").neq("status", "hidden").order("name"),
    db.from("companies").select("id,name").order("name"),
  ]);

  const links: LinkOption[] = [
    ...(funds ?? []).map((f) => ({ type: "fund" as const, id: f.id as string, name: f.name as string })),
    ...(companies ?? []).map((c) => ({ type: "company" as const, id: c.id as string, name: c.name as string })),
  ];

  return (
    <div className="mx-auto max-w-5xl">
      <header className="mb-5">
        <h1 className="text-2xl font-semibold tracking-tight">Blog</h1>
        <p className="mt-1 text-sm text-mute">
          Articles and briefs, authored once and read by both the website and the app. Publishing
          rebuilds the app snapshot. Bodies accept Markdown.
        </p>
      </header>
      <BlogClient posts={(posts ?? []) as PostRow[]} links={links} />
    </div>
  );
}

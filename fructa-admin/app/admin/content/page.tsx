import { supabaseAdmin } from "@/lib/supabase/server";
import { ContentClient, type PageRow } from "./ContentClient";

export const dynamic = "force-dynamic";

export default async function ContentPage() {
  const db = supabaseAdmin();
  const { data: pages } = await db.from("pages").select("slug,title,body,updated_at").order("slug");

  return (
    <div className="mx-auto max-w-6xl">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold tracking-tight">Pages</h1>
        <p className="mt-1 max-w-[70ch] text-sm text-mute">
          The website&apos;s legal and company pages. Markdown in, fructa.africa out, and saving
          publishes immediately. Articles and briefs live in{" "}
          <a href="/admin/blog" className="text-gold hover:underline">
            Blog
          </a>
          .
        </p>
      </header>
      <ContentClient pages={(pages ?? []) as PageRow[]} />
    </div>
  );
}

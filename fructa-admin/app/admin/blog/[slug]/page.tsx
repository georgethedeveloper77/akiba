import { supabaseAdmin } from "@/lib/supabase/server";
import { PostEditor, type PostRow } from "./PostEditor";

export const dynamic = "force-dynamic";

export default async function EditPostPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const db = supabaseAdmin();
  const { data } = await db
    .from("posts")
    .select("slug,title,excerpt,body,cover_url,published,published_at,seo_title,seo_description,updated_at")
    .eq("slug", slug)
    .maybeSingle();

  if (!data) {
    return (
      <div className="mx-auto max-w-3xl">
        <a href="/admin/blog" className="text-sm text-faint hover:text-ink">Back to Blog</a>
        <p className="mt-6 rounded-xl border border-line bg-panel px-4 py-10 text-center text-sm text-mute">
          No post found for <code className="font-mono text-faint">/{slug}</code>.
        </p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl">
      <PostEditor post={data as PostRow} />
    </div>
  );
}

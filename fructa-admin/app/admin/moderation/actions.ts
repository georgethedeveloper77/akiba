"use server";

import { supabaseAdmin } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// Review moderation.
//
// The rule this whole file exists to enforce: a RATING is published the moment
// it is written, a BODY waits for a human. Nothing here ever touches the
// `rating` column. A moderator can suppress someone's words; they cannot
// suppress someone's score, and that asymmetry is what keeps the histogram
// honest even when the queue is backed up.
//
// Reviews are also the one surface that does NOT ride the snapshot: the app
// reads Postgres live, so an approval here reaches devices immediately with no
// republish. That is why none of these actions call republishSnapshot().

function refresh() {
  revalidatePath("/admin/moderation");
  revalidatePath("/admin");
}

/** Publish the body. The rating was already live. */
export async function approveBody(formData: FormData) {
  const id = String(formData.get("id"));
  if (!id) return;
  await supabaseAdmin()
    .from("insurer_reviews")
    .update({
      body_status: "approved",
      reject_reason: null,
      moderated_at: new Date().toISOString(),
    })
    .eq("id", id);
  refresh();
}

/**
 * Refuse the body. The row stays, the rating stays counted, and the author is
 * shown the reason in-app. Deleting the row instead would silently drop their
 * score too, which would be a lie about the sample size.
 */
export async function rejectBody(formData: FormData) {
  const id = String(formData.get("id"));
  if (!id) return;
  const reason = String(formData.get("reason") ?? "").trim();
  await supabaseAdmin()
    .from("insurer_reviews")
    .update({
      body_status: "rejected",
      reject_reason: reason || "Does not meet the content rules",
      moderated_at: new Date().toISOString(),
    })
    .eq("id", id);
  refresh();
}

/**
 * Take down a review that had already been approved. Auto-hide fires at three
 * distinct reporters; this is the human confirming it.
 *
 * "We removed it within the hour" is a materially better position than "we
 * reviewed it and left it up", and Kenya has no Section 230 safe harbour, so a
 * published defamatory claim about a named insurer is Fructa's problem, not
 * just the author's.
 */
export async function hideReview(formData: FormData) {
  const id = String(formData.get("id"));
  if (!id) return;
  await supabaseAdmin()
    .from("insurer_reviews")
    .update({
      hidden: true,
      body_status: "rejected",
      reject_reason: String(formData.get("reason") ?? "").trim() ||
        "Removed after review",
      moderated_at: new Date().toISOString(),
    })
    .eq("id", id);
  refresh();
}

/** Reinstate a review the auto-hide caught wrongly. Brigading is a thing. */
export async function unhideReview(formData: FormData) {
  const id = String(formData.get("id"));
  if (!id) return;
  await supabaseAdmin()
    .from("insurer_reviews")
    .update({ hidden: false, moderated_at: new Date().toISOString() })
    .eq("id", id);
  refresh();
}

/**
 * Block an author. Anonymous auth means this is a device, not a person: they
 * can reinstall and come back. It is a speed bump for the persistent abuser,
 * not a wall, and it should not be described in the UI as anything more.
 */
export async function blockAuthor(formData: FormData) {
  const authorId = String(formData.get("author_id"));
  if (!authorId) return;
  await supabaseAdmin().from("blocked_authors").upsert(
    {
      author_id: authorId,
      reason: String(formData.get("reason") ?? "").trim() || "Abuse",
    },
    { onConflict: "author_id" },
  );
  // Their existing words come down with them. Their ratings stay: a blocked
  // device does not retroactively make its scores fraudulent, and silently
  // rewriting history would be worse than the abuse.
  await supabaseAdmin()
    .from("insurer_reviews")
    .update({ hidden: true, body_status: "rejected", reject_reason: "Blocked" })
    .eq("author_id", authorId);
  refresh();
}

export async function unblockAuthor(formData: FormData) {
  const authorId = String(formData.get("author_id"));
  if (!authorId) return;
  await supabaseAdmin()
    .from("blocked_authors")
    .delete()
    .eq("author_id", authorId);
  refresh();
}

/** Clear the reports on a review that turned out to be fine. */
export async function dismissReports(formData: FormData) {
  const id = String(formData.get("id"));
  if (!id) return;
  await supabaseAdmin().from("review_reports").delete().eq("review_id", id);
  await supabaseAdmin()
    .from("insurer_reviews")
    .update({ hidden: false })
    .eq("id", id);
  refresh();
}

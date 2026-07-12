/// User reviews of an insurer.
///
/// The split that runs through this whole feature: a RATING publishes the
/// moment it is written, a BODY waits for a human. A star is a preference, and
/// a preference is hard to defame with. A paragraph is a statement of fact
/// about a named, litigious company, and Kenya has no Section 230 safe harbour,
/// so publishing one makes Fructa a publisher.
///
/// The database enforces that split in a view, not in convention: the app reads
/// `insurer_reviews_public`, which nulls `body` unless body_status='approved'.
/// An unapproved body cannot leak into these models because the column does not
/// arrive.
library;

/// A published review. `body` is null when the author wrote none, or when their
/// words have not cleared moderation. Both cases render the same way, which is
/// correct: a rating-only review is complete, not half-finished.
class InsurerReview {
  const InsurerReview({
    required this.id,
    required this.insurerId,
    required this.rating,
    required this.createdAt,
    this.body,
    this.claimsHolder = false,
    this.helpfulCount = 0,
  });

  final String id;
  final String insurerId;
  final int rating; // 1..5
  final String? body;
  final bool claimsHolder;
  final int helpfulCount;
  final DateTime createdAt;

  bool get hasBody => body != null && body!.trim().isNotEmpty;

  factory InsurerReview.fromJson(Map<String, dynamic> j) => InsurerReview(
    id: j['id'] as String,
    insurerId: j['insurer_id'] as String,
    rating: (j['rating'] as num).toInt(),
    body: j['body'] as String?,
    claimsHolder: (j['claims_holder'] ?? false) as bool,
    helpfulCount: (j['helpful_count'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse((j['created_at'] ?? '') as String)?.toLocal() ??
        DateTime.now(),
  );
}

/// The author's own row, which is the ONLY place body_status is visible. They
/// are told plainly that their rating counted and their words are queued, so
/// nobody is left wondering whether the app swallowed their review.
class MyReview {
  const MyReview({
    required this.id,
    required this.rating,
    required this.bodyStatus,
    this.body,
    this.rejectReason,
    this.claimsHolder = false,
  });

  final String id;
  final int rating;
  final String? body;
  final String bodyStatus; // none | pending | approved | rejected
  final String? rejectReason;
  final bool claimsHolder;

  bool get pending => bodyStatus == 'pending';
  bool get rejected => bodyStatus == 'rejected';

  factory MyReview.fromJson(Map<String, dynamic> j) => MyReview(
    id: j['id'] as String,
    rating: (j['rating'] as num).toInt(),
    body: j['body'] as String?,
    bodyStatus: (j['body_status'] ?? 'none') as String,
    rejectReason: j['reject_reason'] as String?,
    claimsHolder: (j['claims_holder'] ?? false) as bool,
  );
}

/// Aggregate over every VISIBLE rating, whether or not its body was approved.
/// That is the point of auto-publishing ratings: moderation delays the words,
/// never the score.
class ReviewStats {
  const ReviewStats({
    required this.count,
    required this.average,
    required this.buckets,
  });

  final int count;
  final double average;
  final Map<int, int> buckets; // star -> how many

  static const empty = ReviewStats(count: 0, average: 0, buckets: {});

  bool get isEmpty => count == 0;

  /// Share of the tallest bar, for the histogram. Guards against divide-by-zero
  /// on an empty set.
  double fraction(int star) {
    if (buckets.isEmpty) return 0;
    final top = buckets.values.fold<int>(0, (a, b) => a > b ? a : b);
    if (top == 0) return 0;
    return (buckets[star] ?? 0) / top;
  }

  factory ReviewStats.fromJson(Map<String, dynamic> j) => ReviewStats(
    count: (j['review_count'] as num?)?.toInt() ?? 0,
    average: (j['review_avg'] as num?)?.toDouble() ?? 0,
    buckets: {
      5: (j['r5'] as num?)?.toInt() ?? 0,
      4: (j['r4'] as num?)?.toInt() ?? 0,
      3: (j['r3'] as num?)?.toInt() ?? 0,
      2: (j['r2'] as num?)?.toInt() ?? 0,
      1: (j['r1'] as num?)?.toInt() ?? 0,
    },
  );
}

/// Why a reader flagged a review. Mirrors the CHECK constraint on
/// review_reports.reason exactly; adding one here without adding it there
/// produces a silent insert failure.
enum ReportReason { spam, abuse, falseClaim, personalInfo, other }

extension ReportReasonX on ReportReason {
  String get key => switch (this) {
    ReportReason.spam => 'spam',
    ReportReason.abuse => 'abuse',
    ReportReason.falseClaim => 'false',
    ReportReason.personalInfo => 'personal_info',
    ReportReason.other => 'other',
  };
}

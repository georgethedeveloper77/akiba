import 'package:hive/hive.dart';

// Last-known snapshot + its ETag, so the app opens instantly and offline,
// and only re-downloads when the file actually changed.
class RatesCache {
  final Box box;
  RatesCache(this.box);

  String? get snapshot => box.get('snapshot') as String?;
  String? get etag => box.get('etag') as String?;

  Future<void> write(String body, String? etag) async {
    await box.put('snapshot', body);
    if (etag != null) await box.put('etag', etag);
  }
}

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/fund.dart';
import '../sources/local/rates_cache.dart';
import '../sources/remote/rates_api.dart';

class RatesRepository {
  final RatesApi api;
  final RatesCache cache;
  RatesRepository(this.api, this.cache);

  static const _bundled = 'assets/json/funds-snapshot.json';

  List<Fund> _parse(String body) {
    final map = jsonDecode(body) as Map<String, dynamic>;
    return (map['funds'] as List? ?? const [])
        .map((e) => Fund.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Instant local read: cached snapshot, else the bundled day-zero one.
  Future<List<Fund>> cachedOrBundled() async {
    final cached = cache.snapshot;
    if (cached != null) return _parse(cached);
    return _parse(await rootBundle.loadString(_bundled));
  }

  // Network refresh; null when the CDN says nothing changed (304).
  Future<List<Fund>?> fetchIfChanged() async {
    final res = await api.getSnapshot(etag: cache.etag);
    if (res == null) return null;
    await cache.write(res.body, res.etag);
    return _parse(res.body);
  }
}

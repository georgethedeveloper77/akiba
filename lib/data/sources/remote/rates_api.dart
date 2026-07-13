import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config.dart';
import '../../models/rate_history.dart';
import '../../models/stock_history.dart';

class SnapshotResponse {
  final String body;
  final String? etag;
  const SnapshotResponse(this.body, this.etag);
}

class RatesApi {
  // Conditional GET of the public snapshot. Returns null on 304 (unchanged).
  Future<SnapshotResponse?> getSnapshot({String? etag}) async {
    final res = await http.get(
      Uri.parse(Config.snapshotUrl),
      headers: {if (etag != null) 'If-None-Match': etag},
    );
    if (res.statusCode == 304) return null;
    if (res.statusCode == 200) {
      return SnapshotResponse(res.body, res.headers['etag']);
    }
    throw Exception('snapshot HTTP ${res.statusCode}');
  }

  // Lazy per-fund history (charts). Fetched only when a fund detail opens.
  Future<List<RateHistory>> getHistory(String fundId) async {
    final url = '${Config.restBase}/rate_history'
        '?fund_id=eq.$fundId&order=as_of&select=as_of,rate';
    final res = await http.get(Uri.parse(url), headers: {
      'apikey': Config.anonKey,
      'Authorization': 'Bearer ${Config.anonKey}',
    });
    if (res.statusCode != 200) throw Exception('history HTTP ${res.statusCode}');
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => RateHistory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lazy per-stock price history, mirroring [getHistory]. Fetched only when a
  /// stock detail opens, never on the markets list: sixty four of these on the
  /// list would be sixty four round trips for four sparkline pixels, which is
  /// what the snapshot's `spark` array is already for.
  Future<List<StockHistory>> getStockHistory(String stockId) async {
    final url = '${Config.restBase}/stock_prices'
        '?stock_id=eq.$stockId&order=as_of&select=as_of,close_kes';
    final res = await http.get(
      Uri.parse(url),
      headers: {
        'apikey': Config.anonKey,
        'Authorization': 'Bearer ${Config.anonKey}',
      },
    );
    if (res.statusCode != 200) {
      throw Exception('stock history HTTP ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => StockHistory.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

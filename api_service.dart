import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trade_setup.dart';

/// Talks to the SnapChart Python backend (TRBP-60 engine).
/// Change baseUrl to your deployed backend when ready.
class ApiService {
  // Local / emulator: use 10.0.2.2 for Android emulator → host machine
  // Physical device: use your machine LAN IP
  static const String baseUrl = 'http://10.0.2.2:5000';

  Future<MarketScan> fetchScan() async {
    final res = await http.get(Uri.parse('$baseUrl/api/scan')).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw Exception('Scan failed: ${res.statusCode}');
    return MarketScan.fromJson(jsonDecode(res.body));
  }

  Future<MarketScan> refreshScan() async {
    final res = await http.get(Uri.parse('$baseUrl/api/refresh')).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('Refresh failed');
    return MarketScan.fromJson(jsonDecode(res.body));
  }

  Future<TradeSetup> fetchSetup(String pair) async {
    final res = await http.get(Uri.parse('$baseUrl/api/setup/$pair'));
    if (res.statusCode != 200) throw Exception('Setup not found');
    return TradeSetup.fromJson(jsonDecode(res.body));
  }

  Future<PositionSizeResult> calculatePositionSize({
    required double balance,
    required double riskPercent,
    required double entry,
    required double stopLoss,
    required String pair,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/position-size'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'balance': balance,
        'risk_percent': riskPercent,
        'entry': entry,
        'stop_loss': stopLoss,
        'pair': pair,
      }),
    );
    if (res.statusCode != 200) throw Exception('Size calc failed');
    return PositionSizeResult.fromJson(jsonDecode(res.body));
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// Auto-Trading Control Centre + MT5 bridge layer.
///
/// Architecture (production):
/// 1. User enables Auto Trading and sets risk limits in the app.
/// 2. App never holds MT5 passwords. Preferred path:
///    - MetaAPI (https://metaapi.cloud) or similar broker-approved bridge
///    - OR custom Expert Advisor on the user's MT5 that listens to a secure WebSocket
/// 3. When TRBP-60 engine emits a VALID setup that passes all filters,
///    backend validates risk → sends order request to the bridge →
///    bridge places market order + SL + TP on the user's account.
/// 4. All actions are logged and visible in the Trade Management screen.
///
/// This class stores user preferences and simulates the control plane.
class AutoTradeSettings {
  bool enabled;
  double riskPerTradePercent;
  double maxDailyLossPercent;
  int maxTradesPerDay;
  int minSetupQuality;
  int minStrategyDna;
  bool newsProtection;
  Set<String> allowedPairs;
  bool moveToBreakevenAt1R;
  bool partialCloseAt1R; // 50%
  bool trailingStop;

  AutoTradeSettings({
    this.enabled = false,
    this.riskPerTradePercent = 0.5,
    this.maxDailyLossPercent = 1.5,
    this.maxTradesPerDay = 3,
    this.minSetupQuality = 75,
    this.minStrategyDna = 70,
    this.newsProtection = true,
    Set<String>? allowedPairs,
    this.moveToBreakevenAt1R = true,
    this.partialCloseAt1R = false,
    this.trailingStop = false,
  }) : allowedPairs = allowedPairs ?? {'EURUSD'};

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'riskPerTradePercent': riskPerTradePercent,
        'maxDailyLossPercent': maxDailyLossPercent,
        'maxTradesPerDay': maxTradesPerDay,
        'minSetupQuality': minSetupQuality,
        'minStrategyDna': minStrategyDna,
        'newsProtection': newsProtection,
        'allowedPairs': allowedPairs.toList(),
        'moveToBreakevenAt1R': moveToBreakevenAt1R,
        'partialCloseAt1R': partialCloseAt1R,
        'trailingStop': trailingStop,
      };

  factory AutoTradeSettings.fromJson(Map<String, dynamic> j) => AutoTradeSettings(
        enabled: j['enabled'] ?? false,
        riskPerTradePercent: (j['riskPerTradePercent'] as num?)?.toDouble() ?? 0.5,
        maxDailyLossPercent: (j['maxDailyLossPercent'] as num?)?.toDouble() ?? 1.5,
        maxTradesPerDay: j['maxTradesPerDay'] ?? 3,
        minSetupQuality: j['minSetupQuality'] ?? 75,
        minStrategyDna: j['minStrategyDna'] ?? 70,
        newsProtection: j['newsProtection'] ?? true,
        allowedPairs: Set<String>.from(j['allowedPairs'] ?? ['EURUSD']),
        moveToBreakevenAt1R: j['moveToBreakevenAt1R'] ?? true,
        partialCloseAt1R: j['partialCloseAt1R'] ?? false,
        trailingStop: j['trailingStop'] ?? false,
      );
}

class Mt5ConnectionStatus {
  final bool connected;
  final String? accountId;
  final String? broker;
  final String? message;

  Mt5ConnectionStatus({
    required this.connected,
    this.accountId,
    this.broker,
    this.message,
  });
}

class AutoTradeService {
  AutoTradeSettings settings = AutoTradeSettings();
  Mt5ConnectionStatus mt5 = Mt5ConnectionStatus(
    connected: false,
    message: 'Not connected',
  );

  // In-memory trade log for demo
  final List<Map<String, dynamic>> actionLog = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('auto_trade_settings');
    if (raw != null) {
      // simple JSON parse could be added; for now keep defaults
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    // prefs.setString('auto_trade_settings', jsonEncode(settings.toJson()));
  }

  /// Simulated secure connect. Real implementation exchanges a short-lived
  /// token with MetaAPI / your bridge, never stores the MT5 password in the app.
  Future<Mt5ConnectionStatus> connectMt5({
    required String accountId,
    required String server,
    required String token, // from your secure bridge
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    mt5 = Mt5ConnectionStatus(
      connected: true,
      accountId: accountId,
      broker: server,
      message: 'Connected via secure bridge',
    );
    _log('MT5 connected', {'accountId': accountId, 'server': server});
    return mt5;
  }

  Future<void> disconnectMt5() async {
    mt5 = Mt5ConnectionStatus(connected: false, message: 'Disconnected by user');
    _log('MT5 disconnected', {});
  }

  /// Called by the engine / backend when a setup is ready.
  /// Returns true only if every user filter passes.
  bool canAutoExecute({
    required String pair,
    required int quality,
    required int dna,
    required bool highImpactNews,
    required int tradesToday,
    required double dailyLossPct,
  }) {
    if (!settings.enabled) return false;
    if (!mt5.connected) return false;
    if (!settings.allowedPairs.contains(pair)) return false;
    if (quality < settings.minSetupQuality) return false;
    if (dna < settings.minStrategyDna) return false;
    if (settings.newsProtection && highImpactNews) return false;
    if (tradesToday >= settings.maxTradesPerDay) return false;
    if (dailyLossPct >= settings.maxDailyLossPercent) return false;
    return true;
  }

  /// Placeholder for the actual order request to the bridge.
  Future<Map<String, dynamic>> requestOrder({
    required String pair,
    required String direction,
    required double entry,
    required double stopLoss,
    required double takeProfit,
    required double lots,
  }) async {
    if (!mt5.connected) {
      return {'ok': false, 'error': 'MT5 not connected'};
    }
    // Real: POST to your secure execution layer
    final result = {
      'ok': true,
      'orderId': 'SIM-${DateTime.now().millisecondsSinceEpoch}',
      'pair': pair,
      'direction': direction,
      'lots': lots,
      'sl': stopLoss,
      'tp': takeProfit,
      'status': 'FILLED',
    };
    _log('ORDER_SENT', result);
    return result;
  }

  void _log(String action, Map<String, dynamic> data) {
    actionLog.insert(0, {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'action': action,
      ...data,
    });
    if (actionLog.length > 200) actionLog.removeLast();
  }
}

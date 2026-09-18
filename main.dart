import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/snap_theme.dart';
import 'models/trade_setup.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/auto_trade_service.dart';
import 'services/journal_service.dart';
import 'screens/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final notifications = NotificationService();
  await notifications.init();

  final journal = JournalService()..seedDemo();
  final autoTrade = AutoTradeService();
  await autoTrade.load();

  runApp(SnapChartApp(
    api: ApiService(),
    notifications: notifications,
    autoTrade: autoTrade,
    journal: journal,
  ));
}

class SnapChartApp extends StatelessWidget {
  final ApiService api;
  final NotificationService notifications;
  final AutoTradeService autoTrade;
  final JournalService journal;

  const SnapChartApp({
    super.key,
    required this.api,
    required this.notifications,
    required this.autoTrade,
    required this.journal,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        Provider.value(value: notifications),
        ChangeNotifierProvider(create: (_) => ScanController(api, notifications)),
        Provider.value(value: autoTrade),
        Provider.value(value: journal),
      ],
      child: MaterialApp(
        title: 'SnapChart',
        debugShowCheckedModeBanner: false,
        theme: SnapTheme.dark,
        home: const HomeShell(),
      ),
    );
  }
}

/// Simple state holder for the market scan
class ScanController extends ChangeNotifier {
  final ApiService api;
  final NotificationService notifications;
  MarketScan? scan;
  bool loading = false;
  String? error;

  ScanController(this.api, this.notifications);

  Future<void> load({bool refresh = false}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      scan = refresh ? await api.refreshScan() : await api.fetchScan();
      // Fire local notification for any new valid high-quality setup
      for (final s in scan!.scan) {
        if (s.isValid && s.setupQuality >= notifications.minQuality) {
          // In production: only notify on *new* signals (track last seen IDs)
          // await notifications.showSetupAlert(pair: s.pair, direction: s.directionLabel, quality: s.setupQuality);
        }
      }
    } catch (e) {
      error = e.toString();
      // Fallback demo data so the UI is usable offline / without backend
      scan = _offlineDemo();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  MarketScan _offlineDemo() {
    return MarketScan(
      generatedAt: DateTime.now().toUtc(),
      pairsAnalysed: 3,
      setupsDetected: 1,
      scan: [
        TradeSetup(
          pair: 'EURUSD',
          direction: Direction.buy,
          entry: 1.08642,
          stopLoss: 1.08415,
          takeProfit: 1.08835,
          riskReward: 0.85,
          setupQuality: 87,
          strategyDna: 82,
          expectedHoldHours: const [2.0, 5.5],
          status: SetupStatus.valid,
          generatedAt: DateTime.now().toUtc(),
          explanation: const [
            '1H price is above the 200 EMA and the EMA is flat-to-rising.',
            '15M price touched or closed below the lower Bollinger Band.',
            'RSI(14) reached oversold territory (≤ 30).',
            'A bullish candle closed back inside the Bollinger Bands.',
          ],
        ),
        TradeSetup(
          pair: 'GBPUSD',
          direction: Direction.none,
          entry: 1.2650,
          stopLoss: 1.2650,
          takeProfit: 1.2650,
          riskReward: 0,
          setupQuality: 0,
          strategyDna: 58,
          expectedHoldHours: const [0, 0],
          status: SetupStatus.waiting,
          generatedAt: DateTime.now().toUtc(),
          explanation: const ['No high-quality setup currently detected.'],
        ),
        TradeSetup(
          pair: 'USDJPY',
          direction: Direction.none,
          entry: 149.20,
          stopLoss: 149.20,
          takeProfit: 149.20,
          riskReward: 0,
          setupQuality: 0,
          strategyDna: 45,
          expectedHoldHours: const [0, 0],
          status: SetupStatus.noTrade,
          generatedAt: DateTime.now().toUtc(),
          explanation: const ['Market conditions do not currently match the strategy.'],
          warnings: const ['High-impact economic news is scheduled soon.'],
        ),
      ],
    );
  }
}

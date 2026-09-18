import 'package:shared_preferences/shared_preferences.dart';

enum TradeEmotion { calm, nervous, revenge, unsure, confident }

class JournalEntry {
  final String id;
  final String pair;
  final String direction;
  final double entry;
  final double? exit;
  final double? pnl;
  final double? rMultiple;
  final int setupQuality;
  final int strategyDna;
  final bool wasAuto;
  final bool userInterfered;
  final DateTime openedAt;
  final DateTime? closedAt;
  final TradeEmotion? emotion;
  final String? note;

  JournalEntry({
    required this.id,
    required this.pair,
    required this.direction,
    required this.entry,
    this.exit,
    this.pnl,
    this.rMultiple,
    required this.setupQuality,
    required this.strategyDna,
    required this.wasAuto,
    this.userInterfered = false,
    required this.openedAt,
    this.closedAt,
    this.emotion,
    this.note,
  });
}

class PerformanceSnapshot {
  final int totalTrades;
  final double winRate;
  final double profitFactor;
  final double avgWinR;
  final double avgLossR;
  final double expectancyR;
  final double maxDrawdownPct;
  final String bestPair;
  final String bestSession;
  final List<String> aiInsights;

  PerformanceSnapshot({
    required this.totalTrades,
    required this.winRate,
    required this.profitFactor,
    required this.avgWinR,
    required this.avgLossR,
    required this.expectancyR,
    required this.maxDrawdownPct,
    required this.bestPair,
    required this.bestSession,
    required this.aiInsights,
  });
}

/// AI Trading Journal + Performance Analytics
/// 
/// Rule-based insights for MVP. Later: send anonymised stats to an LLM
/// endpoint for richer coaching language while keeping the user in control.
class JournalService {
  final List<JournalEntry> _entries = [];

  List<JournalEntry> get entries => List.unmodifiable(_entries);

  void addEntry(JournalEntry e) => _entries.insert(0, e);

  void setEmotion(String id, TradeEmotion emotion) {
    final i = _entries.indexWhere((e) => e.id == id);
    if (i >= 0) {
      final old = _entries[i];
      _entries[i] = JournalEntry(
        id: old.id,
        pair: old.pair,
        direction: old.direction,
        entry: old.entry,
        exit: old.exit,
        pnl: old.pnl,
        rMultiple: old.rMultiple,
        setupQuality: old.setupQuality,
        strategyDna: old.strategyDna,
        wasAuto: old.wasAuto,
        userInterfered: old.userInterfered,
        openedAt: old.openedAt,
        closedAt: old.closedAt,
        emotion: emotion,
        note: old.note,
      );
    }
  }

  PerformanceSnapshot compute() {
    if (_entries.isEmpty) {
      return PerformanceSnapshot(
        totalTrades: 0,
        winRate: 0,
        profitFactor: 0,
        avgWinR: 0,
        avgLossR: 0,
        expectancyR: 0,
        maxDrawdownPct: 0,
        bestPair: '—',
        bestSession: '—',
        aiInsights: [
          'No closed trades yet. Follow a few signals manually to start building your journal.',
        ],
      );
    }

    final closed = _entries.where((e) => e.rMultiple != null).toList();
    if (closed.isEmpty) {
      return PerformanceSnapshot(
        totalTrades: _entries.length,
        winRate: 0,
        profitFactor: 0,
        avgWinR: 0,
        avgLossR: 0,
        expectancyR: 0,
        maxDrawdownPct: 0,
        bestPair: '—',
        bestSession: '—',
        aiInsights: ['Trades are open or missing exit data.'],
      );
    }

    final wins = closed.where((e) => (e.rMultiple ?? 0) > 0).toList();
    final losses = closed.where((e) => (e.rMultiple ?? 0) <= 0).toList();
    final winRate = wins.length / closed.length;
    final avgWin = wins.isEmpty ? 0.0 : wins.map((e) => e.rMultiple!).reduce((a, b) => a + b) / wins.length;
    final avgLoss = losses.isEmpty ? 0.0 : losses.map((e) => e.rMultiple!.abs()).reduce((a, b) => a + b) / losses.length;
    final grossWin = wins.fold(0.0, (s, e) => s + e.rMultiple!);
    final grossLoss = losses.fold(0.0, (s, e) => s + e.rMultiple!.abs());
    final pf = grossLoss == 0 ? grossWin : grossWin / grossLoss;
    final expectancy = (winRate * avgWin) - ((1 - winRate) * avgLoss);

    // Simple pair stats
    final byPair = <String, List<double>>{};
    for (final e in closed) {
      byPair.putIfAbsent(e.pair, () => []).add(e.rMultiple!);
    }
    String bestPair = '—';
    double bestAvg = -999;
    byPair.forEach((p, rs) {
      final avg = rs.reduce((a, b) => a + b) / rs.length;
      if (avg > bestAvg) {
        bestAvg = avg;
        bestPair = p;
      }
    });

    final insights = _generateInsights(
      winRate: winRate,
      expectancy: expectancy,
      closed: closed,
      avgWin: avgWin,
      avgLoss: avgLoss,
    );

    return PerformanceSnapshot(
      totalTrades: closed.length,
      winRate: winRate,
      profitFactor: pf,
      avgWinR: avgWin,
      avgLossR: avgLoss,
      expectancyR: expectancy,
      maxDrawdownPct: 0, // would need equity curve
      bestPair: bestPair,
      bestSession: 'London', // placeholder until session tagging exists
      aiInsights: insights,
    );
  }

  List<String> _generateInsights({
    required double winRate,
    required double expectancy,
    required List<JournalEntry> closed,
    required double avgWin,
    required double avgLoss,
  }) {
    final insights = <String>[];

    if (winRate >= 0.60 && expectancy > 0) {
      insights.add('Your observed win rate is ≥ 60% with positive expectancy — consistent with the TRBP-60 design goal.');
    } else if (winRate >= 0.55) {
      insights.add('Win rate is solid. Focus on keeping average loss ≤ 1R so expectancy stays positive.');
    }

    final interfered = closed.where((e) => e.userInterfered).length;
    if (interfered > closed.length * 0.3) {
      insights.add('You manually interfered on ${((interfered / closed.length) * 100).round()}% of trades. High interference often reduces the edge of a rule-based system.');
    }

    final lowQ = closed.where((e) => e.setupQuality < 65).toList();
    if (lowQ.isNotEmpty) {
      final lowWin = lowQ.where((e) => (e.rMultiple ?? 0) > 0).length / lowQ.length;
      if (lowWin < 0.45) {
        insights.add('Setups below 65 quality historically under-perform for you. Consider raising your minimum quality filter.');
      }
    }

    final highDna = closed.where((e) => e.strategyDna >= 80).toList();
    if (highDna.length >= 5) {
      final highWin = highDna.where((e) => (e.rMultiple ?? 0) > 0).length / highDna.length;
      insights.add('When Strategy DNA ≥ 80%, your win rate on this sample is ${(highWin * 100).round()}%.');
    }

    if (avgLoss > avgWin * 1.3) {
      insights.add('Average losses are larger than average wins. The 0.8–1.0R target rule is designed to prevent this — review stop placement.');
    }

    if (insights.isEmpty) {
      insights.add('Keep journaling. After ~50 closed trades the insights become statistically more meaningful.');
    }
    return insights;
  }

  /// Seed a few demo closed trades so the analytics screen is not empty
  void seedDemo() {
    if (_entries.isNotEmpty) return;
    final now = DateTime.now().toUtc();
    addEntry(JournalEntry(
      id: 'demo-1', pair: 'EURUSD', direction: 'BUY', entry: 1.0840,
      exit: 1.0862, pnl: 22, rMultiple: 0.9, setupQuality: 87, strategyDna: 82,
      wasAuto: false, openedAt: now.subtract(const Duration(hours: 8)), closedAt: now.subtract(const Duration(hours: 4)),
      emotion: TradeEmotion.calm,
    ));
    addEntry(JournalEntry(
      id: 'demo-2', pair: 'EURUSD', direction: 'BUY', entry: 1.0815,
      exit: 1.0801, pnl: -14, rMultiple: -1.0, setupQuality: 72, strategyDna: 68,
      wasAuto: false, openedAt: now.subtract(const Duration(days: 1)), closedAt: now.subtract(const Duration(hours: 20)),
      emotion: TradeEmotion.nervous,
    ));
    addEntry(JournalEntry(
      id: 'demo-3', pair: 'GBPUSD', direction: 'SELL', entry: 1.2680,
      exit: 1.2655, pnl: 18, rMultiple: 0.85, setupQuality: 81, strategyDna: 79,
      wasAuto: true, openedAt: now.subtract(const Duration(days: 2)), closedAt: now.subtract(const Duration(days: 1, hours: 18)),
      emotion: TradeEmotion.confident,
    ));
  }
}

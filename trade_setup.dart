enum Direction { buy, sell, none }
enum SetupStatus { valid, waiting, noTrade, invalidated, expired }

class TradeSetup {
  final String pair;
  final Direction direction;
  final double entry;
  final double stopLoss;
  final double takeProfit;
  final double riskReward;
  final int setupQuality;
  final int strategyDna;
  final List<double> expectedHoldHours;
  final SetupStatus status;
  final DateTime generatedAt;
  final List<String> explanation;
  final List<String> warnings;
  final double atr;
  final double rsi;
  final String bbPosition;

  TradeSetup({
    required this.pair,
    required this.direction,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit,
    required this.riskReward,
    required this.setupQuality,
    required this.strategyDna,
    required this.expectedHoldHours,
    required this.status,
    required this.generatedAt,
    this.explanation = const [],
    this.warnings = const [],
    this.atr = 0,
    this.rsi = 0,
    this.bbPosition = '',
  });

  factory TradeSetup.fromJson(Map<String, dynamic> j) {
    Direction dir = Direction.none;
    final d = (j['direction'] as String? ?? 'NONE').toUpperCase();
    if (d == 'BUY') dir = Direction.buy;
    if (d == 'SELL') dir = Direction.sell;

    SetupStatus st = SetupStatus.noTrade;
    final s = (j['status'] as String? ?? 'NO_TRADE').toUpperCase();
    if (s == 'VALID') st = SetupStatus.valid;
    if (s == 'WAITING') st = SetupStatus.waiting;
    if (s == 'INVALIDATED') st = SetupStatus.invalidated;
    if (s == 'EXPIRED') st = SetupStatus.expired;

    final hold = j['expected_hold_hours'];
    List<double> holdList = [0, 0];
    if (hold is List && hold.length >= 2) {
      holdList = [ (hold[0] as num).toDouble(), (hold[1] as num).toDouble() ];
    }

    return TradeSetup(
      pair: j['pair'] ?? '',
      direction: dir,
      entry: (j['entry'] as num?)?.toDouble() ?? 0,
      stopLoss: (j['stop_loss'] as num?)?.toDouble() ?? 0,
      takeProfit: (j['take_profit'] as num?)?.toDouble() ?? 0,
      riskReward: (j['risk_reward'] as num?)?.toDouble() ?? 0,
      setupQuality: j['setup_quality'] ?? 0,
      strategyDna: j['strategy_dna'] ?? 0,
      expectedHoldHours: holdList,
      status: st,
      generatedAt: DateTime.tryParse(j['generated_at'] ?? '') ?? DateTime.now().toUtc(),
      explanation: List<String>.from(j['explanation'] ?? []),
      warnings: List<String>.from(j['warnings'] ?? []),
      atr: (j['atr'] as num?)?.toDouble() ?? 0,
      rsi: (j['rsi'] as num?)?.toDouble() ?? 0,
      bbPosition: j['bb_position'] ?? '',
    );
  }

  String get pairFormatted {
    if (pair.length == 6) return '${pair.substring(0, 3)}/${pair.substring(3)}';
    return pair;
  }

  bool get isValid => direction != Direction.none && status == SetupStatus.valid;

  String get directionLabel {
    if (!isValid) {
      if (status == SetupStatus.waiting) return 'WAITING';
      return 'NO TRADE';
    }
    return direction == Direction.buy ? 'STRONG BUY' : 'STRONG SELL';
  }
}

class PositionSizeResult {
  final double lots;
  final double riskAmount;
  final double stopPips;

  PositionSizeResult({required this.lots, required this.riskAmount, required this.stopPips});

  factory PositionSizeResult.fromJson(Map<String, dynamic> j) => PositionSizeResult(
    lots: (j['lots'] as num?)?.toDouble() ?? 0,
    riskAmount: (j['risk_amount'] as num?)?.toDouble() ?? 0,
    stopPips: (j['stop_pips'] as num?)?.toDouble() ?? 0,
  );
}

class MarketScan {
  final DateTime generatedAt;
  final int pairsAnalysed;
  final int setupsDetected;
  final List<TradeSetup> scan;

  MarketScan({
    required this.generatedAt,
    required this.pairsAnalysed,
    required this.setupsDetected,
    required this.scan,
  });

  factory MarketScan.fromJson(Map<String, dynamic> j) {
    final list = (j['scan'] as List? ?? [])
        .map((e) => TradeSetup.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return MarketScan(
      generatedAt: DateTime.tryParse(j['generated_at'] ?? '') ?? DateTime.now().toUtc(),
      pairsAnalysed: j['pairs_analysed'] ?? 0,
      setupsDetected: j['setups_detected'] ?? 0,
      scan: list,
    );
  }
}

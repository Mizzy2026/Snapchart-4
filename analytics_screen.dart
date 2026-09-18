import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/snap_theme.dart';
import '../services/journal_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = context.read<JournalService>();
    final snap = journal.compute();

    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: glassDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SNAPSHOT', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: SnapColors.textDim, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _metric('${(snap.winRate * 100).toStringAsFixed(0)}%', 'Win Rate', SnapColors.accent),
                    _metric(snap.totalTrades.toString(), 'Trades', SnapColors.text),
                    _metric(snap.expectancyR.toStringAsFixed(2), 'Expectancy R', snap.expectancyR >= 0 ? SnapColors.accent : SnapColors.sell),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _metric(snap.profitFactor.toStringAsFixed(2), 'Profit Factor', SnapColors.dna),
                    _metric(snap.avgWinR.toStringAsFixed(2), 'Avg Win R', SnapColors.accent),
                    _metric(snap.avgLossR.toStringAsFixed(2), 'Avg Loss R', SnapColors.sell),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: glassDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BEST', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: SnapColors.textDim, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _row('Best pair', snap.bestPair),
                _row('Best session', snap.bestSession),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: glassDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI INSIGHTS', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: SnapColors.textDim, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...snap.aiInsights.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('→  ', style: TextStyle(color: SnapColors.accent)),
                      Expanded(child: Text(i, style: const TextStyle(fontSize: 13.5, height: 1.4))),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Insights are educational and based on your journalled trades. They are not guarantees of future performance.',
            style: TextStyle(fontSize: 11, color: SnapColors.textDim),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: SnapColors.textMuted)),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: SnapColors.textMuted, fontSize: 13)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/snap_theme.dart';
import '../services/journal_service.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = context.read<JournalService>();
    final entries = journal.entries;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Journal')),
      body: entries.isEmpty
          ? const Center(child: Text('No journal entries yet', style: TextStyle(color: SnapColors.textMuted)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final e = entries[i];
                final isWin = (e.rMultiple ?? 0) > 0;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: glassDecoration(radius: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${e.pair}  ${e.direction}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (e.rMultiple != null)
                            Text(
                              '${isWin ? '+' : ''}${e.rMultiple!.toStringAsFixed(2)}R',
                              style: TextStyle(color: isWin ? SnapColors.accent : SnapColors.sell, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Q ${e.setupQuality}  ·  DNA ${e.strategyDna}%  ·  ${e.wasAuto ? 'Auto' : 'Manual'}',
                        style: const TextStyle(fontSize: 12, color: SnapColors.textMuted),
                      ),
                      Text(
                        DateFormat.MMMd().add_Hm().format(e.openedAt.toLocal()),
                        style: const TextStyle(fontSize: 11, color: SnapColors.textDim),
                      ),
                      if (e.emotion != null) ...[
                        const SizedBox(height: 8),
                        Text(_emotionLabel(e.emotion!), style: const TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _emotionLabel(TradeEmotion e) {
    switch (e) {
      case TradeEmotion.calm: return '😎 Calm';
      case TradeEmotion.nervous: return '😬 Nervous';
      case TradeEmotion.revenge: return '😤 Revenge';
      case TradeEmotion.unsure: return '😐 Unsure';
      case TradeEmotion.confident: return '💪 Confident';
    }
  }
}

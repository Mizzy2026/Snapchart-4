import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/snap_theme.dart';
import '../models/trade_setup.dart';
import '../services/api_service.dart';

class SetupDetailScreen extends StatefulWidget {
  final TradeSetup setup;
  const SetupDetailScreen({super.key, required this.setup});

  @override
  State<SetupDetailScreen> createState() => _SetupDetailScreenState();
}

class _SetupDetailScreenState extends State<SetupDetailScreen> {
  bool _whyOpen = false;
  final _balanceCtrl = TextEditingController(text: '1000');
  final _riskCtrl = TextEditingController(text: '0.5');
  PositionSizeResult? _size;
  bool _calcLoading = false;

  TradeSetup get s => widget.setup;

  @override
  void dispose() {
    _balanceCtrl.dispose();
    _riskCtrl.dispose();
    super.dispose();
  }

  Future<void> _calc() async {
    if (!s.isValid) return;
    setState(() => _calcLoading = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.calculatePositionSize(
        balance: double.tryParse(_balanceCtrl.text) ?? 1000,
        riskPercent: double.tryParse(_riskCtrl.text) ?? 0.5,
        entry: s.entry,
        stopLoss: s.stopLoss,
        pair: s.pair,
      );
      setState(() => _size = res);
    } catch (_) {
      // offline fallback
      final bal = double.tryParse(_balanceCtrl.text) ?? 1000;
      final riskPct = double.tryParse(_riskCtrl.text) ?? 0.5;
      final riskAmt = bal * riskPct / 100;
      final stopPips = (s.entry - s.stopLoss).abs() * 10000;
      final lots = stopPips > 0 ? (riskAmt / (stopPips * 10)).clamp(0.01, 50.0) : 0.0;
      setState(() => _size = PositionSizeResult(lots: double.parse(lots.toStringAsFixed(2)), riskAmount: riskAmt, stopPips: stopPips));
    } finally {
      setState(() => _calcLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = s.direction == Direction.buy;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.pairFormatted),
        actions: [
          if (s.isValid)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isBuy ? SnapColors.accentDim : SnapColors.sellDim,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(s.direction.name.toUpperCase(), style: TextStyle(color: isBuy ? SnapColors.accent : SnapColors.sell, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quality + DNA
          Row(
            children: [
              Expanded(child: _scoreCard('Setup Quality', '${s.setupQuality}', '/100', SnapColors.accent)),
              const SizedBox(width: 12),
              Expanded(child: _scoreCard('Strategy DNA', '${s.strategyDna}', '%', SnapColors.dna)),
            ],
          ),
          const SizedBox(height: 16),
          // Levels
          if (s.isValid) ...[
            Row(
              children: [
                Expanded(child: _level('Entry', s.entry.toStringAsFixed(5))),
                const SizedBox(width: 8),
                Expanded(child: _level('Stop Loss', s.stopLoss.toStringAsFixed(5), color: SnapColors.sell)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _level('Take Profit', s.takeProfit.toStringAsFixed(5), color: SnapColors.accent)),
                const SizedBox(width: 8),
                Expanded(child: _level('R : R', '1 : ${s.riskReward.toStringAsFixed(2)}')),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: glassDecoration(radius: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated Hold', style: TextStyle(color: SnapColors.textMuted, fontSize: 13)),
                  Text('${s.expectedHoldHours[0]}–${s.expectedHoldHours[1]} hours', style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Why
          OutlinedButton(
            onPressed: () => setState(() => _whyOpen = !_whyOpen),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0x4DB8F200)),
              foregroundColor: SnapColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('WHY THIS TRADE?', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          if (_whyOpen) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: glassDecoration(radius: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...s.explanation.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✓  ', style: TextStyle(color: SnapColors.accent, fontWeight: FontWeight.w600)),
                        Expanded(child: Text(e, style: const TextStyle(fontSize: 13.5))),
                      ],
                    ),
                  )),
                  ...s.warnings.map((w) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('⚠ $w', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 13)),
                  )),
                ],
              ),
            ),
          ],
          if (s.isValid) ...[
            const SizedBox(height: 28),
            const Text('POSITION SIZE', style: TextStyle(fontSize: 12, letterSpacing: 1, color: SnapColors.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _balanceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Balance (\$)'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _riskCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Risk %'))),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _calcLoading ? null : _calc,
              child: _calcLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Calculate Lot Size'),
            ),
            if (_size != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SnapColors.accentDim,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x33B8F200)),
                ),
                child: Row(
                  children: [
                    const Text('Recommended lot size:', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 10),
                    Text(_size!.lots.toStringAsFixed(2), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: SnapColors.accent, fontFamily: 'monospace')),
                    const Spacer(),
                    Text('Risk \$${_size!.riskAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: SnapColors.textMuted)),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _scoreCard(String label, String value, String suffix, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, color: SnapColors.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            TextSpan(text: value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: color, letterSpacing: -1)),
            TextSpan(text: suffix, style: const TextStyle(fontSize: 14, color: SnapColors.textMuted)),
          ])),
        ],
      ),
    );
  }

  Widget _level(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: SnapColors.textMuted, letterSpacing: 0.6)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'monospace', color: color ?? SnapColors.text)),
        ],
      ),
    );
  }
}

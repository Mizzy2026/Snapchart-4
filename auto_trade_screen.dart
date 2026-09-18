import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/snap_theme.dart';
import '../services/auto_trade_service.dart';

class AutoTradeScreen extends StatefulWidget {
  const AutoTradeScreen({super.key});

  @override
  State<AutoTradeScreen> createState() => _AutoTradeScreenState();
}

class _AutoTradeScreenState extends State<AutoTradeScreen> {
  late AutoTradeService _svc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _svc = context.read<AutoTradeService>();
  }

  @override
  Widget build(BuildContext context) {
    final s = _svc.settings;
    final mt5 = _svc.mt5;

    return Scaffold(
      appBar: AppBar(title: const Text('Auto-Trading')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status
          Container(
            padding: const EdgeInsets.all(18),
            decoration: glassDecoration(
              borderColor: s.enabled && mt5.connected ? const Color(0x40B8F200) : SnapColors.glassBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('AUTO TRADING', style: TextStyle(fontSize: 12, letterSpacing: 1, color: SnapColors.textMuted, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Switch(
                      value: s.enabled,
                      activeColor: SnapColors.accent,
                      onChanged: (v) => setState(() {
                        s.enabled = v;
                        _svc.save();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      mt5.connected ? Icons.check_circle : Icons.cloud_off,
                      size: 16,
                      color: mt5.connected ? SnapColors.accent : SnapColors.textDim,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      mt5.connected ? 'MT5 connected · ${mt5.accountId ?? ''}' : 'MT5 not connected',
                      style: TextStyle(fontSize: 13, color: mt5.connected ? SnapColors.accent : SnapColors.textMuted),
                    ),
                  ],
                ),
                if (!mt5.connected) ...[
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () async {
                      // Demo connect – real flow would open secure bridge auth
                      await _svc.connectMt5(
                        accountId: 'demo-12345',
                        server: 'MetaQuotes-Demo',
                        token: 'secure-bridge-token',
                      );
                      setState(() {});
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: SnapColors.accent, side: const BorderSide(color: Color(0x4DB8F200))),
                    child: const Text('Connect MT5 (Secure Bridge)'),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () async {
                      await _svc.disconnectMt5();
                      setState(() {});
                    },
                    child: const Text('Disconnect', style: TextStyle(color: SnapColors.sell, fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('RISK LIMITS', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: SnapColors.textDim, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _slider('Risk per trade', s.riskPerTradePercent, 0.1, 2.0, '%', (v) => setState(() => s.riskPerTradePercent = v)),
          _slider('Max daily loss', s.maxDailyLossPercent, 0.5, 5.0, '%', (v) => setState(() => s.maxDailyLossPercent = v)),
          _slider('Max trades / day', s.maxTradesPerDay.toDouble(), 1, 10, '', (v) => setState(() => s.maxTradesPerDay = v.round())),
          const SizedBox(height: 16),
          const Text('FILTERS', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: SnapColors.textDim, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _slider('Min setup quality', s.minSetupQuality.toDouble(), 50, 95, '', (v) => setState(() => s.minSetupQuality = v.round())),
          _slider('Min Strategy DNA', s.minStrategyDna.toDouble(), 40, 95, '%', (v) => setState(() => s.minStrategyDna = v.round())),
          SwitchListTile(
            title: const Text('News protection', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Block new trades before high-impact events', style: TextStyle(fontSize: 12, color: SnapColors.textMuted)),
            value: s.newsProtection,
            activeColor: SnapColors.accent,
            onChanged: (v) => setState(() => s.newsProtection = v),
          ),
          const SizedBox(height: 12),
          const Text('TRADE MANAGEMENT', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: SnapColors.textDim, fontWeight: FontWeight.w600)),
          SwitchListTile(
            title: const Text('Move SL to breakeven at 1R', style: TextStyle(fontSize: 14)),
            value: s.moveToBreakevenAt1R,
            activeColor: SnapColors.accent,
            onChanged: (v) => setState(() => s.moveToBreakevenAt1R = v),
          ),
          SwitchListTile(
            title: const Text('Partial close 50% at 1R', style: TextStyle(fontSize: 14)),
            value: s.partialCloseAt1R,
            activeColor: SnapColors.accent,
            onChanged: (v) => setState(() => s.partialCloseAt1R = v),
          ),
          const SizedBox(height: 16),
          const Text(
            'Automation never exceeds your risk limits. You can disable it instantly. '
            'MT5 credentials are handled by a secure bridge — the app does not store raw passwords.',
            style: TextStyle(fontSize: 11, color: SnapColors.textDim, height: 1.4),
          ),
          const SizedBox(height: 24),
          if (_svc.actionLog.isNotEmpty) ...[
            const Text('RECENT ACTIONS', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: SnapColors.textDim, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ..._svc.actionLog.take(8).map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${a['ts']?.toString().substring(11, 19) ?? ''}  ${a['action']}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: SnapColors.textMuted),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, String suffix, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Text('${value.toStringAsFixed(suffix.isEmpty ? 0 : 1)}$suffix', style: const TextStyle(color: SnapColors.accent, fontWeight: FontWeight.w600)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) * (suffix.isEmpty ? 1 : 10)).round().clamp(1, 100),
            activeColor: SnapColors.accent,
            inactiveColor: SnapColors.glassBorder,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

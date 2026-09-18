import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/snap_theme.dart';
import '../models/trade_setup.dart';
import '../main.dart';
import 'setup_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ScanController>();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: SnapColors.accent,
          backgroundColor: SnapColors.bg,
          onRefresh: () => ctrl.load(refresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(ctrl: ctrl)),
              SliverToBoxAdapter(child: _ScanSummary(ctrl: ctrl)),
              if (ctrl.loading && ctrl.scan == null)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: SnapColors.accent)),
                )
              else if (ctrl.scan != null)
                ...ctrl.scan!.scan.map((s) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: SetupCard(
                          setup: s,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SetupDetailScreen(setup: s)),
                          ),
                        ),
                      ),
                    )),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              const SliverToBoxAdapter(child: _Disclaimer()),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ScanController ctrl;
  const _Header({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const Text('S▰', style: TextStyle(color: SnapColors.accent, fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const Text('SNAP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const Text('CHART', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: SnapColors.accent)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: SnapColors.accentDim,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x33B8F200)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(),
                SizedBox(width: 6),
                Text('LIVE', style: TextStyle(color: SnapColors.accent, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_c),
      child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: SnapColors.accent, shape: BoxShape.circle)),
    );
  }
}

class _ScanSummary extends StatelessWidget {
  final ScanController ctrl;
  const _ScanSummary({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final scan = ctrl.scan;
    final time = scan != null ? DateFormat.Hm().format(scan.generatedAt.toLocal()) : '—';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MARKET SCAN', style: TextStyle(fontSize: 11, letterSpacing: 1.4, color: SnapColors.textDim, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('${scan?.pairsAnalysed ?? '—'}', 'pairs analysed'),
              _divider(),
              _stat('${scan?.setupsDetected ?? '—'}', 'setups detected', accent: true),
              _divider(),
              _stat(time, 'last scan'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, {bool accent = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: accent ? SnapColors.accent : SnapColors.text)),
          Text(label, style: const TextStyle(fontSize: 12, color: SnapColors.textMuted)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: SnapColors.glassBorder, margin: const EdgeInsets.symmetric(horizontal: 8));
}

class SetupCard extends StatelessWidget {
  final TradeSetup setup;
  final VoidCallback onTap;
  const SetupCard({super.key, required this.setup, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final valid = setup.isValid;
    Color statusColor = SnapColors.textDim;
    Color statusBg = const Color(0x1F5C6578);
    if (valid && setup.direction == Direction.buy) {
      statusColor = SnapColors.accent;
      statusBg = SnapColors.accentDim;
    } else if (valid && setup.direction == Direction.sell) {
      statusColor = SnapColors.sell;
      statusBg = SnapColors.sellDim;
    } else if (setup.status == SetupStatus.waiting) {
      statusColor = SnapColors.waiting;
      statusBg = const Color(0x1AA0A8B8);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: glassDecoration(
          borderColor: valid ? const Color(0x40B8F200) : SnapColors.glassBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(setup.pairFormatted, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(setup.directionLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (valid) ...[
              Text.rich(TextSpan(children: [
                TextSpan(text: '${setup.setupQuality}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: SnapColors.accent, letterSpacing: -1)),
                const TextSpan(text: '/100', style: TextStyle(fontSize: 14, color: SnapColors.textMuted)),
              ])),
              const Text('Setup Quality', style: TextStyle(fontSize: 12, color: SnapColors.textMuted)),
              const SizedBox(height: 12),
              Text('Entry  ${setup.entry.toStringAsFixed(5)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              Text('SL ${setup.stopLoss.toStringAsFixed(5)}  ·  TP ${setup.takeProfit.toStringAsFixed(5)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: SnapColors.textMuted)),
              Text('R:R 1:${setup.riskReward.toStringAsFixed(2)}  ·  DNA ${setup.strategyDna}%', style: const TextStyle(fontSize: 12, color: SnapColors.textMuted)),
            ] else ...[
              const Text('—', style: TextStyle(fontSize: 22, color: SnapColors.textDim)),
              Text(setup.explanation.isNotEmpty ? setup.explanation.first : 'No setup', style: const TextStyle(fontSize: 13, color: SnapColors.textMuted)),
              const SizedBox(height: 8),
              Text('Strategy DNA ${setup.strategyDna}%', style: const TextStyle(fontSize: 12, color: SnapColors.textDim)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        'TRBP-60 Strategy Engine · Educational use only · Not financial advice\nPast performance does not guarantee future results.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: SnapColors.textDim, height: 1.4),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/snap_theme.dart';
import '../main.dart';
import 'dashboard_screen.dart';
import 'setup_detail_screen.dart';

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ScanController>();
    final valid = ctrl.scan?.scan.where((s) => s.isValid).toList() ?? [];
    final others = ctrl.scan?.scan.where((s) => !s.isValid).toList() ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Signals')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (valid.isEmpty && others.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: Text('No signals yet', style: TextStyle(color: SnapColors.textMuted))),
            ),
          if (valid.isNotEmpty) ...[
            const Text('ACTIVE SETUPS', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: SnapColors.textDim, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...valid.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SetupCard(setup: s, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SetupDetailScreen(setup: s)))),
            )),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('WATCHING', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: SnapColors.textDim, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...others.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SetupCard(setup: s, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SetupDetailScreen(setup: s)))),
            )),
          ],
        ],
      ),
    );
  }
}

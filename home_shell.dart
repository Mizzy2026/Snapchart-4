import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/snap_theme.dart';
import '../main.dart';
import 'dashboard_screen.dart';
import 'signals_screen.dart';
import 'journal_screen.dart';
import 'auto_trade_screen.dart';
import 'analytics_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    DashboardScreen(),
    SignalsScreen(),
    AnalyticsScreen(),
    JournalScreen(),
    AutoTradeScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScanController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: SnapColors.glassBorder)),
          color: Color(0xE6080A0F),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _nav(0, Icons.radar, 'Scan'),
                _nav(1, Icons.bolt, 'Signals'),
                _nav(2, Icons.insights, 'Stats'),
                _nav(3, Icons.menu_book, 'Journal'),
                _nav(4, Icons.smart_toy_outlined, 'Auto'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nav(int i, IconData icon, String label) {
    final selected = _index == i;
    return InkWell(
      onTap: () => setState(() => _index = i),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: selected ? SnapColors.accent : SnapColors.textDim),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? SnapColors.accent : SnapColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

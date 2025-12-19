import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/exercises_screen.dart';
import 'screens/programs_screen.dart';
import 'screens/intake_forms_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/reports_screen.dart' as legacy_reports;
import 'screens/settings_screen.dart';

import 'package:simon_physio/src/features/plans/today_screen.dart';
import 'package:simon_physio/src/features/plans/plans_screen.dart';
import 'package:simon_physio/src/features/reports/reports_screen.dart';

class PremiumPhysioOSApp extends StatelessWidget {
  const PremiumPhysioOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00D4FF),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simon Physio â€” Premium',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
      ),
      home: const PremiumShell(),
    );
  }
}

class PremiumShell extends StatefulWidget {
  const PremiumShell({super.key});

  @override
  State<PremiumShell> createState() => _PremiumShellState();
}

class _PremiumShellState extends State<PremiumShell> {
  int index = 0;

  late final List<_NavDef> _nav = <_NavDef>[
    _NavDef('Today', Icons.today, () => TodayScreen()),
    _NavDef('Plans', Icons.list_alt, () => PlansScreen()),
    _NavDef('Reports', Icons.show_chart, () => ReportsScreen()),

    // Premium legacy sections (kept)
    _NavDef('Dashboard', Icons.dashboard_rounded, () => const DashboardScreen()),
    _NavDef('Clients', Icons.people_alt_rounded, () => const ClientsScreen()),
    _NavDef('Calendar', Icons.calendar_month_rounded, () => const CalendarScreen()),
    _NavDef('Exercises', Icons.fitness_center_rounded, () => const ExercisesScreen()),
    _NavDef('Programs', Icons.playlist_add_check_rounded, () => const ProgramsScreen()),
    _NavDef('Intake Forms', Icons.assignment_rounded, () => const IntakeFormsScreen()),
    _NavDef('Progress', Icons.insights_rounded, () => const ProgressScreen()),
    _NavDef('Legacy Reports', Icons.summarize_rounded, () => const legacy_reports.ReportsScreen()),
    _NavDef('Settings', Icons.settings_rounded, () => const SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 980;

        final body = _nav[index].builder();

        return Scaffold(
          body: Row(
            children: [
              if (wide)
                _PremiumRail(
                  index: index,
                  onTap: (i) => setState(() => index = i),
                  nav: _nav,
                ),
              Expanded(child: body),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : BottomNavigationBar(
                  currentIndex: index.clamp(0, 2),
                  onTap: (i) => setState(() => index = i),
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Today'),
                    BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Plans'),
                    BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Reports'),
                  ],
                ),
        );
      },
    );
  }
}

class _NavDef {
  final String label;
  final IconData icon;
  final Widget Function() builder;
  _NavDef(this.label, this.icon, this.builder);
}

class _PremiumRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<_NavDef> nav;

  const _PremiumRail({
    required this.index,
    required this.onTap,
    required this.nav,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF0E141C),
        border: Border(right: BorderSide(color: Color(0xFF1A2330))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const _BrandHeader(),
          const SizedBox(height: 10),
          Expanded(
            child: NavigationRail(
              backgroundColor: const Color(0xFF0E141C),
              selectedIndex: index,
              onDestinationSelected: onTap,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in nav)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(14),
            child: _FooterHint(),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F14),
        border: Border.all(color: const Color(0xFF1A2330)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withOpacity(0.35)),
            ),
            child: Icon(Icons.health_and_safety_rounded, color: cs.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Simon Physio', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Premium OS', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Tip: Use Today for quick actions, Plans for programs, Reports for outcomes.',
      style: TextStyle(fontSize: 12, color: Colors.white70),
    );
  }
}

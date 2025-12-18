import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/exercises_screen.dart';
import 'screens/programs_screen.dart';
import 'screens/intake_forms_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';

class PremiumPhysioOSApp extends StatelessWidget {
  const PremiumPhysioOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00D4FF), brightness: Brightness.dark);

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
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

  final pages = const [
    DashboardScreen(),
    ClientsScreen(),
    CalendarScreen(),
    ExercisesScreen(),
    ProgramsScreen(),
    IntakeFormsScreen(),
    ProgressScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 980;
        return Scaffold(
          body: Row(
            children: [
              if (wide) _SideRail(index: index, onTap: (i) => setState(() => index = i)),
              Expanded(child: pages[index]),
            ],
          ),
          bottomNavigationBar: wide ? null : _BottomNav(index: index, onTap: (i) => setState(() => index = i)),
        );
      },
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'Clients'),
        NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
        NavigationDestination(icon: Icon(Icons.fitness_center_rounded), label: 'Exercises'),
        NavigationDestination(icon: Icon(Icons.playlist_add_check_rounded), label: 'Programs'),
      ],
    );
  }
}

class _SideRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _SideRail({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF0E141C),
        border: Border(right: BorderSide(color: Color(0xFF1A2330))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _BrandHeader(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                _NavItem(icon: Icons.dashboard_rounded, label: "Dashboard", i: 0, index: index, onTap: onTap),
                _NavItem(icon: Icons.people_alt_rounded, label: "Clients", i: 1, index: index, onTap: onTap),
                _NavItem(icon: Icons.calendar_month_rounded, label: "Calendar", i: 2, index: index, onTap: onTap),
                _NavItem(icon: Icons.fitness_center_rounded, label: "Exercises", i: 3, index: index, onTap: onTap),
                _NavItem(icon: Icons.playlist_add_check_rounded, label: "Programs", i: 4, index: index, onTap: onTap),
                const Divider(height: 26),
                _NavItem(icon: Icons.assignment_rounded, label: "Intake Forms", i: 5, index: index, onTap: onTap),
                _NavItem(icon: Icons.show_chart_rounded, label: "Progress", i: 6, index: index, onTap: onTap),
                _NavItem(icon: Icons.summarize_rounded, label: "Reports", i: 7, index: index, onTap: onTap),
                const Divider(height: 26),
                _NavItem(icon: Icons.settings_rounded, label: "Settings", i: 8, index: index, onTap: onTap),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF7C4DFF)]),
      ),
      child: const Row(
        children: [
          Icon(Icons.health_and_safety_rounded, color: Colors.black, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Simon Physio", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
                Text("Premium â€” Physio OS v1", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int i;
  final int index;
  final ValueChanged<int> onTap;

  const _NavItem({required this.icon, required this.label, required this.i, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = i == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? const Color(0xFF121D2A) : Colors.transparent,
            border: Border.all(color: selected ? const Color(0xFF2B3B52) : const Color(0x00000000)),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? const Color(0xFF00D4FF) : const Color(0xFF9FB0C6)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFC6D3E6),
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1A2330)),
        color: const Color(0xFF0B0F14),
      ),
      child: const Text(
        "MVP v1 focus:\nâ€¢ Client CRM\nâ€¢ Sessions + notes\nâ€¢ Home programs\nâ€¢ Intake forms\nâ€¢ Progress + reports\n\nNext: billing/NDIS, templates, cloud sync, AI assist.",
        style: TextStyle(color: Color(0xFF9FB0C6), height: 1.25),
      ),
    );
  }
}

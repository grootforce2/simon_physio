import 'package:flutter/material.dart';
import '../widgets/premium_shell_scaffold.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return PremiumShellScaffold(
      title: "Dashboard",
      subtitle: "Todays workload, key clients, and quick actions.",
      children: const [
        _Grid(),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid();
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: const [
        _KpiCard(title: "Appointments", value: "", hint: "Today"),
        _KpiCard(title: "Clients", value: "", hint: "Active"),
        _KpiCard(title: "Programs", value: "", hint: "Assigned"),
        _KpiCard(title: "Tasks", value: "", hint: "Outstanding"),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String hint;
  const _KpiCard({required this.title, required this.value, required this.hint});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF9FB0C6), fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(hint, style: const TextStyle(color: Color(0xFF9FB0C6))),
            ],
          ),
        ),
      ),
    );
  }
}

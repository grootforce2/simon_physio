import 'package:flutter/material.dart';
import '../widgets/premium_shell_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumShellScaffold(
      title: "Settings",
      subtitle: "Clinic profile, templates, backups.",
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "MVP v1: local settings.\nNext: encrypted backups + cloud sync + multi-clinic profiles.",
              style: TextStyle(color: Color(0xFF9FB0C6), height: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

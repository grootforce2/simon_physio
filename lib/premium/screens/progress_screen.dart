import 'package:flutter/material.dart';
import '../widgets/premium_shell_scaffold.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumShellScaffold(
      title: "Progress",
      subtitle: "Pain scores, ROM, strength, milestones.",
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "MVP v1: basic progress entries.\nNext: graphs per metric + adherence correlation + automated summaries.",
              style: TextStyle(color: Color(0xFF9FB0C6), height: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

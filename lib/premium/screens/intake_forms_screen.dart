import 'package:flutter/material.dart';
import '../widgets/premium_shell_scaffold.dart';

class IntakeFormsScreen extends StatelessWidget {
  const IntakeFormsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumShellScaffold(
      title: "Intake Forms",
      subtitle: "Assessments, consent, questionnaires.",
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "MVP v1: standard intake templates (pain scale, history, red flags).\nNext: shareable link + signature + PDF export.",
              style: TextStyle(color: Color(0xFF9FB0C6), height: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

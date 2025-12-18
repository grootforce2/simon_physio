import 'package:flutter/material.dart';
import '../widgets/premium_shell_scaffold.dart';

class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumShellScaffold(
      title: "Exercise Library",
      subtitle: "Templates, progressions, cues, contraindications.",
      actions: [
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add_rounded), label: const Text("New Exercise")),
      ],
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "MVP v1: exercise catalog + tags + notes.\nNext: video attachments, printable sheets, client-facing export.",
              style: TextStyle(color: Color(0xFF9FB0C6), height: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

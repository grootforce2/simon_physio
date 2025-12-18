import 'package:flutter/material.dart';
import '../widgets/premium_shell_scaffold.dart';

class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumShellScaffold(
      title: "Home Programs",
      subtitle: "Build, assign, and track adherence.",
      actions: [
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.playlist_add_rounded), label: const Text("New Program")),
      ],
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "MVP v1: program builder + assign to client.\nNext: patient portal, adherence check-ins, push reminders.",
              style: TextStyle(color: Color(0xFF9FB0C6), height: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

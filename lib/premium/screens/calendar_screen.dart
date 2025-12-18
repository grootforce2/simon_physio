import 'package:flutter/material.dart';
import '../widgets/premium_shell_scaffold.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumShellScaffold(
      title: "Calendar",
      subtitle: "Appointments, reminders, follow-ups.",
      actions: [
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add_rounded), label: const Text("New Appointment")),
      ],
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "MVP v1: local appointments + reminders.\nNext: Google Calendar sync + SMS/email reminders.",
              style: TextStyle(color: Color(0xFF9FB0C6), height: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

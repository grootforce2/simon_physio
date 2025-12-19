import 'package:flutter/material.dart';
import '../widgets/premium_shell_scaffold.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumShellScaffold(
      title: "Clients",
      subtitle: "CRM, injuries, goals, notes, and programs.",
      actions: [
        FilledButton.icon(onPressed: () { debugPrint('TODO-WIRE: lib\premium\screens\clients_screen.dart'); }, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text("New Client")),
      ],
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search clients (name, injury, phone, email)Ã¢â‚¬¦",
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(onPressed: () { debugPrint('TODO-WIRE: lib\premium\screens\clients_screen.dart'); }, icon: const Icon(Icons.filter_alt_rounded), label: const Text("Filter")),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "MVP v1: client list + client profile + session notes + assigned home programs.\n"
              "Next: intake import, consent, attachments, messaging, templates.",
              style: const TextStyle(color: Color(0xFF9FB0C6), height: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

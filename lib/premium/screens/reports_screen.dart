import 'package:flutter/material.dart';
import '../widgets/premium_shell_scaffold.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumShellScaffold(
      title: "Reports",
      subtitle: "Export-ready clinical notes and summaries.",
      actions: [
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text("Export PDF")),
      ],
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "MVP v1: report templates.\nNext: NDIS-ready reports + GP letters + outcome measures pack.",
              style: TextStyle(color: Color(0xFF9FB0C6), height: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

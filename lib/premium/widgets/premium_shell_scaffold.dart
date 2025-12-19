import 'package:flutter/material.dart';

class PremiumShellScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  const PremiumShellScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
  width: 22,
  height: 22,
  child: Image(image: AssetImage('assets/images/app_icon.png')),
),
// ASSET_SMOKETEST_IN_SHELL
const SizedBox(width: 10),
const Text('Assets OK', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF9FB0C6))),
const SizedBox(width: 12),
Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: Color(0xFF9FB0C6))),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ...actions,
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


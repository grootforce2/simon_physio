import 'package:flutter/material.dart';
import '../../core/widgets/app_card.dart';

class SessionPlayerScreen extends StatelessWidget {
  const SessionPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lower Back  Day 1')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hip Hinge Drill', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Keep ribs down, push hips back, neutral spine.', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _pill('3 sets'),
                      _pill('10 reps'),
                      _pill('45s rest'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AppCard(
                child: Center(
                  child: Text(
                    'Hybrid media will be wired next:\\nBundled preview + HD download + offline cache',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                      // Auto-wired by SIMON_ONECLICK_AUTOFIX_BUTTONS_AND_BUILD.ps1
                      // TODO: connect to video/exercise controller if available
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Action wired. Connect player logic next.')),
                      );
                    },
                child: const Text('Mark Step Complete'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _pill(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5FF),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(t),
  );
}

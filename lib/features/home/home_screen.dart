import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/app_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Simon Physio', style: Theme.of(context).textTheme.titleLarge)
                .animate().fadeIn(duration: 280.ms).slideY(begin: 0.08, end: 0),
            const SizedBox(height: 6),
            Text('Your plan for today', style: Theme.of(context).textTheme.bodyMedium)
                .animate().fadeIn(duration: 280.ms, delay: 80.ms),
            const SizedBox(height: 16),
            AppCard(
              onTap: () => Navigator.pushNamed(context, '/session'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today’s Session', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Lower Back – Day 1 • 12 min', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/session'),
                      child: const Text('Start'),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 320.ms, delay: 140.ms).slideY(begin: 0.08, end: 0),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Check-in', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Pain level today (0–10)', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Slider(value: 3, min: 0, max: 10, divisions: 10, onChanged: (_) {}),
                ],
              ),
            ).animate().fadeIn(duration: 320.ms, delay: 220.ms).slideY(begin: 0.08, end: 0),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class PlaceholderDashboard extends StatelessWidget {
  const PlaceholderDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Dashboard temporarily disabled')),
    );
  }
}
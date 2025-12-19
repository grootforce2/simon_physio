import 'package:flutter/material.dart';
import 'premium_dashboard.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _PremiumApp());
}


class _PremiumApp extends StatelessWidget {
  const _PremiumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simon Physio',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B82F6),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      ),
      home: const PremiumDashboard(),
    );
  }
}


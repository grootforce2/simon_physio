import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub async providers so screens using .when() compile.
/// Replace with real repos/providers later.
final patientsProvider = FutureProvider<List<dynamic>>((ref) async => <dynamic>[]);

final exercisesProvider = FutureProvider<List<dynamic>>((ref) async => <dynamic>[]);

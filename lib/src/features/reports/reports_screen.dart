import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:simon_physio/src/data/providers.dart';

import '../../data/repos.dart';
import '../patients/patients_screen.dart';
import 'package:simon_physio/src/data/providers.dart';

final completionSeriesProvider = FutureProvider.family<List<Map<String, Object?>>, String>((ref, pid) async {
  return ref.read(planRepoProvider).completionSeries(patientId: pid, days: 28);
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(patientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: patients.when(
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('Add a patient first.'));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: list.map((p) {
              final pid = p.id as String;
              final name = p.fullName as String;
              final series = ref.watch(completionSeriesProvider(pid));

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      series.when(
                        data: (rows) {
                          final m = <String, int>{};
                          for (final r in rows) {
                            m[r['day'] as String] = (r['c'] as int?) ?? 0;
                          }

                          final now = DateTime.now().toLocal();
                          final start = now.subtract(const Duration(days: 27));
                          final spots = <FlSpot>[];

                          String dayKey(DateTime d) {
                            final y = d.year.toString().padLeft(4, '0');
                            final mo = d.month.toString().padLeft(2, '0');
                            final da = d.day.toString().padLeft(2, '0');
                            return '$y-$mo-$da';
                          }

                          for (int i = 0; i < 28; i++) {
                            final d = start.add(Duration(days: i));
                            final key = dayKey(d);
                            final c = (m[key] ?? 0).toDouble();
                            spots.add(FlSpot(i.toDouble(), c));
                          }

                          final total = m.values.fold<int>(0, (a, b) => a + b);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Completions last 28 days: $total'),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 220,
                                child: LineChart(
                                  LineChartData(
                                    titlesData: const FlTitlesData(show: false),
                                    borderData: FlBorderData(show: true),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: spots,
                                        isCurved: true,
                                        dotData: const FlDotData(show: true),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simon_physio/src/data/providers.dart';

import '../../data/repos.dart';
import '../patients/patients_screen.dart';
import 'package:simon_physio/src/data/providers.dart';

final dueTodayProvider = FutureProvider.family<List<Map<String, Object?>>, String>((ref, pid) async {
  return ref.read(planRepoProvider).dueToday(patientId: pid);
});

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(patientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: patients.when(
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('Add a patient first.'));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: list.map((p) {
              final pid = p.id as String;
              final name = p.fullName as String;
              final due = ref.watch(dueTodayProvider(pid));
              return Card(
                child: ExpansionTile(
                  title: Text(name),
                  subtitle: const Text('Due today'),
                  children: [
                    due.when(
                      data: (rows) {
                        if (rows.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text('Nothing due today (based on plan frequency).'),
                          );
                        }
                        return Column(
                          children: rows.map((r) {
                            final planItemId = r['planItemId'] as String;
                            final planId = r['planId'] as String;
                            final exName = (r['customName'] as String?)?.trim().isNotEmpty == true
                                ? (r['customName'] as String)
                                : ((r['exerciseName'] as String?) ?? 'Exercise');
                            final reps = r['reps'] as int?;
                            final sets = r['sets'] as int?;
                            final done = (r['isDone'] as int?) == 1;

                            return CheckboxListTile(
                              value: done,
                              title: Text(exName),
                              subtitle: Text('Sets: ${sets ?? '-'}  Reps: ${reps ?? '-'}'),
                              onChanged: (v) async {
                                final mark = v ?? false;
                                await ref.read(planRepoProvider).toggleCompletion(
                                  patientId: pid,
                                  planId: planId,
                                  planItemId: planItemId,
                                  done: mark,
                                );
                                ref.invalidate(dueTodayProvider(pid));
                              },
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
                      error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e')),
                    )
                  ],
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


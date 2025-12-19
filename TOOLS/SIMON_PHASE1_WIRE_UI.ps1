$ErrorActionPreference = "Stop"

function INFO($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function OK($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function WARN($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function FAIL($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; throw $m }

function Write-Utf8NoBom([string]$path, [string]$content) {
    if ([string]::IsNullOrWhiteSpace($path)) { FAIL "Write-Utf8NoBom got empty path" }
    $dir = Split-Path -Path $path -Parent
    if ([string]::IsNullOrWhiteSpace($dir)) { $dir = "." }
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

# ---------- Repo + lib ----------
$repo = (Resolve-Path ".").Path
Set-Location $repo
OK "Repo: $repo"

$lib = Join-Path $repo "lib"
if (!(Test-Path $lib)) { FAIL "Missing lib folder: $lib (Run this from repo root)" }
OK "Lib:  $lib"

# ---------- Find db.dart + repos.dart anywhere under lib ----------
INFO "Locating db.dart / repos.dart under lib (no assumptions)..."
$dbFile = Get-ChildItem -Path $lib -Recurse -File -Filter "db.dart" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\data\\db\.dart$" -or (Get-Content -Raw $_.FullName -ErrorAction SilentlyContinue) -match "class\s+AppDb" } |
    Select-Object -First 1

$reposFile = Get-ChildItem -Path $lib -Recurse -File -Filter "repos.dart" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\data\\repos\.dart$" -or (Get-Content -Raw $_.FullName -ErrorAction SilentlyContinue) -match "class\s+PatientsRepo" } |
    Select-Object -First 1

if (!$dbFile) { FAIL "Could not locate db.dart under lib. Search manually for 'class AppDb'." }
if (!$reposFile) { FAIL "Could not locate repos.dart under lib. Search manually for 'class PatientsRepo'." }

OK "db.dart:    $($dbFile.FullName)"
OK "repos.dart: $($reposFile.FullName)"

# ---------- Feature file targets (create if missing) ----------
$plansScreen = Join-Path $lib "src\features\plans\plans_screen.dart"
$todayScreen = Join-Path $lib "src\features\plans\today_screen.dart"
$reportsScreen = Join-Path $lib "src\features\reports\reports_screen.dart"

# ---------- Write Plans screen ----------
INFO "Writing Plans screen -> $plansScreen"
Write-Utf8NoBom $plansScreen @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repos.dart';
import '../patients/patients_screen.dart';

final patientPlansProvider = FutureProvider.family<List<Map<String, Object?>>, String>((ref, pid) async {
  return ref.read(planRepoProvider).listPlansByPatient(pid);
});

final planItemsProvider = FutureProvider.family<List<Map<String, Object?>>, String>((ref, planId) async {
  return ref.read(planRepoProvider).listPlanItems(planId);
});

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(patientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Plans')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
        onPressed: () async {
          final list = await patients.future;
          if (list.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a patient first.')));
            return;
          }
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => _CreatePlanDialog(patients: list),
          );
          if (ok == true) {
            ref.invalidate(patientsProvider);
          }
        },
      ),
      body: patients.when(
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('No patients yet.'));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: list.map((p) {
              final pid = p.id as String;
              final name = p.fullName as String;
              final plans = ref.watch(patientPlansProvider(pid));
              return Card(
                child: ExpansionTile(
                  title: Text(name),
                  subtitle: const Text('Plans'),
                  children: [
                    plans.when(
                      data: (rows) {
                        if (rows.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text('No plans yet. Create one.'),
                          );
                        }
                        return Column(
                          children: rows.map((r) {
                            final planId = r['id'] as String;
                            final title = (r['title'] as String?) ?? 'Rehab Plan';
                            final active = (r['active'] as int?) == 1;
                            final startDate = r['startDate'] as String? ?? '';
                            return ListTile(
                              title: Text(title),
                              subtitle: Text('Start: $startDate${active ? '' : ' (inactive)'}'),
                              trailing: Switch(
                                value: active,
                                onChanged: (v) async {
                                  await ref.read(planRepoProvider).setPlanActive(planId, v);
                                  ref.invalidate(patientPlansProvider(pid));
                                },
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlanDetailScreen(
                                    patientId: pid,
                                    planId: planId,
                                    patientName: name,
                                    planTitle: title,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
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

class PlanDetailScreen extends ConsumerWidget {
  final String patientId;
  final String planId;
  final String patientName;
  final String planTitle;

  const PlanDetailScreen({
    super.key,
    required this.patientId,
    required this.planId,
    required this.patientName,
    required this.planTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(planItemsProvider(planId));
    return Scaffold(
      appBar: AppBar(title: Text('$planTitle  $patientName')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => _AddPlanItemDialog(planId: planId),
          );
          if (ok == true) ref.invalidate(planItemsProvider(planId));
        },
      ),
      body: items.when(
        data: (rows) {
          if (rows.isEmpty) return const Center(child: Text('No plan items yet. Add exercises.'));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: rows.map((r) {
              final id = r['id'] as String;
              final exName = (r['customName'] as String?)?.trim().isNotEmpty == true
                  ? (r['customName'] as String)
                  : ((r['exerciseName'] as String?) ?? 'Exercise');
              final reps = r['reps'] as int?;
              final sets = r['sets'] as int?;
              final freq = r['freqPerWeek'] as int? ?? 3;
              final notes = (r['notes'] as String?) ?? '';
              return Card(
                child: ListTile(
                  title: Text(exName),
                  subtitle: Text('Sets: ${sets ?? '-'}  Reps: ${reps ?? '-'}  Freq/week: $freq${notes.isEmpty ? '' : '\n$notes'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref.read(planRepoProvider).deletePlanItem(id);
                      ref.invalidate(planItemsProvider(planId));
                    },
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

class _CreatePlanDialog extends ConsumerStatefulWidget {
  final List<dynamic> patients;
  const _CreatePlanDialog({required this.patients});

  @override
  ConsumerState<_CreatePlanDialog> createState() => _CreatePlanDialogState();
}

class _CreatePlanDialogState extends ConsumerState<_CreatePlanDialog> {
  String? _pid;
  final _title = TextEditingController(text: 'Rehab Plan');
  DateTime _start = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pid = widget.patients.first.id as String;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Plan'),
      content: SizedBox(
        width: 520,
        child: ListView(
          shrinkWrap: true,
          children: [
            DropdownButtonFormField<String>(
              value: _pid,
              items: widget.patients.map((p) => DropdownMenuItem(value: p.id as String, child: Text(p.fullName as String))).toList(),
              onChanged: (v) => setState(() => _pid = v),
              decoration: const InputDecoration(labelText: 'Patient'),
            ),
            const SizedBox(height: 8),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Plan title')),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Start date'),
              subtitle: Text('${_start.year}-${_start.month.toString().padLeft(2, '0')}-${_start.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _start);
                if (d == null) return;
                setState(() => _start = DateTime(d.year, d.month, d.day));
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (_pid == null) return;
            final planId = await ref.read(planRepoProvider).createPlan(patientId: _pid!, title: _title.text, startDate: _start);
            if (!mounted) return;
            Navigator.pop(context, true);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlanDetailScreen(
                  patientId: _pid!,
                  planId: planId,
                  patientName: '',
                  planTitle: _title.text.trim().isEmpty ? 'Rehab Plan' : _title.text.trim(),
                ),
              ),
            );
          },
          child: const Text('Create'),
        )
      ],
    );
  }
}

class _AddPlanItemDialog extends ConsumerStatefulWidget {
  final String planId;
  const _AddPlanItemDialog({required this.planId});

  @override
  ConsumerState<_AddPlanItemDialog> createState() => _AddPlanItemDialogState();
}

class _AddPlanItemDialogState extends ConsumerState<_AddPlanItemDialog> {
  String? _exerciseId;
  final _customName = TextEditingController();
  final _reps = TextEditingController(text: '10');
  final _sets = TextEditingController(text: '3');
  final _freq = TextEditingController(text: '3');
  final _notes = TextEditingController();

  int? _i(TextEditingController c) => int.tryParse(c.text.trim());

  @override
  void dispose() {
    _customName.dispose();
    _reps.dispose();
    _sets.dispose();
    _freq.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ex = ref.watch(exercisesProvider);

    return AlertDialog(
      title: const Text('Add Plan Exercise'),
      content: SizedBox(
        width: 520,
        child: ex.when(
          data: (list) {
            if (list.isEmpty) {
              return const Text('No exercise templates found. Add exercises first.');
            }
            _exerciseId ??= list.first.id;
            return ListView(
              shrinkWrap: true,
              children: [
                DropdownButtonFormField<String>(
                  value: _exerciseId,
                  items: list.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                  onChanged: (v) => setState(() => _exerciseId = v),
                  decoration: const InputDecoration(labelText: 'Exercise template'),
                ),
                TextField(controller: _customName, decoration: const InputDecoration(labelText: 'Custom name (optional)')),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: _reps, decoration: const InputDecoration(labelText: 'Reps'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _sets, decoration: const InputDecoration(labelText: 'Sets'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _freq, decoration: const InputDecoration(labelText: 'Freq/week'))),
                ]),
                const SizedBox(height: 8),
                TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 2),
              ],
            );
          },
          loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final exList = await ref.read(exercisesProvider.future);
            if (exList.isEmpty) return;
            final exId = _exerciseId ?? exList.first.id;
            await ref.read(planRepoProvider).addPlanItem(
              planId: widget.planId,
              exerciseId: exId,
              customName: _customName.text,
              reps: _i(_reps),
              sets: _i(_sets),
              freqPerWeek: _i(_freq),
              notes: _notes.text,
            );
            if (!mounted) return;
            Navigator.pop(context, true);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
'@

# ---------- Write Today screen ----------
INFO "Writing Today screen -> $todayScreen"
Write-Utf8NoBom $todayScreen @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repos.dart';
import '../patients/patients_screen.dart';

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
'@

# ---------- Write Reports screen ----------
INFO "Writing Reports screen -> $reportsScreen"
Write-Utf8NoBom $reportsScreen @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../data/repos.dart';
import '../patients/patients_screen.dart';

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
'@

OK "Wrote Plans/Today/Reports screens"

# ---------- Try to locate router/nav file ----------
INFO "Searching for router/nav file to wire screens..."
$dartFiles = Get-ChildItem -Path $lib -Recurse -File -Filter "*.dart" -ErrorAction SilentlyContinue

$routerHits = $dartFiles | Where-Object {
    $raw = Get-Content -Raw $_.FullName -ErrorAction SilentlyContinue
    $raw -match "BottomNavigationBar|NavigationRail|GoRouter|MaterialApp\.router|_screens\s*=\s*\["
} | Select-Object -First 5

if (!$routerHits) {
    WARN "No obvious router/nav file found. You'll wire these manually."
    WARN "Add tabs/routes for: TodayScreen(), PlansScreen(), ReportsScreen()"
}
else {
    OK "Top router candidates:"
    $routerHits | ForEach-Object { Write-Host " - $($_.FullName)" }
    WARN "Tell me which one is the real tabs/router file and Iâ€™ll give you the exact patch for it."
}

OK "Phase-1 UI files written. Next step: wire them into navigation."


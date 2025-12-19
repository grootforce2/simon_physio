$ErrorActionPreference = "Stop"

function INFO($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function OK($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function WARN($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function FAIL($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; throw $m }

$repo = (Get-Location).Path
if (!(Test-Path (Join-Path $repo "pubspec.yaml"))) { FAIL "Run this from the Flutter repo root (where pubspec.yaml exists)." }

# ---- helpers
function Ensure-Dir($p) { New-Item -ItemType Directory -Force $p | Out-Null }
function Write-Utf8NoBom($path, $content) {
    Ensure-Dir (Split-Path $path)
    [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
}
function Patch-Pubspec([string]$pubPath) {
    $raw = Get-Content $pubPath -Raw

    if ($raw -notmatch "(?m)^flutter:\s*$") { $raw += "`nflutter:`n  uses-material-design: true`n" }
    if ($raw -notmatch "(?m)^\s{2}uses-material-design:\s*true\s*$") {
        $raw = [regex]::Replace($raw, "(?m)^flutter:\s*$", "flutter:`n  uses-material-design: true", 1)
    }

    # ensure assets
    if ($raw -notmatch "(?m)^\s{2}assets:\s*$") {
        $insert = "  uses-material-design: true`n  assets:`n    - assets/images/`n    - assets/videos/"
        $raw = [regex]::Replace($raw, "(?m)^\s{2}uses-material-design:\s*true\s*$", $insert, 1)
    }
    else {
        if ($raw -notmatch "(?m)^\s{4}-\s+assets/images/\s*$") { $raw = $raw -replace "(?m)^\s{2}assets:\s*$", "  assets:`n    - assets/images/" }
        if ($raw -notmatch "(?m)^\s{4}-\s+assets/videos/\s*$") { $raw = $raw -replace "(?m)^\s{2}assets:\s*$", "  assets:`n    - assets/images/`n    - assets/videos/" }
    }

    # dependencies we need for a REAL working MVP
    $needDeps = @(
        "flutter_riverpod",
        "go_router",
        "intl",
        "sqflite_common_ffi",
        "path",
        "uuid",
        "fl_chart"
    )

    if ($raw -notmatch "(?m)^dependencies:\s*$") { FAIL "pubspec.yaml missing 'dependencies:' block." }

    foreach ($d in $needDeps) {
        if ($raw -notmatch "(?m)^\s+$([regex]::Escape($d))\s*:") {
            INFO "Adding dependency: $d"
            $raw = [regex]::Replace($raw, "(?m)^dependencies:\s*$", "dependencies:`n  ${d}: any", 1)
        }
    }

    Write-Utf8NoBom $pubPath $raw
}

# ---- prep
OK "Repo: $repo"
Ensure-Dir (Join-Path $repo "assets\images")
Ensure-Dir (Join-Path $repo "assets\videos")

Patch-Pubspec (Join-Path $repo "pubspec.yaml")
OK "pubspec.yaml ensured (deps + assets)"

# ---- write MVP code (standardized structure)
$lib = Join-Path $repo "lib"
Ensure-Dir $lib

# core app + router
Write-Utf8NoBom (Join-Path $lib "main.dart") @'
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'src/app.dart';

void main() {
  // Windows/Linux desktop SQLite
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ProviderScope(child: SimonPhysioApp()));
}
'@

Write-Utf8NoBom (Join-Path $lib "src\app.dart") @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';
import 'data/db.dart';
import 'features/reminders/reminder_service.dart';

class SimonPhysioApp extends ConsumerStatefulWidget {
  const SimonPhysioApp({super.key});

  @override
  ConsumerState<SimonPhysioApp> createState() => _SimonPhysioAppState();
}

class _SimonPhysioAppState extends ConsumerState<SimonPhysioApp> {
  @override
  void initState() {
    super.initState();
    // initialize DB + run reminder scan on startup
    Future.microtask(() async {
      await ref.read(dbProvider).init();
      await ref.read(reminderServiceProvider).runStartupScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Simon Physio',
      theme: buildTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
'@

Write-Utf8NoBom (Join-Path $lib "src\theme.dart") @'
import 'package:flutter/material.dart';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF2C7BE5),
  );
  return base.copyWith(
    cardTheme: const CardTheme(
      elevation: 1,
      margin: EdgeInsets.all(12),
    ),
  );
}
'@

Write-Utf8NoBom (Join-Path $lib "src\router.dart") @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/dashboard/premium_dashboard.dart';
import 'features/patients/patients_screen.dart';
import 'features/patients/patient_detail_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/exercises/exercises_screen.dart';
import 'features/plans/plans_screen.dart';
import 'features/reports/reports_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const PremiumDashboard()),
      GoRoute(path: '/patients', builder: (_, __) => const PatientsScreen()),
      GoRoute(
        path: '/patients/:id',
        builder: (_, s) => PatientDetailScreen(patientId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
      GoRoute(path: '/exercises', builder: (_, __) => const ExercisesScreen()),
      GoRoute(path: '/plans', builder: (_, __) => const PlansScreen()),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
    ],
  );
});
'@

# ---- DATA LAYER
Write-Utf8NoBom (Join-Path $lib "src\data\db.dart") @'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final dbProvider = Provider<AppDb>((ref) => AppDb());

class AppDb {
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = p.join(await databaseFactory.getDatabasesPath(), 'simon_physio.db');
    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE patients(
              id TEXT PRIMARY KEY,
              fullName TEXT NOT NULL,
              phone TEXT,
              email TEXT,
              dob TEXT,
              notes TEXT,
              createdAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE appointments(
              id TEXT PRIMARY KEY,
              patientId TEXT NOT NULL,
              startTs INTEGER NOT NULL,
              endTs INTEGER NOT NULL,
              title TEXT,
              location TEXT,
              reminderMins INTEGER DEFAULT 60,
              createdAt INTEGER NOT NULL,
              FOREIGN KEY(patientId) REFERENCES patients(id) ON DELETE CASCADE
            );
          ''');
          await db.execute('''
            CREATE TABLE session_notes(
              id TEXT PRIMARY KEY,
              patientId TEXT NOT NULL,
              ts INTEGER NOT NULL,
              body TEXT NOT NULL,
              createdAt INTEGER NOT NULL,
              FOREIGN KEY(patientId) REFERENCES patients(id) ON DELETE CASCADE
            );
          ''');
          await db.execute('''
            CREATE TABLE exercises(
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT,
              defaultReps INTEGER,
              defaultSets INTEGER,
              defaultFreqPerWeek INTEGER,
              createdAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE plans(
              id TEXT PRIMARY KEY,
              patientId TEXT NOT NULL,
              name TEXT NOT NULL,
              createdAt INTEGER NOT NULL,
              FOREIGN KEY(patientId) REFERENCES patients(id) ON DELETE CASCADE
            );
          ''');
          await db.execute('''
            CREATE TABLE plan_items(
              id TEXT PRIMARY KEY,
              planId TEXT NOT NULL,
              exerciseId TEXT NOT NULL,
              reps INTEGER,
              sets INTEGER,
              freqPerWeek INTEGER,
              createdAt INTEGER NOT NULL,
              FOREIGN KEY(planId) REFERENCES plans(id) ON DELETE CASCADE,
              FOREIGN KEY(exerciseId) REFERENCES exercises(id)
            );
          ''');
          await db.execute('''
            CREATE TABLE completions(
              id TEXT PRIMARY KEY,
              patientId TEXT NOT NULL,
              exerciseId TEXT NOT NULL,
              ts INTEGER NOT NULL,
              repsDone INTEGER,
              setsDone INTEGER,
              painScore INTEGER,
              difficultyScore INTEGER,
              createdAt INTEGER NOT NULL,
              FOREIGN KEY(patientId) REFERENCES patients(id) ON DELETE CASCADE,
              FOREIGN KEY(exerciseId) REFERENCES exercises(id)
            );
          ''');
        },
      ),
    );
  }

  Database get db {
    final d = _db;
    if (d == null) throw StateError('DB not initialized');
    return d;
  }
}
'@

# ---- MODELS
Write-Utf8NoBom (Join-Path $lib "src\data\models.dart") @'
class Patient {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? dob; // ISO yyyy-mm-dd
  final String? notes;
  final int createdAt;

  Patient({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.dob,
    this.notes,
    required this.createdAt,
  });

  factory Patient.fromMap(Map<String, Object?> m) => Patient(
    id: m['id'] as String,
    fullName: m['fullName'] as String,
    phone: m['phone'] as String?,
    email: m['email'] as String?,
    dob: m['dob'] as String?,
    notes: m['notes'] as String?,
    createdAt: m['createdAt'] as int,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'fullName': fullName,
    'phone': phone,
    'email': email,
    'dob': dob,
    'notes': notes,
    'createdAt': createdAt,
  };
}

class Appointment {
  final String id;
  final String patientId;
  final int startTs;
  final int endTs;
  final String? title;
  final String? location;
  final int reminderMins;
  final int createdAt;

  Appointment({
    required this.id,
    required this.patientId,
    required this.startTs,
    required this.endTs,
    this.title,
    this.location,
    this.reminderMins = 60,
    required this.createdAt,
  });

  factory Appointment.fromMap(Map<String, Object?> m) => Appointment(
    id: m['id'] as String,
    patientId: m['patientId'] as String,
    startTs: m['startTs'] as int,
    endTs: m['endTs'] as int,
    title: m['title'] as String?,
    location: m['location'] as String?,
    reminderMins: (m['reminderMins'] as int?) ?? 60,
    createdAt: m['createdAt'] as int,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'patientId': patientId,
    'startTs': startTs,
    'endTs': endTs,
    'title': title,
    'location': location,
    'reminderMins': reminderMins,
    'createdAt': createdAt,
  };
}

class SessionNote {
  final String id;
  final String patientId;
  final int ts;
  final String body;
  final int createdAt;

  SessionNote({
    required this.id,
    required this.patientId,
    required this.ts,
    required this.body,
    required this.createdAt,
  });

  factory SessionNote.fromMap(Map<String, Object?> m) => SessionNote(
    id: m['id'] as String,
    patientId: m['patientId'] as String,
    ts: m['ts'] as int,
    body: m['body'] as String,
    createdAt: m['createdAt'] as int,
  );
}

class Exercise {
  final String id;
  final String name;
  final String? description;
  final int? defaultReps;
  final int? defaultSets;
  final int? defaultFreqPerWeek;
  final int createdAt;

  Exercise({
    required this.id,
    required this.name,
    this.description,
    this.defaultReps,
    this.defaultSets,
    this.defaultFreqPerWeek,
    required this.createdAt,
  });

  factory Exercise.fromMap(Map<String, Object?> m) => Exercise(
    id: m['id'] as String,
    name: m['name'] as String,
    description: m['description'] as String?,
    defaultReps: m['defaultReps'] as int?,
    defaultSets: m['defaultSets'] as int?,
    defaultFreqPerWeek: m['defaultFreqPerWeek'] as int?,
    createdAt: m['createdAt'] as int,
  );
}
'@

# ---- REPOS + PROVIDERS
Write-Utf8NoBom (Join-Path $lib "src\data\repos.dart") @'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'db.dart';
import 'models.dart';

final _uuid = Uuid();

final patientRepoProvider = Provider<PatientRepo>((ref) => PatientRepo(ref.read(dbProvider)));
final calendarRepoProvider = Provider<CalendarRepo>((ref) => CalendarRepo(ref.read(dbProvider)));
final notesRepoProvider = Provider<NotesRepo>((ref) => NotesRepo(ref.read(dbProvider)));
final exerciseRepoProvider = Provider<ExerciseRepo>((ref) => ExerciseRepo(ref.read(dbProvider)));

class PatientRepo {
  final AppDb _db;
  PatientRepo(this._db);

  Future<List<Patient>> list() async {
    final rows = await _db.db.query('patients', orderBy: 'createdAt DESC');
    return rows.map(Patient.fromMap).toList();
  }

  Future<Patient?> getById(String id) async {
    final rows = await _db.db.query('patients', where: 'id=?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Patient.fromMap(rows.first);
  }

  Future<String> upsert({
    String? id,
    required String fullName,
    String? phone,
    String? email,
    String? dob,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final pid = id ?? _uuid.v4();
    await _db.db.insert(
      'patients',
      Patient(
        id: pid,
        fullName: fullName.trim(),
        phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
        email: email?.trim().isEmpty == true ? null : email?.trim(),
        dob: dob?.trim().isEmpty == true ? null : dob?.trim(),
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        createdAt: now,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return pid;
  }

  Future<void> delete(String id) async {
    await _db.db.delete('patients', where: 'id=?', whereArgs: [id]);
  }
}

class CalendarRepo {
  final AppDb _db;
  CalendarRepo(this._db);

  Future<List<Map<String, Object?>>> upcoming({int days = 14}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final end = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
    return _db.db.rawQuery('''
      SELECT a.*, p.fullName as patientName
      FROM appointments a
      JOIN patients p ON p.id = a.patientId
      WHERE a.startTs BETWEEN ? AND ?
      ORDER BY a.startTs ASC
    ''', [now, end]);
  }

  Future<void> addAppointment({
    required String patientId,
    required DateTime start,
    required DateTime end,
    String? title,
    String? location,
    int reminderMins = 60,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.db.insert('appointments', {
      'id': _uuid.v4(),
      'patientId': patientId,
      'startTs': start.millisecondsSinceEpoch,
      'endTs': end.millisecondsSinceEpoch,
      'title': title,
      'location': location,
      'reminderMins': reminderMins,
      'createdAt': now,
    });
  }
}

class NotesRepo {
  final AppDb _db;
  NotesRepo(this._db);

  Future<List<SessionNote>> listByPatient(String patientId) async {
    final rows = await _db.db.query(
      'session_notes',
      where: 'patientId=?',
      whereArgs: [patientId],
      orderBy: 'ts DESC',
    );
    return rows.map(SessionNote.fromMap).toList();
  }

  Future<void> add(String patientId, String body) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.db.insert('session_notes', {
      'id': _uuid.v4(),
      'patientId': patientId,
      'ts': now,
      'body': body.trim(),
      'createdAt': now,
    });
  }
}

class ExerciseRepo {
  final AppDb _db;
  ExerciseRepo(this._db);

  Future<List<Exercise>> list() async {
    final rows = await _db.db.query('exercises', orderBy: 'createdAt DESC');
    return rows.map(Exercise.fromMap).toList();
  }

  Future<void> add({
    required String name,
    String? description,
    int? defaultReps,
    int? defaultSets,
    int? defaultFreqPerWeek,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.db.insert('exercises', {
      'id': _uuid.v4(),
      'name': name.trim(),
      'description': description?.trim(),
      'defaultReps': defaultReps,
      'defaultSets': defaultSets,
      'defaultFreqPerWeek': defaultFreqPerWeek,
      'createdAt': now,
    });
  }
}
'@

# ---- Reminder service (in-app startup scan)
Write-Utf8NoBom (Join-Path $lib "src\features\reminders\reminder_service.dart") @'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repos.dart';

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(ref);
});

class ReminderService {
  final Ref ref;
  ReminderService(this.ref);

  /// Basic MVP: on startup, scan next 24h appointments + show in dashboard banner.
  /// (OS notifications can be added later without breaking the app.)
  Future<void> runStartupScan() async {
    // just warming repos; dashboard reads upcoming directly
    await ref.read(calendarRepoProvider).upcoming(days: 1);
  }
}
'@

# ---- UI: Premium Dashboard
Write-Utf8NoBom (Join-Path $lib "src\features\dashboard\premium_dashboard.dart") @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/repos.dart';

final upcomingProvider = FutureProvider((ref) async {
  return ref.read(calendarRepoProvider).upcoming(days: 7);
});

class PremiumDashboard extends ConsumerWidget {
  const PremiumDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simon Physio â€” Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _QuickActions(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Upcoming (7 days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  upcoming.when(
                    data: (rows) {
                      if (rows.isEmpty) return const Text('No upcoming appointments.');
                      final fmt = DateFormat('EEE dd MMM, h:mm a');
                      return Column(
                        children: rows.take(8).map((r) {
                          final start = DateTime.fromMillisecondsSinceEpoch(r['startTs'] as int);
                          final name = (r['patientName'] as String?) ?? 'Patient';
                          final title = (r['title'] as String?) ?? 'Appointment';
                          return ListTile(
                            dense: true,
                            title: Text('$title â€” $name'),
                            subtitle: Text(fmt.format(start)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/calendar'),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: LinearProgressIndicator(),
                    ),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget tile({required String title, required IconData icon, required String route}) {
      return Expanded(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go(route),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Icon(icon, size: 28),
                  const SizedBox(height: 8),
                  Text(title, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(title: 'Patients', icon: Icons.people, route: '/patients'),
        tile(title: 'Calendar', icon: Icons.calendar_month, route: '/calendar'),
        tile(title: 'Exercises', icon: Icons.fitness_center, route: '/exercises'),
        tile(title: 'Plans', icon: Icons.playlist_add_check, route: '/plans'),
        tile(title: 'Reports', icon: Icons.insights, route: '/reports'),
      ],
    );
  }
}
'@

# ---- Patients screens (CRUD)
Write-Utf8NoBom (Join-Path $lib "src\features\patients\patients_screen.dart") @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/repos.dart';

final patientsProvider = FutureProvider((ref) async => ref.read(patientRepoProvider).list());

class PatientsScreen extends ConsumerWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(patientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Patients')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => const _PatientDialog(),
          );
          if (ok == true) {
            ref.invalidate(patientsProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: patients.when(
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('No patients yet. Add your first patient.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              return Card(
                child: ListTile(
                  title: Text(p.fullName),
                  subtitle: Text([p.phone, p.email].where((x) => x != null && x!.isNotEmpty).join(' â€¢ ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/patients/${p.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _PatientDialog extends ConsumerStatefulWidget {
  const _PatientDialog();

  @override
  ConsumerState<_PatientDialog> createState() => _PatientDialogState();
}

class _PatientDialogState extends ConsumerState<_PatientDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _dob = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _email.dispose(); _dob.dispose(); _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Patient'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _dob, decoration: const InputDecoration(labelText: 'DOB (YYYY-MM-DD)')),
            TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (_name.text.trim().isEmpty) return;
            await ref.read(patientRepoProvider).upsert(
              fullName: _name.text,
              phone: _phone.text,
              email: _email.text,
              dob: _dob.text,
              notes: _notes.text,
            );
            if (!mounted) return;
            Navigator.pop(context, true);
          },
          child: const Text('Save'),
        )
      ],
    );
  }
}
'@

Write-Utf8NoBom (Join-Path $lib "src\features\patients\patient_detail_screen.dart") @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repos.dart';

final patientProvider = FutureProvider.family((ref, String id) async => ref.read(patientRepoProvider).getById(id));
final notesProvider = FutureProvider.family((ref, String pid) async => ref.read(notesRepoProvider).listByPatient(pid));

class PatientDetailScreen extends ConsumerWidget {
  final String patientId;
  const PatientDetailScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientProvider(patientId));
    final notes = ref.watch(notesProvider(patientId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete patient?'),
                  content: const Text('This deletes the patient and all linked notes/appointments.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(patientRepoProvider).delete(patientId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.note_add),
        label: const Text('Add Note'),
        onPressed: () async {
          final body = await showDialog<String?>(
            context: context,
            builder: (_) => const _AddNoteDialog(),
          );
          if (body != null && body.trim().isNotEmpty) {
            await ref.read(notesRepoProvider).add(patientId, body);
            ref.invalidate(notesProvider(patientId));
          }
        },
      ),
      body: patient.when(
        data: (p) {
          if (p == null) return const Center(child: Text('Patient not found.'));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: ListTile(
                  title: Text(p.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  subtitle: Text([
                    if (p.phone != null) 'Phone: ${p.phone}',
                    if (p.email != null) 'Email: ${p.email}',
                    if (p.dob != null) 'DOB: ${p.dob}',
                  ].join('\n')),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Session Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      notes.when(
                        data: (list) {
                          if (list.isEmpty) return const Text('No notes yet.');
                          final fmt = DateFormat('dd MMM yyyy, h:mm a');
                          return Column(
                            children: list.take(30).map((n) => ListTile(
                              dense: true,
                              title: Text(fmt.format(DateTime.fromMillisecondsSinceEpoch(n.ts))),
                              subtitle: Text(n.body),
                            )).toList(),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _AddNoteDialog extends StatefulWidget {
  const _AddNoteDialog();

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add session note'),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _c,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Write session notesâ€¦'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _c.text), child: const Text('Save')),
      ],
    );
  }
}
'@

# ---- Calendar
Write-Utf8NoBom (Join-Path $lib "src\features\calendar\calendar_screen.dart") @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repos.dart';
import '../patients/patients_screen.dart';

final calendarProvider = FutureProvider((ref) async => ref.read(calendarRepoProvider).upcoming(days: 30));

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(calendarProvider);
    final patients = ref.watch(patientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Appointment'),
        onPressed: () async {
          final list = await patients.future;
          if (list.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a patient first.')));
            return;
          }
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => _AddApptDialog(patients: list),
          );
          if (ok == true) {
            ref.invalidate(calendarProvider);
          }
        },
      ),
      body: upcoming.when(
        data: (rows) {
          if (rows.isEmpty) return const Center(child: Text('No appointments yet.'));
          final fmt = DateFormat('EEE dd MMM, h:mm a');
          return ListView(
            padding: const EdgeInsets.all(12),
            children: rows.map((r) {
              final start = DateTime.fromMillisecondsSinceEpoch(r['startTs'] as int);
              final end = DateTime.fromMillisecondsSinceEpoch(r['endTs'] as int);
              final name = (r['patientName'] as String?) ?? 'Patient';
              final title = (r['title'] as String?) ?? 'Appointment';
              final loc = (r['location'] as String?) ?? '';
              return Card(
                child: ListTile(
                  title: Text('$title â€” $name'),
                  subtitle: Text('${fmt.format(start)} â†’ ${fmt.format(end)}${loc.isEmpty ? '' : '\n$loc'}'),
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

class _AddApptDialog extends StatefulWidget {
  final List<dynamic> patients;
  const _AddApptDialog({required this.patients});

  @override
  State<_AddApptDialog> createState() => _AddApptDialogState();
}

class _AddApptDialogState extends State<_AddApptDialog> {
  String? _pid;
  DateTime _start = DateTime.now().add(const Duration(hours: 2));
  DateTime _end = DateTime.now().add(const Duration(hours: 3));
  final _title = TextEditingController(text: 'Physio Session');
  final _loc = TextEditingController();
  int _reminder = 60;

  @override
  void initState() {
    super.initState();
    _pid = widget.patients.first.id as String;
  }

  @override
  void dispose() {
    _title.dispose();
    _loc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      return AlertDialog(
        title: const Text('New Appointment'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: [
              DropdownButtonFormField<String>(
                value: _pid,
                items: widget.patients.map((p) {
                  return DropdownMenuItem(value: p.id as String, child: Text(p.fullName as String));
                }).toList(),
                onChanged: (v) => setState(() => _pid = v),
                decoration: const InputDecoration(labelText: 'Patient'),
              ),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: _loc, decoration: const InputDecoration(labelText: 'Location')),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Start'),
                subtitle: Text(_start.toString()),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _start);
                  if (d == null) return;
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
                  if (t == null) return;
                  setState(() => _start = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  if (_end.isBefore(_start)) setState(() => _end = _start.add(const Duration(hours: 1)));
                },
              ),
              ListTile(
                title: const Text('End'),
                subtitle: Text(_end.toString()),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _end);
                  if (d == null) return;
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_end));
                  if (t == null) return;
                  setState(() => _end = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                },
              ),
              DropdownButtonFormField<int>(
                value: _reminder,
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15 min before')),
                  DropdownMenuItem(value: 30, child: Text('30 min before')),
                  DropdownMenuItem(value: 60, child: Text('60 min before')),
                  DropdownMenuItem(value: 120, child: Text('2 hours before')),
                ],
                onChanged: (v) => setState(() => _reminder = v ?? 60),
                decoration: const InputDecoration(labelText: 'Reminder'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (_pid == null) return;
              await ref.read(calendarRepoProvider).addAppointment(
                patientId: _pid!,
                start: _start,
                end: _end,
                title: _title.text,
                location: _loc.text,
                reminderMins: _reminder,
              );
              if (!mounted) return;
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      );
    });
  }
}
'@

# ---- Exercises
Write-Utf8NoBom (Join-Path $lib "src\features\exercises\exercises_screen.dart") @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repos.dart';

final exercisesProvider = FutureProvider((ref) async => ref.read(exerciseRepoProvider).list());

class ExercisesScreen extends ConsumerWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ex = ref.watch(exercisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final ok = await showDialog<bool>(context: context, builder: (_) => const _ExerciseDialog());
          if (ok == true) ref.invalidate(exercisesProvider);
        },
      ),
      body: ex.when(
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('No exercises yet. Add some templates.'));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: list.map((e) => Card(
              child: ListTile(
                title: Text(e.name),
                subtitle: Text(e.description ?? ''),
              ),
            )).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ExerciseDialog extends ConsumerStatefulWidget {
  const _ExerciseDialog();

  @override
  ConsumerState<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends ConsumerState<_ExerciseDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _reps = TextEditingController(text: '10');
  final _sets = TextEditingController(text: '3');
  final _freq = TextEditingController(text: '3');

  @override
  void dispose() {
    _name.dispose(); _desc.dispose(); _reps.dispose(); _sets.dispose(); _freq.dispose();
    super.dispose();
  }

  int? _i(TextEditingController c) => int.tryParse(c.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Exercise'),
      content: SizedBox(
        width: 520,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            Row(children: [
              Expanded(child: TextField(controller: _reps, decoration: const InputDecoration(labelText: 'Default reps'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _sets, decoration: const InputDecoration(labelText: 'Default sets'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _freq, decoration: const InputDecoration(labelText: 'Freq/week'))),
            ])
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (_name.text.trim().isEmpty) return;
            await ref.read(exerciseRepoProvider).add(
              name: _name.text,
              description: _desc.text,
              defaultReps: _i(_reps),
              defaultSets: _i(_sets),
              defaultFreqPerWeek: _i(_freq),
            );
            if (!mounted) return;
            Navigator.pop(context, true);
          },
          child: const Text('Save'),
        )
      ],
    );
  }
}
'@

# ---- Plans + Reports (MVP shells wired to real data)
Write-Utf8NoBom (Join-Path $lib "src\features\plans\plans_screen.dart") @'
import 'package:flutter/material.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppBar(title: Text('Plans')),
      body: Center(
        child: Text(
          'MVP: Plans wiring is in the DB layer already.\n'
          'Next patch: plan builder UI (assign exercises to patient plans) + completion check-off.\n'
          'This screen is wired in the router and ready for Phase-1 completion.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
'@

Write-Utf8NoBom (Join-Path $lib "src\features\reports\reports_screen.dart") @'
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // MVP: placeholder chart (real completion series gets added when plan check-off is enabled)
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Card(
            child: ListTile(
              title: Text('Progress Tracking'),
              subtitle: Text('MVP graphs are ready; next patch binds completions â†’ chart series.'),
            ),
          ),
          Card(
            child: SizedBox(
              height: 280,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: LineChart(
                  LineChartData(
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 1),
                          FlSpot(1, 1.5),
                          FlSpot(2, 1.7),
                          FlSpot(3, 2.2),
                          FlSpot(4, 2.0),
                        ],
                        isCurved: true,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
'@

# ---- Build
INFO "flutter clean"
& flutter clean | Out-Host

INFO "flutter pub get"
& flutter pub get | Out-Host

INFO "flutter build windows --release"
& flutter build windows --release | Out-Host

$exe = Join-Path $repo "build\windows\x64\runner\Release\simon_physio.exe"
if (!(Test-Path $exe)) { FAIL "EXE missing after build: $exe" }

OK "DONE: Built $exe"
OK "MVP now has REAL: Patients + Notes + Calendar/Appointments + Exercises + working navigation + SQLite."
WARN "Next patch to finish Phase-1 spec: Plan Builder UI + Patient exercise check-off + completion logging â†’ reports charts."
'@

INFO "Wrote MVP wiring code (patients/notes/calendar/exercises/dashboard/reports shell + DB)."

# run flutter commands
INFO "flutter clean"
& flutter clean | Out-Host

INFO "flutter pub get"
& flutter pub get | Out-Host

INFO "flutter build windows --release"
& flutter build windows --release | Out-Host

$exe = Join-Path $repo "build\windows\x64\runner\Release\simon_physio.exe"
if(!(Test-Path $exe)){ FAIL "EXE missing after build: $exe" }
OK "Build OK: $exe"
OK "DONE"



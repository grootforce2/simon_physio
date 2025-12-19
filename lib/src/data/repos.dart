import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'db.dart';

final _uuid = const Uuid();

String _dayKey(DateTime d) {
  final local = d.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '$y-$m-$dd';
}

int _nowTs() => DateTime.now().millisecondsSinceEpoch;

final patientsRepoProvider = Provider((ref) => PatientsRepo());
final notesRepoProvider = Provider((ref) => NotesRepo());
final calendarRepoProvider = Provider((ref) => CalendarRepo());
final exerciseRepoProvider = Provider((ref) => ExerciseRepo());
final planRepoProvider = Provider((ref) => PlanRepo());

class PatientsRepo {
  Future<List<Map<String, Object?>>> list() async {
    final db = await AppDb.open();
    return db.query('patients', orderBy: 'createdTs DESC');
  }

  Future<Map<String, Object?>?> getById(String id) async {
    final db = await AppDb.open();
    final rows = await db.query('patients', where: 'id=?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> add({
    required String fullName,
    String? phone,
    String? email,
    String? dob,
  }) async {
    final db = await AppDb.open();
    await db.insert('patients', {
      'id': _uuid.v4(),
      'fullName': fullName.trim(),
      'phone': phone?.trim(),
      'email': email?.trim(),
      'dob': dob?.trim(),
      'createdTs': _nowTs(),
    });
  }

  Future<void> delete(String id) async {
    final db = await AppDb.open();
    await db.delete('patients', where: 'id=?', whereArgs: [id]);
  }
}

class NotesRepo {
  Future<List<Map<String, Object?>>> byPatient(String patientId) async {
    final db = await AppDb.open();
    return db.query('notes', where: 'patientId=?', whereArgs: [patientId], orderBy: 'createdTs DESC');
  }

  Future<void> add({required String patientId, required String body}) async {
    final db = await AppDb.open();
    final text = body.trim();
    if (text.isEmpty) return;
    await db.insert('notes', {
      'id': _uuid.v4(),
      'patientId': patientId,
      'body': text,
      'createdTs': _nowTs(),
    });
  }
}

class CalendarRepo {
  Future<List<Map<String, Object?>>> upcoming({int days = 30}) async {
    final db = await AppDb.open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final until = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;

    final rows = await db.rawQuery('''
      SELECT a.*, p.fullName as patientName
      FROM appointments a
      LEFT JOIN patients p ON p.id = a.patientId
      WHERE a.startTs BETWEEN ? AND ?
      ORDER BY a.startTs ASC
    ''', [now, until]);

    return rows;
  }

  Future<void> addAppointment({
    required String patientId,
    required DateTime start,
    required DateTime end,
    String? title,
    String? location,
    int? reminderMins,
  }) async {
    final db = await AppDb.open();
    await db.insert('appointments', {
      'id': _uuid.v4(),
      'patientId': patientId,
      'startTs': start.millisecondsSinceEpoch,
      'endTs': end.millisecondsSinceEpoch,
      'title': title?.trim(),
      'location': location?.trim(),
      'reminderMins': reminderMins,
    });
  }
}

class Exercise {
  final String id;
  final String name;
  final String? description;
  final int? defaultReps;
  final int? defaultSets;
  final int? defaultFreqPerWeek;

  Exercise({
    required this.id,
    required this.name,
    this.description,
    this.defaultReps,
    this.defaultSets,
    this.defaultFreqPerWeek,
  });

  static Exercise fromRow(Map<String, Object?> r) => Exercise(
        id: r['id'] as String,
        name: r['name'] as String,
        description: r['description'] as String?,
        defaultReps: r['defaultReps'] as int?,
        defaultSets: r['defaultSets'] as int?,
        defaultFreqPerWeek: r['defaultFreqPerWeek'] as int?,
      );
}

class ExerciseRepo {
  Future<List<Exercise>> list() async {
    final db = await AppDb.open();
    final rows = await db.query('exercises', orderBy: 'createdTs DESC');
    return rows.map(Exercise.fromRow).toList();
  }

  Future<void> add({
    required String name,
    String? description,
    int? defaultReps,
    int? defaultSets,
    int? defaultFreqPerWeek,
  }) async {
    final db = await AppDb.open();
    final n = name.trim();
    if (n.isEmpty) return;
    await db.insert('exercises', {
      'id': _uuid.v4(),
      'name': n,
      'description': description?.trim(),
      'defaultReps': defaultReps,
      'defaultSets': defaultSets,
      'defaultFreqPerWeek': defaultFreqPerWeek,
      'createdTs': _nowTs(),
    });
  }
}

class PlanRepo {
  Future<List<Map<String, Object?>>> listPlansByPatient(String patientId) async {
    final db = await AppDb.open();
    return db.query('plans', where: 'patientId=?', whereArgs: [patientId], orderBy: 'createdTs DESC');
  }

  Future<List<Map<String, Object?>>> listPlanItems(String planId) async {
    final db = await AppDb.open();
    final rows = await db.rawQuery('''
      SELECT i.*, e.name as exerciseName, e.description as exerciseDesc
      FROM plan_items i
      LEFT JOIN exercises e ON e.id = i.exerciseId
      WHERE i.planId = ?
      ORDER BY i.createdTs ASC
    ''', [planId]);
    return rows;
  }

  Future<String> createPlan({
    required String patientId,
    required String title,
    required DateTime startDate,
  }) async {
    final db = await AppDb.open();
    final id = _uuid.v4();
    await db.insert('plans', {
      'id': id,
      'patientId': patientId,
      'title': title.trim().isEmpty ? 'Rehab Plan' : title.trim(),
      'startDate': _dayKey(startDate),
      'active': 1,
      'createdTs': _nowTs(),
    });
    return id;
  }

  Future<void> addPlanItem({
    required String planId,
    required String exerciseId,
    String? customName,
    int? reps,
    int? sets,
    int? freqPerWeek,
    String? notes,
  }) async {
    final db = await AppDb.open();
    await db.insert('plan_items', {
      'id': _uuid.v4(),
      'planId': planId,
      'exerciseId': exerciseId,
      'customName': customName?.trim(),
      'reps': reps,
      'sets': sets,
      'freqPerWeek': freqPerWeek,
      'notes': notes?.trim(),
      'createdTs': _nowTs(),
    });
  }

  Future<void> deletePlanItem(String id) async {
    final db = await AppDb.open();
    await db.delete('plan_items', where: 'id=?', whereArgs: [id]);
  }

  Future<void> setPlanActive(String planId, bool active) async {
    final db = await AppDb.open();
    await db.update('plans', {'active': active ? 1 : 0}, where: 'id=?', whereArgs: [planId]);
  }

  bool _isDueToday(String patientId, String planItemId, int freqPerWeek, DateTime now) {
    freqPerWeek = max(1, min(7, freqPerWeek));
    final dow = now.toLocal().weekday;
    final seed = patientId.hashCode ^ planItemId.hashCode ^ dow.hashCode;
    final r = (seed.abs() % 7) + 1;
    return r <= freqPerWeek;
  }

  Future<List<Map<String, Object?>>> dueToday({required String patientId, DateTime? when}) async {
    final db = await AppDb.open();
    final now = (when ?? DateTime.now()).toLocal();
    final day = _dayKey(now);

    final items = await db.rawQuery('''
      SELECT i.id as planItemId, i.planId, i.exerciseId, i.customName, i.reps, i.sets, i.freqPerWeek, i.notes,
             p.title as planTitle,
             e.name as exerciseName, e.description as exerciseDesc
      FROM plan_items i
      JOIN plans p ON p.id = i.planId
      LEFT JOIN exercises e ON e.id = i.exerciseId
      WHERE p.patientId = ? AND p.active = 1
      ORDER BY p.createdTs DESC, i.createdTs ASC
    ''', [patientId]);

    final completed = await db.rawQuery('''
      SELECT planItemId FROM completions
      WHERE patientId = ? AND day = ?
    ''', [patientId, day]);
    final doneSet = completed.map((r) => r['planItemId'] as String).toSet();

    final out = <Map<String, Object?>>[];
    for (final r in items) {
      final pi = r['planItemId'] as String;
      final freq = (r['freqPerWeek'] as int?) ?? 3;
      final due = _isDueToday(patientId, pi, freq, now);
      if (!due) continue;

      out.add({
        ...r,
        'day': day,
        'isDone': doneSet.contains(pi) ? 1 : 0,
      });
    }
    return out;
  }

  Future<void> toggleCompletion({
    required String patientId,
    required String planId,
    required String planItemId,
    required bool done,
    DateTime? when,
    int? pain,
    int? difficulty,
    String? note,
  }) async {
    final db = await AppDb.open();
    final now = (when ?? DateTime.now()).toLocal();
    final day = _dayKey(now);

    if (!done) {
      await db.delete('completions', where: 'planItemId=? AND day=?', whereArgs: [planItemId, day]);
      return;
    }

    await db.insert(
      'completions',
      {
        'id': _uuid.v4(),
        'patientId': patientId,
        'planId': planId,
        'planItemId': planItemId,
        'day': day,
        'completedTs': now.millisecondsSinceEpoch,
        'pain': pain,
        'difficulty': difficulty,
        'note': note?.trim(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, Object?>>> completionSeries({
    required String patientId,
    int days = 28,
  }) async {
    final db = await AppDb.open();
    final now = DateTime.now().toLocal();
    final start = now.subtract(Duration(days: days - 1));
    final startKey = _dayKey(start);

    final rows = await db.rawQuery('''
      SELECT day, COUNT(*) as c
      FROM completions
      WHERE patientId = ? AND day >= ?
      GROUP BY day
      ORDER BY day ASC
    ''', [patientId, startKey]);

    return rows;
  }
}